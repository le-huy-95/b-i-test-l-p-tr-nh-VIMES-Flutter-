import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

sealed class TenantSelectEvent extends Equatable {
  const TenantSelectEvent();

  @override
  List<Object?> get props => [];
}

class TenantSelectLoadRequested extends TenantSelectEvent {
  const TenantSelectLoadRequested(this.tenants);

  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [tenants];
}

class TenantSelectRefreshRequested extends TenantSelectEvent {
  const TenantSelectRefreshRequested();
}

class TenantSelectCreateRequested extends TenantSelectEvent {
  const TenantSelectCreateRequested({
    required this.code,
    required this.name,
    this.logoFilePath,
  });

  final String code;
  final String name;
  final String? logoFilePath;

  @override
  List<Object?> get props => [code, name, logoFilePath];
}
