import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/otp_event.dart';
import 'package:test_y_app/features/auth/bloc/otp_state.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  OtpBloc({
    required AuthRepository authRepository,
    this.email,
    this.phone,
  })  : _authRepository = authRepository,
        super(const OtpInitial()) {
    on<OtpVerifyRequested>(_onVerifyRequested);
    on<OtpResendRequested>(_onResendRequested);
  }

  final AuthRepository _authRepository;
  final String? email;
  final String? phone;

  Future<void> _onVerifyRequested(
    OtpVerifyRequested event,
    Emitter<OtpState> emit,
  ) async {
    emit(const OtpLoading());
    try {
      await _authRepository.verifyOtp(
        email: email,
        phone: phone,
        code: event.code,
      );
      emit(const OtpVerified());
    } catch (e) {
      emit(OtpFailure(e.toString()));
    }
  }

  Future<void> _onResendRequested(
    OtpResendRequested event,
    Emitter<OtpState> emit,
  ) async {
    emit(const OtpLoading());
    try {
      final next = await _authRepository.resendOtp(email: email, phone: phone);
      emit(OtpResent(nextResendAt: next));
    } catch (e) {
      emit(OtpFailure(e.toString()));
    }
  }
}
