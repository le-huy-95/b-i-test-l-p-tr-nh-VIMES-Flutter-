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
    final tenantsJson = json['tenants'];
    return MeResult(
      user: User.fromJson(json),
      tenants: tenantsJson is List
          ? tenantsJson
              .whereType<Map>()
              .map((e) => TenantMembership.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
