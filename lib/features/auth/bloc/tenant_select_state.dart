import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

sealed class TenantSelectState extends Equatable {
  const TenantSelectState();

  @override
  List<Object?> get props => [];
}

class TenantSelectInitial extends TenantSelectState {
  const TenantSelectInitial({this.tenants = const []});

  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [tenants];
}

class TenantSelectLoading extends TenantSelectState {
  const TenantSelectLoading({required this.tenants});

  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [tenants];
}

class TenantSelectRefreshing extends TenantSelectState {
  const TenantSelectRefreshing({required this.tenants});

  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [tenants];
}

class TenantSelectSelected extends TenantSelectState {
  const TenantSelectSelected({
    required this.tenants,
    required this.tenantId,
  });

  final List<TenantMembership> tenants;
  final String tenantId;

  @override
  List<Object?> get props => [tenants, tenantId];
}

class TenantSelectCreated extends TenantSelectState {
  const TenantSelectCreated({
    required this.tenants,
    required this.created,
    this.logoUploadWarning,
  });

  final List<TenantMembership> tenants;
  final TenantMembership created;
  final String? logoUploadWarning;

  @override
  List<Object?> get props => [tenants, created, logoUploadWarning];
}

class TenantSelectFailure extends TenantSelectState {
  const TenantSelectFailure({
    required this.tenants,
    required this.message,
  });

  final List<TenantMembership> tenants;
  final String message;

  @override
  List<Object?> get props => [tenants, message];
}
