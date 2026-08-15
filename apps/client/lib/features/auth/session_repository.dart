import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3001/v1',
);

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
      _storage = storage ?? const FlutterSecureStorage();

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
    if (token == null || token.isEmpty)
      throw StateError('Sign in before joining a household.');
    await _dio.post<void>(
      '/households/join',
      data: {'code': code.trim()},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await _resolveHousehold(token);
  }

  Future<void> importRecipe(String sourceUrl) async {
    final token = await accessToken();
    final household = await householdId();
    if (token == null || household == null) {
      throw StateError('Your household session is unavailable. Sign in again.');
    }
    await _dio.post<void>(
      '/households/$household/imports',
      data: {'sourceKind': 'url', 'sourceInput': sourceUrl.trim()},
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
