import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/core/firebase/push_notification_handler.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';

/// Wires [PushNotificationHandler] to auth lifecycle (cold start + tenant sync).
class PushNotificationListener extends StatefulWidget {
  const PushNotificationListener({
    super.key,
    required this.handler,
    required this.child,
  });

  final PushNotificationHandler handler;
  final Widget child;

  @override
  State<PushNotificationListener> createState() =>
      _PushNotificationListenerState();
}

class _PushNotificationListenerState extends State<PushNotificationListener> {
  @override
  void initState() {
    super.initState();
    widget.handler.setOnTenantSelected((tenantId) {
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthTenantSelected(tenantId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is! AuthLoading && current is! AuthInitial,
      listener: (context, state) {
        widget.handler.markAuthReady();
      },
      child: widget.child,
    );
  }
}
