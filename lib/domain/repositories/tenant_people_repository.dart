import 'package:test_y_app/data/models/tenant/tenant_invitation.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';

abstract class TenantPeopleRepository {
  Future<TenantMemberPageResult> fetchMembers({
    int page = 1,
    int limit = 20,
    String? search,
  });

  Future<TenantInvitationPageResult> fetchInvitations({
    int page = 1,
    int limit = 20,
    String? search,
  });

  Future<CreateInvitationResult> createInvitation({
    required String email,
    String role = 'viewer',
  });

  Future<AcceptInvitationResult> acceptInvitation({required String invitationId});

  Future<DeclineInvitationResult> declineInvitation({required String invitationId});

  Future<CreateTenantUserResult> createTenantUser({
    String? email,
    String? phone,
    String? name,
    required String password,
    String role = 'warehouse_keeper',
    List<String>? warehouseIds,
  });
}
