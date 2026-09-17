import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:pantry_pal/features/auth/session_repository.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(values);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return values.containsKey(key);
  }
}

class _ScriptedAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> seen = [];

  _ScriptedAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeSecureStorage storage;

  setUp(() {
    storage = _FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance = MethodChannelFlutterSecureStorage();
  });

  test(
    'retries a household request after refreshing an expired token',
    () async {
      storage.values.addAll({
        'pantrypal.access-token': 'stale-token',
        'pantrypal.refresh-token': 'session.raw-refresh',
        'pantrypal.household-id': 'hh1',
      });
      var refreshCalls = 0;
      final adapter = _ScriptedAdapter((options) async {
        final auth = options.headers['Authorization'] as String?;
        if (options.path == '/auth/refresh') {
          refreshCalls += 1;
          return ResponseBody.fromString(
            '{"accessToken":"fresh-token","refreshToken":"session.rotated",'
            '"household":{"id":"hh1"}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path.startsWith('/households/hh1/imports')) {
          return auth == 'Bearer fresh-token'
              ? ResponseBody.fromString(
                  '{"id":"job1","status":"QUEUED","progress":0}',
                  201,
                  headers: {
                    Headers.contentTypeHeader: ['application/json'],
                  },
                )
              : ResponseBody.fromString(
                  '{"message":"Your session has expired."}',
                  401,
                  headers: {
                    Headers.contentTypeHeader: ['application/json'],
                  },
                );
        }
        return ResponseBody.fromString('{}', 404);
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/v1'))
        ..httpClientAdapter = adapter;
      final repository = SessionRepository(dio: dio);

      final job = await repository.importRecipe(
        sourceKind: 'url',
        sourceInput: 'https://example.com/recipe',
      );

      expect(job.id, 'job1');
      expect(refreshCalls, 1);
      expect(storage.values['pantrypal.access-token'], 'fresh-token');
      expect(storage.values['pantrypal.refresh-token'], 'session.rotated');
      final retryAuth = adapter.seen.last.headers['Authorization'] as String?;
      expect(retryAuth, 'Bearer fresh-token');
    },
  );

  test('surfaces the sign-in error when refresh is rejected', () async {
    storage.values.addAll({
      'pantrypal.access-token': 'stale-token',
      'pantrypal.refresh-token': 'session.dead',
      'pantrypal.household-id': 'hh1',
    });
    final adapter = _ScriptedAdapter((options) async {
      if (options.path == '/auth/refresh') {
        return ResponseBody.fromString(
          '{"message":"Refresh token is invalid."}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"message":"Your session has expired."}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/v1'))
      ..httpClientAdapter = adapter;
    final repository = SessionRepository(dio: dio);

    await expectLater(
      repository.importRecipe(
        sourceKind: 'url',
        sourceInput: 'https://example.com/recipe',
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('does not attempt refresh for auth endpoints', () async {
    var refreshCalls = 0;
    final adapter = _ScriptedAdapter((options) async {
      if (options.path == '/auth/refresh') {
        refreshCalls += 1;
      }
      return ResponseBody.fromString(
        '{"message":"Invalid credentials."}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/v1'))
      ..httpClientAdapter = adapter;
    final repository = SessionRepository(dio: dio);

    await expectLater(
      repository.login(email: 'a@b.c', password: 'wrong-password'),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
  });
}
