import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/login_event.dart';
import 'package:test_y_app/features/auth/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
    on<LoginGoogleRequested>(_onGoogleRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final session = await _authRepository.login(
        credentials: event.credentials,
        password: event.password,
      );
      emit(LoginSuccess(session));
    } catch (e) {
      emit(LoginFailure(_friendlyError(e)));
    }
  }

  Future<void> _onGoogleRequested(
    LoginGoogleRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final session = await _authRepository.loginWithGoogle(
        idToken: event.idToken,
      );
      emit(LoginSuccess(session));
    } catch (e) {
      emit(LoginFailure(_friendlyError(e)));
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }
}
