import 'package:equatable/equatable.dart';

sealed class OtpState extends Equatable {
  const OtpState();

  @override
  List<Object?> get props => [];
}

class OtpInitial extends OtpState {
  const OtpInitial();
}

class OtpLoading extends OtpState {
  const OtpLoading();
}

class OtpVerified extends OtpState {
  const OtpVerified();
}

class OtpResent extends OtpState {
  const OtpResent({this.nextResendAt});

  final DateTime? nextResendAt;

  @override
  List<Object?> get props => [nextResendAt];
}

class OtpFailure extends OtpState {
  const OtpFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
