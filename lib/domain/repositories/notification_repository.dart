import 'package:test_y_app/data/models/notification/notification_item.dart';

abstract class NotificationRepository {
  Future<NotificationListResult> list({
    String? cursor,
    int limit = 20,
    bool onlyUnread = false,
  });

  Future<int> getUnreadCount();

  Future<MarkReadResult> markRead({
    List<String>? notificationIds,
    bool markAll = false,
  });
}
