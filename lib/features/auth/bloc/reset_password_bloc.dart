import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/reset_password_event.dart';
import 'package:test_y_app/features/auth/bloc/reset_password_state.dart';

class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc({
    required AuthRepository authRepository,
    required this.email,
  })  : _authRepository = authRepository,
        super(const ResetPasswordInitial()) {
    on<ResetPasswordSubmitted>(_onSubmitted);
    on<ResetPasswordResendRequested>(_onResendRequested);
  }

  final AuthRepository _authRepository;
  final String email;

  Future<void> _onSubmitted(
    ResetPasswordSubmitted event,
    Emitter<ResetPasswordState> emit,
  ) async {
    emit(const ResetPasswordLoading());
    try {
      await _authRepository.resetPassword(
        email: email,
        code: event.code,
        newPassword: event.newPassword,
      );
      emit(const ResetPasswordSuccess());
    } catch (e) {
      emit(ResetPasswordFailure(_friendlyError(e)));
    }
  }

  Future<void> _onResendRequested(
    ResetPasswordResendRequested event,
    Emitter<ResetPasswordState> emit,
  ) async {
    emit(const ResetPasswordLoading());
    try {
      final result = await _authRepository.forgotPassword(email: email);
      emit(ResetPasswordOtpResent(result: result));
    } catch (e) {
      emit(ResetPasswordFailure(_friendlyError(e)));
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
