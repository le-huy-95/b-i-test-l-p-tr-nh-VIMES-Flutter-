import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';

void main() {
  test('parses login data with tenants', () {
    final session = AuthSession.fromJson({
      'user': {
        'id': 'u1',
        'email': 'a@b.com',
        'phone': null,
        'name': 'A',
        'emailVerified': true,
        'phoneVerified': false,
        'isPlatformAdmin': false,
      },
      'tenants': [
        {
          'id': 't1',
          'code': 'ACME',
          'name': 'Acme',
          'role': 'admin',
          'status': 'active',
        }
      ],
      'accessToken': 'at',
      'refreshToken': 'rt',
    });
    expect(session.user.email, 'a@b.com');
    expect(session.tenants.single.code, 'ACME');
    expect(session.accessToken, 'at');
  });
}
