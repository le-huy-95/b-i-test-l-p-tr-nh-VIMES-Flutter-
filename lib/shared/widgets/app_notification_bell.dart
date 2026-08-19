import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/features/notification/bloc/notification_bloc.dart';
import 'package:test_y_app/features/notification/bloc/notification_state.dart';

class AppNotificationBell extends StatelessWidget {
  const AppNotificationBell({
    super.key,
    this.tooltip = 'Thông báo',
    this.route = '/notifications',
    this.color,
    this.padding = const EdgeInsets.only(right: 4),
  });

  final String tooltip;
  final String route;
  final Color? color;
  final EdgeInsetsGeometry padding;

  NotificationBloc? _maybeBloc(BuildContext context) {
    try {
      return context.read<NotificationBloc>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _maybeBloc(context);
    final button = bloc == null
        ? IconButton(
            tooltip: tooltip,
            onPressed: () => context.push(route),
            icon: Icon(Icons.notifications_none_outlined, color: color),
          )
        : BlocBuilder<NotificationBloc, NotificationState>(
            bloc: bloc,
            buildWhen: (previous, current) {
              final prevCount =
                  previous is NotificationReady ? previous.unreadCount : 0;
              final currCount =
                  current is NotificationReady ? current.unreadCount : 0;
              return prevCount != currCount;
            },
            builder: (context, state) {
              final unread = state is NotificationReady ? state.unreadCount : 0;
              return IconButton(
                tooltip: tooltip,
                onPressed: () => context.push(route),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: unread > 99 ? const Text('99+') : Text('$unread'),
                  child: Icon(
                    Icons.notifications_none_outlined,
                    color: color,
                  ),
                ),
              );
            },
          );

    return Padding(padding: padding, child: button);
  }
}
