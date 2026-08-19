import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_event.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_state.dart';

class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const ForgotPasswordInitial()) {
    on<ForgotPasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _authRepository;

  Future<void> _onSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(const ForgotPasswordLoading());
    try {
      final result = await _authRepository.forgotPassword(
        email: event.email.trim(),
      );
      emit(ForgotPasswordSuccess(email: event.email.trim(), result: result));
    } catch (e) {
      emit(ForgotPasswordFailure(_friendlyError(e)));
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
