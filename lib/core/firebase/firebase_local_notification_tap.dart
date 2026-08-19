import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

/// Background tap handler for [FlutterLocalNotificationsPlugin].
@pragma('vm:entry-point')
void firebaseLocalNotificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    jsonDecode(payload);
    Logger().i('Local notification tapped (background isolate)');
  } catch (e) {
    Logger().w('Invalid local notification payload: $e');
  }
}
