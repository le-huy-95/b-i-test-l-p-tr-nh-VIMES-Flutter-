import 'package:equatable/equatable.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.credentials,
    required this.password,
  });

  final String credentials;
  final String password;

  @override
  List<Object?> get props => [credentials, password];
}

class LoginGoogleRequested extends LoginEvent {
  const LoginGoogleRequested(this.idToken);

  final String idToken;

  @override
  List<Object?> get props => [idToken];
}
