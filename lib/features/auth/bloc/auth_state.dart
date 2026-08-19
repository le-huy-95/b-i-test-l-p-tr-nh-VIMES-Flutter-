import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.user,
    required this.tenants,
    required this.selectedTenantId,
  });

  final User user;
  final List<TenantMembership> tenants;
  final String selectedTenantId;

  @override
  List<Object?> get props => [user, tenants, selectedTenantId];
}

class AuthNeedsTenant extends AuthState {
  const AuthNeedsTenant({
    required this.user,
    required this.tenants,
  });

  final User user;
  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [user, tenants];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  const AuthError({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
