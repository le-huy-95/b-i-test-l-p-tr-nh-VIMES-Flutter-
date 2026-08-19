import 'package:firebase_messaging/firebase_messaging.dart';

/// Normalized FCM payload for display and navigation (Phase 3).
class PushNotificationPayload {
  const PushNotificationPayload({
    required this.data,
    this.title,
    this.body,
    this.type,
    this.tenantId,
    this.targetId,
  });

  final Map<String, dynamic> data;
  final String? title;
  final String? body;
  final String? type;
  final String? tenantId;
  final String? targetId;

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    return PushNotificationPayload(
      data: data,
      title: notification?.title ?? data['title']?.toString(),
      body: notification?.body ?? data['body']?.toString(),
      type: data['type']?.toString(),
      tenantId: data['tenantId']?.toString(),
      targetId: data['targetId']?.toString(),
    );
  }

  factory PushNotificationPayload.fromJsonMap(Map<String, dynamic> data) {
    return PushNotificationPayload(
      data: data,
      title: data['title']?.toString(),
      body: data['body']?.toString(),
      type: data['type']?.toString(),
      tenantId: data['tenantId']?.toString(),
      targetId: data['targetId']?.toString(),
    );
  }

  bool get hasDisplayContent {
    final hasTitle = title != null && title!.trim().isNotEmpty;
    final hasBody = body != null && body!.trim().isNotEmpty;
    return hasTitle || hasBody;
  }
}
