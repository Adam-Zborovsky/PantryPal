import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_repository.dart';

final pushNotificationsProvider = Provider<PushNotificationsService>((ref) {
  final service = PushNotificationsService(ref.read(sessionRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

class PushNotificationsService {
  PushNotificationsService(this._repository);

  final SessionRepository _repository;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> requestAndRegister() async {
    if (!_isAndroid) return false;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return false;
    }
    await messaging.setAutoInitEnabled(true);
    await _registerCurrentToken(messaging);
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (token) => unawaited(_repository.registerPushSubscription(token)),
    );
    return true;
  }

  Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Could not obtain a notification token for this device.',
      );
    }
    await _repository.registerPushSubscription(token);
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
