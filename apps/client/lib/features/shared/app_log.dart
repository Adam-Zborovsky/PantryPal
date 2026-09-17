import 'package:flutter/foundation.dart';

/// Lightweight structured console logging.
///
/// Output appears in `flutter run` console output and in Android logcat under
/// the `flutter` tag, prefixed with the originating domain, e.g.
/// `pantrypal/auth 2026-08-23T10:55:01.123 :: Access token rejected (401)`.
void appLog(String domain, String message) {
  debugPrint(
    'pantrypal/$domain ${DateTime.now().toIso8601String()} :: $message',
  );
}
