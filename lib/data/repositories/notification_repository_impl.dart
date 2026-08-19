import 'package:test_y_app/data/datasources/api_services/notification_api_service.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';
import 'package:test_y_app/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({NotificationApiService? apiService})
      : _api = apiService ?? NotificationApiService();

  final NotificationApiService _api;

  @override
  Future<NotificationListResult> list({
    String? cursor,
    int limit = 20,
    bool onlyUnread = false,
  }) {
    return _api.list(cursor: cursor, limit: limit, onlyUnread: onlyUnread);
  }

  @override
  Future<int> getUnreadCount() => _api.getUnreadCount();

  @override
  Future<MarkReadResult> markRead({
    List<String>? notificationIds,
    bool markAll = false,
  }) {
    return _api.markRead(
      notificationIds: notificationIds,
      markAll: markAll,
    );
  }
}
