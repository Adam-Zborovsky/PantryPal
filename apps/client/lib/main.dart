import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

export 'app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint(
      'PANTRYPAL_CRASH: ${details.exception}\n'
      'PANTRYPAL_CRASH_LIBRARY: ${details.library}',
    );
    if (details.stack != null) {
      debugPrint('PANTRYPAL_CRASH_STACK:\n${details.stack}');
    }
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint(
      'PANTRYPAL_CRASH_UNCAUGHT: $error\nPANTRYPAL_CRASH_STACK:\n$stack',
    );
    return true;
  };
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const PantryPalApp());
}
