import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

class CreateTenantWithLogoResult {
  const CreateTenantWithLogoResult({
    required this.tenant,
    this.logoUploadWarning,
  });

  final TenantMembership tenant;
  final String? logoUploadWarning;
}
