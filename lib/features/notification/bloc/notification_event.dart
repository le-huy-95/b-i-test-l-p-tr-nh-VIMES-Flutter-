import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationStarted extends NotificationEvent {
  const NotificationStarted();
}

class NotificationRefreshed extends NotificationEvent {
  const NotificationRefreshed();
}

class NotificationLoadMore extends NotificationEvent {
  const NotificationLoadMore();
}

class NotificationReceived extends NotificationEvent {
  const NotificationReceived({required this.item, required this.unreadCount});

  final NotificationItem item;
  final int unreadCount;

  @override
  List<Object?> get props => [item, unreadCount];
}

class NotificationWsConnected extends NotificationEvent {
  const NotificationWsConnected();
}

class NotificationWsDisconnected extends NotificationEvent {
  const NotificationWsDisconnected();
}

class NotificationMarkRead extends NotificationEvent {
  const NotificationMarkRead(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

class NotificationMarkAllRead extends NotificationEvent {
  const NotificationMarkAllRead();
}

class NotificationDisconnected extends NotificationEvent {
  const NotificationDisconnected();
}
