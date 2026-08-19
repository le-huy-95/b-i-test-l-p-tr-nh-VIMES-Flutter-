import 'package:test_y_app/data/datasources/api_services/tenant_people_api_service.dart';
import 'package:test_y_app/data/models/tenant/tenant_invitation.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/domain/repositories/tenant_people_repository.dart';

class TenantPeopleRepositoryImpl implements TenantPeopleRepository {
  TenantPeopleRepositoryImpl({TenantPeopleApiService? apiService})
      : _api = apiService ?? TenantPeopleApiService();

  final TenantPeopleApiService _api;

  @override
  Future<TenantMemberPageResult> fetchMembers({
    int page = 1,
    int limit = 20,
    String? search,
  }) {
    return _api.fetchMembers(page: page, limit: limit, search: search);
  }

  @override
  Future<TenantInvitationPageResult> fetchInvitations({
    int page = 1,
    int limit = 20,
    String? search,
  }) {
    return _api.fetchInvitations(page: page, limit: limit, search: search);
  }

  @override
  Future<CreateInvitationResult> createInvitation({
    required String email,
    String role = 'viewer',
  }) {
    return _api.createInvitation(email: email, role: role);
  }

  @override
  Future<AcceptInvitationResult> acceptInvitation({required String invitationId}) {
    return _api.acceptInvitation(invitationId: invitationId);
  }

  @override
  Future<DeclineInvitationResult> declineInvitation({required String invitationId}) {
    return _api.declineInvitation(invitationId: invitationId);
  }

  @override
  Future<CreateTenantUserResult> createTenantUser({
    String? email,
    String? phone,
    String? name,
    required String password,
    String role = 'warehouse_keeper',
    List<String>? warehouseIds,
  }) {
    return _api.createTenantUser(
      email: email,
      phone: phone,
      name: name,
      password: password,
      role: role,
      warehouseIds: warehouseIds,
    );
  }
}
