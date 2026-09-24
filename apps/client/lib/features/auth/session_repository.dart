import 'package:dio/dio.dart';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../shared/app_log.dart';

const _rawApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3001/v1',
);

String _normalizeApiBaseUrl(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return 'http://localhost:3001/v1';
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    trimmed = 'https://$trimmed';
  }
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

final apiBaseUrl = _normalizeApiBaseUrl(_rawApiBaseUrl);

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final repository = SessionRepository();
  ref.onDispose(repository.close);
  return repository;
});

class SessionRepository {
  SessionRepository({Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage() {
    _dio.interceptors.add(QueuedInterceptorsWrapper(onError: _onDioError));
    // The refresh call must bypass the queued interceptor above: a 401 from
    // /auth/refresh would otherwise wait behind the callback that issued it
    // and deadlock the queue.
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ),
    )..httpClientAdapter = _dio.httpClientAdapter;
  }

  late final Dio _refreshDio;

  /// Transparently refreshes an expired access token once per request.
  ///
  /// The API issues 15-minute access tokens; without this, every call after
  /// expiry fails with a 401 that the user only experiences as a silent
  /// no-op behind modal sheets.
  Future<void> _onDioError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final options = error.requestOptions;
    final path = options.path;
    final alreadyRetried = options.extra['pantrypalRetried'] == true;
    final isAuthPath = path.startsWith('/auth/');
    if (response?.statusCode != 401 || alreadyRetried || isAuthPath) {
      return handler.next(error);
    }

    final failedToken = options.headers['Authorization'] as String?;
    final storedToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      appLog('auth', '401 on $path with no refresh credential stored');
      return handler.next(error);
    }
    // Another queued request may have already refreshed while this one was
    // waiting; reuse the rotated token instead of rotating again.
    final tokenChanged =
        storedToken != null && failedToken != 'Bearer $storedToken';

    try {
      String accessToken;
      if (tokenChanged) {
        appLog('auth', '401 on $path; reusing concurrently refreshed token');
        accessToken = storedToken;
      } else {
        appLog('auth', '401 on $path; refreshing access token');
        final refreshResponse = await _refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'client': 'android', 'refreshToken': refreshToken},
        );
        final newAccess = refreshResponse.data?['accessToken'];
        final newRefresh = refreshResponse.data?['refreshToken'];
        if (newAccess is! String || newAccess.isEmpty) {
          throw DioException(
            requestOptions: refreshResponse.requestOptions,
            error: 'Refresh response did not include an access token.',
            type: DioExceptionType.badResponse,
          );
        }
        await _storage.write(key: _accessTokenKey, value: newAccess);
        if (newRefresh is String && newRefresh.isNotEmpty) {
          await _storage.write(key: _refreshTokenKey, value: newRefresh);
        }
        final household = refreshResponse.data?['household'];
        if (household is Map && household['id'] is String) {
          await _storage.write(
            key: _householdIdKey,
            value: household['id'] as String,
          );
        }
        accessToken = newAccess;
      }

      final retry = options
        ..extra['pantrypalRetried'] = true
        ..headers['Authorization'] = 'Bearer $accessToken';
      final retryResponse = await _dio.fetch<dynamic>(retry);
      appLog(
        'auth',
        'Retried $path after refresh: ${retryResponse.statusCode}',
      );
      return handler.resolve(retryResponse);
    } on DioException catch (refreshError) {
      appLog(
        'auth',
        'Session refresh failed '
            '(${refreshError.response?.statusCode ?? 'no response'}); clearing session',
      );
      await clear();
      return handler.next(error);
    }
  }

  static const _accessTokenKey = 'pantrypal.access-token';
  static const _refreshTokenKey = 'pantrypal.refresh-token';
  static const _householdIdKey = 'pantrypal.household-id';
  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> login({required String email, required String password}) =>
      _authenticate('/auth/login', {
        'email': email.trim(),
        'password': password,
        'client': 'android',
      });
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String householdName,
    required String betaInvite,
  }) => _authenticate('/auth/register', {
    'email': email.trim(),
    'password': password,
    'displayName': displayName.trim(),
    'householdName': householdName.trim(),
    'betaInvite': betaInvite.trim(),
    'client': 'android',
  });

  Future<bool> restore() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    return accessToken != null && accessToken.isNotEmpty;
  }

  Future<String?> accessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> householdId() => _storage.read(key: _householdIdKey);

  Future<void> joinHousehold(String code) async {
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in before joining a household.');
    }
    await _dio.post<void>(
      '/households/join',
      data: {'code': code.trim()},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await _resolveHousehold(token);
  }

  Future<ImportJobSummary> importRecipe({
    required String sourceKind,
    required String sourceInput,
  }) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/households/$household/imports',
      data: {'sourceKind': sourceKind, 'sourceInput': sourceInput.trim()},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ImportJobSummary.fromJson(response.data ?? const {});
  }

  Future<ImportJobSummary> importStatus(String jobId) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/households/$household/imports/$jobId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ImportJobSummary.fromJson(response.data ?? const {});
  }

  Future<ImportJobSummary> importRecipeImage({
    required Uint8List bytes,
    required String mimeType,
    ProgressCallback? onUploadProgress,
  }) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final uploadResponse = await _dio.post<Map<String, dynamic>>(
      '/households/$household/imports/media-assets/upload-url',
      data: {
        'kind': 'image',
        'mimeType': mimeType,
        'byteSize': bytes.lengthInBytes,
      },
      options: Options(headers: headers),
    );
    final upload = uploadResponse.data;
    final assetId = upload?['assetId'];
    final uploadUrl = upload?['uploadUrl'];
    if (assetId is! String || uploadUrl is! String) {
      throw DioException(
        requestOptions: uploadResponse.requestOptions,
        error: 'The API did not provide a media upload destination.',
        type: DioExceptionType.badResponse,
      );
    }
    final uploader = Dio();
    try {
      await uploader.put<void>(
        uploadUrl,
        data: bytes,
        options: Options(contentType: mimeType),
        onSendProgress: onUploadProgress,
      );
    } finally {
      uploader.close(force: true);
    }
    await _dio.post<void>(
      '/households/$household/imports/media-assets/$assetId/complete',
      options: Options(headers: headers),
    );
    return importRecipe(sourceKind: 'image', sourceInput: assetId);
  }

  /// Uploads a live photo for an archived meal via a presigned PUT and
  /// attaches it as the archive cover.
  Future<void> uploadArchiveCover({
    required String cookingInstanceId,
    required Uint8List bytes,
    required String mimeType,
    ProgressCallback? onUploadProgress,
  }) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    final requestResponse = await _dio.post<Map<String, dynamic>>(
      '/households/$household/archive/$cookingInstanceId/cover/upload-request',
      data: {'mimeType': mimeType, 'byteSize': bytes.lengthInBytes},
      options: Options(headers: headers),
    );
    final upload = requestResponse.data;
    final assetId = upload?['assetId'];
    final uploadUrl = upload?['uploadUrl'];
    if (assetId is! String || uploadUrl is! String) {
      throw DioException(
        requestOptions: requestResponse.requestOptions,
        error: 'The API did not provide a media upload destination.',
        type: DioExceptionType.badResponse,
      );
    }
    final uploader = Dio();
    try {
      await uploader.put<void>(
        uploadUrl,
        data: bytes,
        options: Options(contentType: mimeType),
        onSendProgress: onUploadProgress,
      );
    } finally {
      uploader.close(force: true);
    }
    await _dio.post<void>(
      '/households/$household/archive/$cookingInstanceId/cover/complete',
      data: {'assetId': assetId},
      options: Options(headers: headers),
    );
  }

  /// Fetches an archived meal's cover photo bytes.
  Future<Uint8List> archiveCoverBytes(String cookingInstanceId) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.get<List<int>>(
      '/households/$household/archive/$cookingInstanceId/cover',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<RecipeReview> recipeReview(String recipeId) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/households/$household/recipes/$recipeId/review',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return RecipeReview.fromJson(response.data ?? const {});
  }

  Future<RecipeReview> saveRecipeReview(RecipeReview review) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.put<Map<String, dynamic>>(
      '/households/$household/recipes/${review.id}/review',
      data: review.toSaveJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return RecipeReview.fromJson(response.data ?? const {});
  }

  Future<RecipeReview> createRecipe(RecipeReview recipe) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/households/$household/recipes',
      data: recipe.toCreateJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return RecipeReview.fromJson(response.data ?? const {});
  }

  Future<List<HouseholdCollectionItem>> cookingInstances() =>
      _householdCollection('/cooking');

  Future<List<HouseholdCollectionItem>> recipes() =>
      _householdCollection('/recipes');

  Future<List<HouseholdCollectionItem>> shoppingTrips() =>
      _householdCollection('/trips');

  Future<List<HouseholdCollectionItem>> archive() =>
      _householdCollection('/archive');

  Future<List<HouseholdCollectionItem>> notifications() =>
      _householdCollection('/notifications');

  Future<HouseholdCollectionItem> shoppingTripDetail(String tripId) =>
      _householdItem('/trips/$tripId');

  Future<void> updateShoppingItem({
    required String tripId,
    required String itemId,
    required String status,
    String? amount,
    String? unit,
  }) => _householdPatch('/trips/$tripId/items/$itemId', {
    'status': status,
    if (amount?.isNotEmpty ?? false) 'amount': amount!,
    if (unit?.isNotEmpty ?? false) 'unit': unit!,
  });

  Future<void> addShoppingItem({
    required String tripId,
    required String displayName,
    String? amount,
    String? unit,
  }) => _householdPost('/trips/$tripId/items', {
    'displayName': displayName.trim(),
    if (amount != null && amount.trim().isNotEmpty) 'amount': amount.trim(),
    if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
  });

  Future<void> toggleShoppingItemPickedUp({
    required String tripId,
    required String itemId,
  }) => _householdPost('/trips/$tripId/items/$itemId/picked-up');

  Future<void> archiveShoppingItem({
    required String tripId,
    required String itemId,
    required String reason,
  }) => _householdPost('/trips/$tripId/items/$itemId/archive', {
    'reason': reason,
  });

  Future<void> restoreShoppingItem({
    required String tripId,
    required String itemId,
  }) => _householdPost('/trips/$tripId/items/$itemId/restore');

  Future<void> markNotificationRead(String notificationId) =>
      _householdPost('/notifications/$notificationId/read');

  Future<void> registerPushSubscription(String token) async {
    final accessToken = await this.accessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Sign in before enabling device notifications.');
    }
    await _dio.post<void>(
      '/push-subscriptions',
      data: {'platform': 'android', 'endpoint': token},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<void> cookAgain({
    required String cookingInstanceId,
    String? targetServings,
    String? cookingDate,
  }) => _householdPost('/cooking/$cookingInstanceId/cook-again', {
    if (targetServings != null && targetServings.trim().isNotEmpty)
      'targetServings': targetServings.trim(),
    if (cookingDate != null && cookingDate.trim().isNotEmpty)
      'cookingDate': cookingDate.trim(),
  });

  Future<void> markCooked(String cookingInstanceId) =>
      _householdPost('/cooking/$cookingInstanceId/mark-cooked');

  /// Manually attaches or clears the shopping trip for a scheduled meal.
  /// `shoppingTripId: null` clears the trip. Either way the meal becomes
  /// MANUAL on the API, so automatic assignment never silently moves it.
  Future<void> assignCookingTrip({
    required String cookingInstanceId,
    required String? shoppingTripId,
  }) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    await _dio.patch<void>(
      '/households/$household/cooking/$cookingInstanceId',
      data: {'shoppingTripId': shoppingTripId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> createCookingInstance({
    required String recipeId,
    required String targetServings,
    String? cookingDate,
    String? shoppingTripId,
  }) => _householdPost('/cooking', {
    'recipeId': recipeId,
    'targetServings': targetServings.trim(),
    if (cookingDate != null && cookingDate.trim().isNotEmpty)
      'cookingDate': cookingDate.trim(),
    if (shoppingTripId != null && shoppingTripId.trim().isNotEmpty)
      'shoppingTripId': shoppingTripId.trim(),
  });

  Future<void> createShoppingTrip(String? scheduledFor) =>
      _householdPost('/trips', {
        if (scheduledFor != null && scheduledFor.trim().isNotEmpty)
          'scheduledFor': scheduledFor.trim(),
      });

  Future<void> transitionShoppingTrip({
    required String tripId,
    required String action,
  }) => _householdPost('/trips/$tripId/$action');

  Future<void> updateShoppingTripDate({
    required String tripId,
    required String scheduledFor,
  }) => _householdPatch('/trips/$tripId', {'scheduledFor': scheduledFor});

  Future<List<HouseholdCollectionItem>> _householdCollection(
    String path,
  ) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.get<List<dynamic>>(
      '/households/$household$path',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .map(HouseholdCollectionItem.fromJson)
        .toList();
  }

  Future<HouseholdCollectionItem> _householdItem(String path) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/households/$household$path',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return HouseholdCollectionItem.fromJson(response.data ?? const {});
  }

  Future<void> _householdPatch(String path, Map<String, String> data) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    await _dio.patch<void>(
      '/households/$household$path',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> _householdPost(String path, [Map<String, String>? data]) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    await _dio.post<void>(
      '/households/$household$path',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> clear() => _storage.deleteAll();

  Future<void> _authenticate(String path, Map<String, String> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: payload);
    final accessToken = response.data?['accessToken'];
    final refreshToken = response.data?['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'The API returned an incomplete Android session.',
        type: DioExceptionType.badResponse,
      );
    }
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    final household = response.data?['household'];
    if (household is Map && household['id'] is String) {
      await _storage.write(
        key: _householdIdKey,
        value: household['id'] as String,
      );
    } else {
      await _resolveHousehold(accessToken);
    }
  }

  Future<void> _resolveHousehold(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/households',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final first = response.data?.whereType<Map>().firstOrNull;
    final household = first?['household'];
    if (household is Map && household['id'] is String) {
      await _storage.write(
        key: _householdIdKey,
        value: household['id'] as String,
      );
    }
  }

  void close() => _dio.close(force: true);
}

class ImportJobSummary {
  const ImportJobSummary({
    required this.id,
    required this.status,
    required this.progress,
    this.errorCode,
    this.recipeId,
  });
  final String id;
  final String status;
  final int progress;
  final String? errorCode;
  final String? recipeId;

  factory ImportJobSummary.fromJson(Map<String, dynamic> json) =>
      ImportJobSummary(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'QUEUED',
        progress: json['progress'] as int? ?? 0,
        errorCode: json['errorCode'] as String?,
        recipeId: json['recipeId'] as String?,
      );
}

class HouseholdCollectionItem {
  const HouseholdCollectionItem(this.values);

  final Map<String, Object?> values;

  factory HouseholdCollectionItem.fromJson(Map<dynamic, dynamic> json) =>
      HouseholdCollectionItem(
        json.map((key, value) => MapEntry('$key', value as Object?)),
      );

  String? string(String key) => values[key] as String?;
  int? integer(String key) => values[key] as int?;
}

class RecipeReview {
  RecipeReview({
    required this.id,
    required this.title,
    required this.readiness,
    required this.revision,
    required this.originalServings,
    required this.yieldWording,
    required this.ingredients,
    required this.instructions,
    required this.completeness,
    required this.evidence,
    this.sourceUrl,
  });

  final String id;
  String title;
  String readiness;
  String revision;
  String originalServings;
  String yieldWording;
  final List<RecipeReviewIngredient> ingredients;
  final List<String> instructions;
  RecipeCompleteness completeness;
  final List<RecipeEvidence> evidence;
  final String? sourceUrl;

  factory RecipeReview.fromJson(Map<String, dynamic> json) {
    final recipe = json['recipe'] as Map? ?? const {};
    final version = json['version'] as Map? ?? const {};
    final source = json['source'] as Map?;
    return RecipeReview(
      id: recipe['id'] as String? ?? '',
      title: version['title'] as String? ?? recipe['title'] as String? ?? '',
      readiness: recipe['readiness'] as String? ?? 'NEEDS_REVIEW',
      revision: '${recipe['revision'] ?? ''}',
      originalServings: version['originalServings'] as String? ?? '',
      yieldWording: version['yieldWording'] as String? ?? '',
      ingredients: (json['ingredients'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => RecipeReviewIngredient.fromJson(item))
          .toList(),
      instructions: (json['instructions'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      completeness: RecipeCompleteness.fromJson(
        json['completeness'] as Map? ?? const {},
      ),
      evidence: (json['evidence'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => RecipeEvidence.fromJson(item))
          .toList(),
      sourceUrl: source?['canonicalUrl'] as String?,
    );
  }

  Map<String, dynamic> toSaveJson() => {
    'title': title.trim(),
    'originalServings': originalServings.trim().isEmpty
        ? null
        : originalServings.trim(),
    'yieldWording': yieldWording.trim().isEmpty ? null : yieldWording.trim(),
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'instructions': instructions,
    'expectedRevision': revision,
  };

  Map<String, dynamic> toCreateJson() => {
    'title': title.trim(),
    'originalServings': originalServings.trim().isEmpty
        ? null
        : originalServings.trim(),
    'yieldWording': yieldWording.trim().isEmpty ? null : yieldWording.trim(),
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'instructions': instructions,
  };
}

class RecipeReviewIngredient {
  RecipeReviewIngredient({
    required this.name,
    required this.quantityMin,
    required this.quantityMax,
    required this.originalUnit,
    required this.preparationNote,
    required this.classification,
    required this.includeInShopping,
    required this.originalText,
  });

  String name;
  String quantityMin;
  String quantityMax;
  String originalUnit;
  String preparationNote;
  String classification;
  bool includeInShopping;
  final String originalText;

  factory RecipeReviewIngredient.fromJson(Map<dynamic, dynamic> json) =>
      RecipeReviewIngredient(
        name: json['name'] as String? ?? '',
        quantityMin: json['quantityMin'] as String? ?? '',
        quantityMax: json['quantityMax'] as String? ?? '',
        originalUnit: json['originalUnit'] as String? ?? '',
        preparationNote: json['preparationNote'] as String? ?? '',
        classification: json['classification'] as String? ?? 'REQUIRED',
        includeInShopping: json['includeInShopping'] as bool? ?? true,
        originalText: json['originalText'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'quantityMin': quantityMin.trim().isEmpty ? null : quantityMin.trim(),
    'quantityMax': quantityMax.trim().isEmpty ? null : quantityMax.trim(),
    'originalUnit': originalUnit.trim().isEmpty ? null : originalUnit.trim(),
    'preparationNote': preparationNote.trim().isEmpty
        ? null
        : preparationNote.trim(),
    'classification': classification,
    'includeInShopping': includeInShopping,
  };
}

class RecipeCompleteness {
  const RecipeCompleteness({
    required this.extracted,
    required this.manual,
    required this.missing,
  });
  final int extracted;
  final int manual;
  final int missing;

  factory RecipeCompleteness.fromJson(Map<dynamic, dynamic> json) =>
      RecipeCompleteness(
        extracted: json['extracted'] as int? ?? 0,
        manual: json['manual'] as int? ?? 0,
        missing: json['missing'] as int? ?? 0,
      );
}

class RecipeEvidence {
  const RecipeEvidence({
    required this.fieldPath,
    required this.origin,
    required this.excerpt,
    required this.confidence,
  });
  final String fieldPath;
  final String origin;
  final String? excerpt;
  final String? confidence;

  factory RecipeEvidence.fromJson(Map<dynamic, dynamic> json) => RecipeEvidence(
    fieldPath: json['fieldPath'] as String? ?? '',
    origin: json['origin'] as String? ?? 'source',
    excerpt: json['excerpt'] as String?,
    confidence: json['confidence'] as String?,
  );
}
