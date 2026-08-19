import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test_y_app/core/firebase/firebase_local_notification_tap.dart';
import 'package:test_y_app/core/firebase/push_notification_payload.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/storage/share_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DeviceRegistrationCallback = Future<void> Function();
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

class FirebaseService {
  FirebaseService._internal();

  static final FirebaseService _instance = FirebaseService._internal();
  static FirebaseService get instance => _instance;

  static const String fcmTokenStorageKey = 'fcm_token';
  static const String _androidChannelId = 'test_y_app_channel';
  static const String _androidChannelName = 'test_y_app Notifications';

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();
  final ValueNotifier<int> _notificationBadgeCount = ValueNotifier<int>(0);

  ValueNotifier<int> get notificationBadgeCount => _notificationBadgeCount;
  String? _currentToken;
  String? get currentToken => _currentToken;

  DeviceRegistrationCallback? _onRegisterDevice;
  NotificationTapCallback? _onNotificationTap;
  Map<String, dynamic>? _pendingTapData;

  /// Wire after [AuthRepository] is available (e.g. in [BaseApp.initState]).
  void setDeviceRegistrationHandler(DeviceRegistrationCallback handler) {
    _onRegisterDevice = handler;
    unawaited(_registerDeviceBestEffort());
  }

  /// Wire when navigation is ready (Phase 3). Until then, tap data is queued.
  void setNotificationTapHandler(NotificationTapCallback handler) {
    _onNotificationTap = handler;
    final pending = _pendingTapData;
    if (pending != null) {
      _pendingTapData = null;
      handler(pending);
    }
  }

  Map<String, dynamic>? consumePendingTapData() {
    final pending = _pendingTapData;
    _pendingTapData = null;
    return pending;
  }

  Future<void> _registerDeviceBestEffort() async {
    final handler = _onRegisterDevice;
    if (handler == null) return;
    try {
      await handler();
    } catch (e, st) {
      _logger.w('FCM: registerDevice best-effort failed: $e', stackTrace: st);
    }
  }

  FirebaseMessaging get _messaging {
    return _fcm ??= FirebaseMessaging.instance;
  }

  Future<void> initialize() async {
    try {
      await _messaging.setAutoInitEnabled(true);
      await _initializeLocalNotifications();
      final permissionGranted = await _requestPermission();
      if (permissionGranted) {
        await _registerDeviceBestEffort();
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      _messaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        try {
          await ShareManager().saveString(fcmTokenStorageKey, newToken);
        } catch (e) {
          _logger.w('FCM: không lưu được token sau refresh: $e');
        }
        await _registerDeviceBestEffort();
      });

      FirebaseMessaging.onMessage.listen(_showNotificationFromMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteNotificationTap);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleRemoteNotificationTap(initial);
      }

      await getToken();
      _logger.i('Firebase Service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Firebase Service: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          firebaseLocalNotificationTapBackground,
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    var granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.notification.request();
      granted = granted || status.isGranted;
    }

    return granted;
  }

  Future<String?> getToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // Simulator / cold start often has no APNS token yet.
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          _logger.w(
            'FCM: APNS token chưa sẵn sàng — bỏ qua getToken (thường gặp trên simulator)',
          );
          return null;
        }
      }
      final token = await _messaging.getToken();
      _currentToken = token;
      if (token != null && token.isNotEmpty) {
        await ShareManager().saveString(fcmTokenStorageKey, token);
      }
      return token;
    } catch (e) {
      final message = e.toString();
      if (message.contains('apns-token-not-set')) {
        _logger.w('FCM: APNS token chưa sẵn sàng — $e');
      } else {
        _logger.e('Failed to get FCM token: $e');
      }
      return null;
    }
  }

  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _currentToken = null;
  }

  void _handleRemoteNotificationTap(RemoteMessage message) {
    final payload = PushNotificationPayload.fromRemoteMessage(message);
    if (payload.data.isEmpty && !payload.hasDisplayContent) {
      _logger.w('FCM tap ignored: empty payload');
      return;
    }
    _dispatchNotificationTap(payload.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload == null || rawPayload.isEmpty) return;

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        _logger.w('FCM local tap ignored: payload is not a map');
        return;
      }
      _dispatchNotificationTap(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      _logger.w('FCM local tap payload parse failed: $e', stackTrace: st);
    }
  }

  void _dispatchNotificationTap(Map<String, dynamic> data) {
    final handler = _onNotificationTap;
    if (handler != null) {
      handler(data);
      return;
    }
    _pendingTapData = data;
    _logger.i('FCM tap queued (handler not ready): $data');
  }

  Future<void> _showNotificationFromMessage(RemoteMessage message) async {
    final payload = PushNotificationPayload.fromRemoteMessage(message);
    if (!payload.hasDisplayContent) {
      _logger.d('FCM foreground message has no display content: ${payload.data}');
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: ColorSkin.primary,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId =
        message.messageId?.hashCode ?? message.hashCode;

    await _localNotifications.show(
      id: notificationId,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: payload.data.isNotEmpty ? jsonEncode(payload.data) : null,
    );
  }
}
