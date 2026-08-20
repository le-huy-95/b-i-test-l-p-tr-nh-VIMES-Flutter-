import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';

class MeResult {
  const MeResult({
    required this.user,
    required this.tenants,
  });

  final User user;
  final List<TenantMembership> tenants;

  factory MeResult.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final userMap = userJson is Map<String, dynamic>
        ? userJson
        : userJson is Map
            ? Map<String, dynamic>.from(userJson)
            : json;

    return MeResult(
      user: User.fromJson(userMap),
      tenants: parseTenantMemberships(json),
    );
  }

  /// Parses tenant memberships from `/auth/me` (and compatible login payloads).
  static List<TenantMembership> parseTenantMemberships(Map<String, dynamic> json) {
    final tenantsJson =
        json['tenants'] ?? json['memberships'] ?? json['tenantMemberships'];

    if (tenantsJson is! List) return const [];

    return tenantsJson
        .whereType<Map>()
        .map((e) => TenantMembership.fromJson(Map<String, dynamic>.from(e)))
        .where((tenant) => tenant.id.isNotEmpty)
        .toList();
  }
}
