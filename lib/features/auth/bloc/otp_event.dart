import 'package:equatable/equatable.dart';

sealed class OtpEvent extends Equatable {
  const OtpEvent();

  @override
  List<Object?> get props => [];
}

class OtpVerifyRequested extends OtpEvent {
  const OtpVerifyRequested(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

class OtpResendRequested extends OtpEvent {
  const OtpResendRequested();
}
