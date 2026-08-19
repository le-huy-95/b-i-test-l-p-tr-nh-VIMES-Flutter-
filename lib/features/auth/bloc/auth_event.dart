import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.credentials, required this.password});

  final String credentials;
  final String password;

  @override
  List<Object?> get props => [credentials, password];
}

class AuthSessionEstablished extends AuthEvent {
  const AuthSessionEstablished(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthTenantSelected extends AuthEvent {
  const AuthTenantSelected(this.tenantId);

  final String tenantId;

  @override
  List<Object?> get props => [tenantId];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
