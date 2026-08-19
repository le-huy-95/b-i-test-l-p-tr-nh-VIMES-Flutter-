import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

enum TenantDestination { home, selectTenant }

class TenantRouteResult {
  final TenantDestination destination;
  final String? tenantId;

  const TenantRouteResult({required this.destination, this.tenantId});
}

TenantRouteResult resolveTenantRoute({
  required List<TenantMembership> tenants,
  required String? savedTenantId,
}) {
  if (tenants.isEmpty) {
    return const TenantRouteResult(destination: TenantDestination.selectTenant);
  }

  if (tenants.length == 1) {
    return TenantRouteResult(
      destination: TenantDestination.home,
      tenantId: tenants.first.id,
    );
  }

  final saved = savedTenantId;
  if (saved != null &&
      saved.isNotEmpty &&
      tenants.any((t) => t.id == saved)) {
    return TenantRouteResult(
      destination: TenantDestination.home,
      tenantId: saved,
    );
  }

  return const TenantRouteResult(destination: TenantDestination.selectTenant);
}
