import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';

sealed class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationReady extends NotificationState {
  const NotificationReady({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
    this.isLoadingMore = false,
    this.isWsConnected = false,
    this.error,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool isWsConnected;
  final String? error;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  NotificationReady copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isWsConnected,
    String? error,
    bool clearError = false,
  }) {
    return NotificationReady(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isWsConnected: isWsConnected ?? this.isWsConnected,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [items, unreadCount, nextCursor, isLoadingMore, isWsConnected, error];
}

class NotificationFailure extends NotificationState {
  const NotificationFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
