import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.tenants,
    required this.accessToken,
    required this.refreshToken,
    this.isNewUser,
  });

  final User user;
  final List<TenantMembership> tenants;
  final String accessToken;
  final String refreshToken;
  final bool? isNewUser;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final tenantsJson = json['tenants'];

    return AuthSession(
      user: User.fromJson(
        userJson is Map<String, dynamic>
            ? userJson
            : Map<String, dynamic>.from(userJson as Map? ?? {}),
      ),
      tenants: tenantsJson is List
          ? tenantsJson
              .whereType<Map>()
              .map((e) => TenantMembership.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      isNewUser: json['isNewUser'] as bool?,
    );
  }
}
