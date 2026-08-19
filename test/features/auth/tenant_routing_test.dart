import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/features/auth/utils/tenant_routing.dart';

TenantMembership fakeTenant(String id) {
  return TenantMembership(
    id: id,
    code: id.toUpperCase(),
    name: 'Tenant $id',
    role: 'admin',
  );
}

void main() {
  test('one tenant -> home with that id', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1')],
      savedTenantId: null,
    );
    expect(r.destination, TenantDestination.home);
    expect(r.tenantId, 't1');
  });

  test('many without saved -> selectTenant', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1'), fakeTenant('t2')],
      savedTenantId: null,
    );
    expect(r.destination, TenantDestination.selectTenant);
    expect(r.tenantId, isNull);
  });

  test('many with valid saved -> home with saved id', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1'), fakeTenant('t2')],
      savedTenantId: 't2',
    );
    expect(r.destination, TenantDestination.home);
    expect(r.tenantId, 't2');
  });

  test('many with invalid saved -> selectTenant', () {
    final r = resolveTenantRoute(
      tenants: [fakeTenant('t1'), fakeTenant('t2')],
      savedTenantId: 'missing',
    );
    expect(r.destination, TenantDestination.selectTenant);
    expect(r.tenantId, isNull);
  });

  test('zero -> selectTenant', () {
    final r = resolveTenantRoute(tenants: [], savedTenantId: null);
    expect(r.destination, TenantDestination.selectTenant);
    expect(r.tenantId, isNull);
  });
}
