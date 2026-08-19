import 'package:equatable/equatable.dart';

sealed class ResetPasswordEvent extends Equatable {
  const ResetPasswordEvent();

  @override
  List<Object?> get props => [];
}

final class ResetPasswordSubmitted extends ResetPasswordEvent {
  const ResetPasswordSubmitted({
    required this.code,
    required this.newPassword,
  });

  final String code;
  final String newPassword;

  @override
  List<Object?> get props => [code, newPassword];
}

final class ResetPasswordResendRequested extends ResetPasswordEvent {
  const ResetPasswordResendRequested();
}
