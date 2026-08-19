import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/auth/widgets/vimes_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  StreamSubscription<AuthState>? _authSub;
  Timer? _minDelay;
  Timer? _fallback;
  bool _minDelayDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authBloc = context.read<AuthBloc>();
      _authSub = authBloc.stream.listen(_tryNavigate);
      _minDelay = Timer(const Duration(milliseconds: 700), () {
        _minDelayDone = true;
        _tryNavigate(authBloc.state);
      });
      _fallback = Timer(const Duration(seconds: 3), () {
        if (!mounted || _navigated) return;
        _go(AppRoutes.login.path);
      });
    });
  }

  void _tryNavigate(AuthState state) {
    if (!mounted || _navigated || !_minDelayDone) return;

    if (state is AuthLoading || state is AuthInitial) return;

    if (state is AuthAuthenticated) {
      _go(AppRoutes.home.path);
    } else if (state is AuthNeedsTenant) {
      _go(AppRoutes.selectTenant.path);
    } else {
      _go(AppRoutes.login.path);
    }
  }

  void _go(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(path);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _minDelay?.cancel();
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorSkin.primary,
              ColorSkin.primarySub,
              Color(0xFF084A50),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: ColorSkin.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const VimesLogo(width: 240),
            ),
          ),
        ),
      ),
    );
  }
}
