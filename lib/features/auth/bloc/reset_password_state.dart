import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/auth/forgot_password_result.dart';

sealed class ResetPasswordState extends Equatable {
  const ResetPasswordState();

  @override
  List<Object?> get props => [];
}

final class ResetPasswordInitial extends ResetPasswordState {
  const ResetPasswordInitial();
}

final class ResetPasswordLoading extends ResetPasswordState {
  const ResetPasswordLoading();
}

final class ResetPasswordSuccess extends ResetPasswordState {
  const ResetPasswordSuccess();
}

final class ResetPasswordOtpResent extends ResetPasswordState {
  const ResetPasswordOtpResent({this.result});

  final ForgotPasswordResult? result;

  @override
  List<Object?> get props => [result];
}

final class ResetPasswordFailure extends ResetPasswordState {
  const ResetPasswordFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
