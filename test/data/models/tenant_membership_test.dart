import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

void main() {
  test('TenantMembership.fromJson parses logoUrl', () {
    final tenant = TenantMembership.fromJson({
      'id': 't1',
      'code': 'ACME',
      'name': 'Acme Corp',
      'role': 'admin',
      'logoUrl': 'http://example.com/logo.png',
      'status': 'active',
    });

    expect(tenant.id, 't1');
    expect(tenant.code, 'ACME');
    expect(tenant.name, 'Acme Corp');
    expect(tenant.role, 'admin');
    expect(tenant.logoUrl, 'http://example.com/logo.png');
    expect(tenant.status, 'active');
  });

  test('TenantMembership.fromJson handles null logoUrl', () {
    final tenant = TenantMembership.fromJson({
      'id': 't1',
      'code': 'ACME',
      'name': 'Acme Corp',
      'role': 'admin',
      'logoUrl': null,
    });

    expect(tenant.logoUrl, isNull);
  });
}
