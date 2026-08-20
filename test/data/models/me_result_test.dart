import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/auth/me_result.dart';

void main() {
  test('parses nested user and tenants from /auth/me payload', () {
    final result = MeResult.fromJson({
      'user': {
        'id': 'u1',
        'name': 'User One',
        'email': 'a@b.com',
      },
      'tenants': [
        {
          'id': 't1',
          'code': 'ACME',
          'name': 'Acme Corp',
          'role': 'admin',
        },
      ],
    });

    expect(result.user.id, 'u1');
    expect(result.user.email, 'a@b.com');
    expect(result.tenants, hasLength(1));
    expect(result.tenants.single.code, 'ACME');
  });

  test('parses flat user payload with memberships fallback key', () {
    final result = MeResult.fromJson({
      'id': 'u2',
      'name': 'Flat User',
      'memberships': [
        {
          '_id': 't2',
          'code': 'VIMES',
          'name': 'VIMES',
          'role': 'admin',
        },
      ],
    });

    expect(result.user.id, 'u2');
    expect(result.tenants.single.id, 't2');
    expect(result.tenants.single.code, 'VIMES');
  });
}
