import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/domain/usecases/auth/login_usecase.dart';
import 'package:test_y_app/features/auth/utils/tenant_routing.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    LoginUseCase? loginUseCase,
    bool checkOnCreate = true,
  })  : _authRepository = authRepository,
        _loginUseCase = loginUseCase ?? LoginUseCase(authRepository),
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthSessionEstablished>(_onAuthSessionEstablished);
    on<AuthTenantSelected>(_onAuthTenantSelected);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    if (checkOnCreate) {
      add(const AuthCheckRequested());
    }
  }

  final AuthRepository _authRepository;
  final LoginUseCase _loginUseCase;
  final Logger _logger = Logger();

  Future<void> _emitAfterSession(AuthSession session, Emitter<AuthState> emit) async {
    final saved = await _authRepository.getSelectedTenantId();
    final route = resolveTenantRoute(
      tenants: session.tenants,
      savedTenantId: saved,
    );
    if (route.destination == TenantDestination.home && route.tenantId != null) {
      await _authRepository.selectTenant(route.tenantId!);
      AppRouterConfig.instance.setAuthState(true, hasTenant: true);
      emit(
        AuthAuthenticated(
          user: session.user,
          tenants: session.tenants,
          selectedTenantId: route.tenantId!,
        ),
      );
      _safeNavigate(() => AppRouterConfig.instance.goHome());
    } else {
      AppRouterConfig.instance.setAuthState(true, hasTenant: false);
      emit(AuthNeedsTenant(user: session.user, tenants: session.tenants));
      _safeNavigate(() => AppRouterConfig.instance.goSelectTenant());
    }
  }

  void _safeNavigate(void Function() navigate) {
    try {
      navigate();
    } catch (e, st) {
      _logger.w('Auth navigation skipped', error: e, stackTrace: st);
    }
  }

  Future<void> _registerDeviceBestEffort() async {
    try {
      await _authRepository.registerDevice();
    } catch (e, st) {
      _logger.w(
        'registerDevice best-effort failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Đang kiểm tra phiên đăng nhập...'));
    try {
      if (!await _authRepository.isLoggedIn()) {
        AppRouterConfig.instance.setAuthState(false);
        emit(const AuthUnauthenticated());
        return;
      }

      final me = await _authRepository.getMe();
      if (me == null) {
        await _authRepository.logout(forceLocalOnly: true);
        AppRouterConfig.instance.setAuthState(false);
        emit(const AuthUnauthenticated());
        return;
      }

      await _registerDeviceBestEffort();

      await _emitAfterSession(
        AuthSession(
          user: me.user,
          tenants: me.tenants,
          accessToken: '',
          refreshToken: '',
        ),
        emit,
      );
    } catch (e) {
      _logger.e('Auth check failed', error: e);
      try {
        await _authRepository.logout(forceLocalOnly: true);
      } catch (_) {}
      AppRouterConfig.instance.setAuthState(false);
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Đang đăng nhập...'));
    final result = await _loginUseCase(
      credentials: event.credentials,
      password: event.password,
    );

    await result.fold(
      (failure) async => emit(AuthError(error: failure.message)),
      (session) => _emitAfterSession(session, emit),
    );
  }

  Future<void> _onAuthSessionEstablished(
    AuthSessionEstablished event,
    Emitter<AuthState> emit,
  ) async {
    await _emitAfterSession(event.session, emit);
  }

  Future<void> _onAuthTenantSelected(
    AuthTenantSelected event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    final user = switch (current) {
      AuthNeedsTenant(:final user) => user,
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final tenants = switch (current) {
      AuthNeedsTenant(:final tenants) => tenants,
      AuthAuthenticated(:final tenants) => tenants,
      _ => null,
    };

    if (user == null || tenants == null) {
      emit(const AuthError(error: 'Không có phiên đăng nhập để chọn tenant'));
      return;
    }

    await _authRepository.selectTenant(event.tenantId);
    AppRouterConfig.instance.setAuthState(true, hasTenant: true);
    emit(
      AuthAuthenticated(
        user: user,
        tenants: tenants,
        selectedTenantId: event.tenantId,
      ),
    );
    _safeNavigate(() => AppRouterConfig.instance.goHome());
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    AppRouterConfig.instance.setAuthState(false);
    emit(const AuthUnauthenticated());
    _safeNavigate(() => AppRouterConfig.instance.goLogin());
  }
}
