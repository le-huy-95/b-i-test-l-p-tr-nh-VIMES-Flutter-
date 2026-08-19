import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:test_y_app/data/datasources/notification_ws_service.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';
import 'package:test_y_app/domain/repositories/notification_repository.dart';

import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({
    required NotificationRepository repository,
    NotificationWsService? wsService,
  })  : _repository = repository,
        _ws = wsService ?? NotificationWsService(),
        super(const NotificationInitial()) {
    _setupWs();

    on<NotificationStarted>(_onStarted);
    on<NotificationRefreshed>(_onRefreshed);
    on<NotificationLoadMore>(_onLoadMore);
    on<NotificationReceived>(_onReceived);
    on<NotificationWsConnected>(_onWsConnected);
    on<NotificationWsDisconnected>(_onWsDisconnected);
    on<NotificationMarkRead>(_onMarkRead);
    on<NotificationMarkAllRead>(_onMarkAllRead);
    on<NotificationDisconnected>(_onDisconnected);
  }

  final NotificationRepository _repository;
  final NotificationWsService _ws;
  final Logger _logger = Logger();

  void _setupWs() {
    _ws.onNotification = (item, unreadCount) {
      if (!isClosed) add(NotificationReceived(item: item, unreadCount: unreadCount));
    };
    _ws.onConnectionChanged = (connected) {
      if (!isClosed) {
        add(connected
            ? const NotificationWsConnected()
            : const NotificationWsDisconnected());
      }
    };
  }

  @override
  Future<void> close() {
    _ws.dispose();
    return super.close();
  }

  Future<void> _onStarted(
    NotificationStarted event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    try {
      final results = await Future.wait([
        _repository.list(limit: 20),
        _repository.getUnreadCount(),
      ]);
      final listResult = results[0] as NotificationListResult;
      final unread = results[1] as int;
      emit(NotificationReady(
        items: listResult.items,
        unreadCount: unread,
        nextCursor: listResult.nextCursor,
      ));
      _ws.connect();
    } catch (e) {
      emit(NotificationFailure(_friendly(e)));
    }
  }

  Future<void> _onRefreshed(
    NotificationRefreshed event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _repository.list(limit: 20),
        _repository.getUnreadCount(),
      ]);
      final listResult = results[0] as NotificationListResult;
      final unread = results[1] as int;
      final current = state;
      if (current is NotificationReady) {
        emit(current.copyWith(
          items: listResult.items,
          unreadCount: unread,
          nextCursor: listResult.nextCursor,
          clearError: true,
        ));
      } else {
        emit(NotificationReady(
          items: listResult.items,
          unreadCount: unread,
          nextCursor: listResult.nextCursor,
        ));
      }
      _ws.connect();
    } catch (e) {
      final current = state;
      if (current is NotificationReady) {
        emit(current.copyWith(error: _friendly(e)));
      } else {
        emit(NotificationFailure(_friendly(e)));
      }
    }
  }

  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationReady || !current.hasMore || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.list(cursor: current.nextCursor, limit: 20);
      emit(current.copyWith(
        items: [...current.items, ...result.items],
        nextCursor: result.nextCursor,
        isLoadingMore: false,
        clearError: true,
      ));
    } catch (e) {
      emit(current.copyWith(isLoadingMore: false, error: _friendly(e)));
    }
  }

  void _onReceived(
    NotificationReceived event,
    Emitter<NotificationState> emit,
  ) {
    final current = state;
    if (current is! NotificationReady) return;

    final exists = current.items.any((item) => item.id == event.item.id);
    if (exists) return;

    final updatedItems = [event.item, ...current.items];
    emit(current.copyWith(
      items: updatedItems,
      unreadCount: event.unreadCount,
      clearError: true,
    ));
  }

  void _onWsConnected(
    NotificationWsConnected event,
    Emitter<NotificationState> emit,
  ) {
    final current = state;
    if (current is NotificationReady) {
      emit(current.copyWith(isWsConnected: true, clearError: true));
    }
  }

  void _onWsDisconnected(
    NotificationWsDisconnected event,
    Emitter<NotificationState> emit,
  ) {
    final current = state;
    if (current is NotificationReady) {
      emit(current.copyWith(isWsConnected: false));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkRead event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationReady) return;

    final updatedItems = current.items.map((item) {
      if (item.id == event.notificationId && !item.isRead) {
        return item.copyWith(readAt: DateTime.now());
      }
      return item;
    }).toList();

    final wasUnread = current.items.any(
      (item) => item.id == event.notificationId && !item.isRead,
    );
    final localUnread = wasUnread
        ? (current.unreadCount > 0 ? current.unreadCount - 1 : 0)
        : current.unreadCount;

    emit(current.copyWith(
      items: updatedItems,
      unreadCount: localUnread,
    ));

    try {
      final result = await _repository.markRead(notificationIds: [event.notificationId]);
      emit(current.copyWith(
        items: updatedItems,
        unreadCount: result.unreadCount,
      ));
    } catch (e) {
      _logger.w('markRead API failed, keeping local optimistic state', error: e);
    }
  }

  Future<void> _onMarkAllRead(
    NotificationMarkAllRead event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationReady) return;

    final now = DateTime.now();
    final updatedItems = current.items
        .map((item) => item.isRead ? item : item.copyWith(readAt: now))
        .toList();

    emit(current.copyWith(items: updatedItems, unreadCount: 0));

    try {
      await _repository.markRead(markAll: true);
    } catch (e) {
      _logger.w('markAllRead API failed, keeping local optimistic state', error: e);
    }
  }

  void _onDisconnected(
    NotificationDisconnected event,
    Emitter<NotificationState> emit,
  ) {
    _ws.disconnect();
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}
