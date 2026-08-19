import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/auth/forgot_password_result.dart';

sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

final class ForgotPasswordInitial extends ForgotPasswordState {
  const ForgotPasswordInitial();
}

final class ForgotPasswordLoading extends ForgotPasswordState {
  const ForgotPasswordLoading();
}

final class ForgotPasswordSuccess extends ForgotPasswordState {
  const ForgotPasswordSuccess({
    required this.email,
    required this.result,
  });

  final String email;
  final ForgotPasswordResult result;

  @override
  List<Object?> get props => [email, result];
}

final class ForgotPasswordFailure extends ForgotPasswordState {
  const ForgotPasswordFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
