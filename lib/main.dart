import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import 'app/app.dart';
import 'core/firebase/firebase_service.dart' as app_firebase;
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    Logger().i('Handling a background message: ${message.messageId}');
    if (message.data.isNotEmpty) {
      Logger().d('Background message data: ${message.data}');
    }
  } catch (e) {
    Logger().w('Error in firebaseMessagingBackgroundHandler: $e');
  }
}

Future<bool> _initializeFirebase(Logger logger) async {
  if (Firebase.apps.isNotEmpty) return true;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i('Firebase initialized successfully');
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      logger.i('Firebase already initialized');
      return true;
    }
    logger.w(
      'Firebase initialization failed (${e.code}): ${e.message}. '
      'Add ios/Runner/GoogleService-Info.plist, '
      'android/app/google-services.json (and optionally lib/firebase_options.dart).',
    );
    return false;
  } catch (e) {
    logger.w(
      'Firebase initialization unknown error: $e. '
      'Run: dart pub global activate flutterfire_cli && flutterfire configure',
    );
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = Logger();

  await Future.wait([
    dotenv.load(fileName: '.env'),
    initializeDateFormatting('vi_VN'),
  ]);
  Intl.defaultLocale = 'vi_VN';
  logger.i('API base URL: ${dotenv.env['API_DEV_URL']}');

  final firebaseReady = await _initializeFirebase(logger);

  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      await app_firebase.FirebaseService.instance.initialize();
    } catch (e) {
      logger.w('FirebaseService initialization error: $e');
    }
  } else {
    logger.w(
      'Firebase unavailable — push notifications and Google login will not work '
      'until Firebase config files are added.',
    );
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const BaseApp());
}
