import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';

/// Tenant RBAC helpers for master-data screens (warehouse / product).
String normalizeTenantRole(String role) => role.trim().toLowerCase();

String tenantRoleLabel(String role) {
  return switch (normalizeTenantRole(role)) {
    'admin' => 'Admin',
    'warehouse_keeper' => 'Thủ kho',
    'accountant' => 'Kế toán',
    'approver' => 'Duyệt',
    'viewer' => 'Người xem',
    _ => role.trim().isEmpty ? '—' : role.trim(),
  };
}

TenantMembership? currentTenantFromAuthState(AuthState authState) {
  switch (authState) {
    case AuthAuthenticated(:final tenants, :final selectedTenantId):
      for (final tenant in tenants) {
        if (tenant.id == selectedTenantId) {
          return tenant;
        }
      }
      return null;
    default:
      return null;
  }
}

String? currentTenantRoleFromAuthState(AuthState authState) {
  return currentTenantFromAuthState(authState)?.role;
}

bool hasSelectedTenant(AuthState authState) =>
    currentTenantFromAuthState(authState) != null;

bool canManageMasterData(String role) {
  final normalized = normalizeTenantRole(role);
  return normalized == 'admin' ||
      normalized == 'warehouse_keeper' ||
      normalized == 'accountant';
}

bool canManageMasterDataForAuthState(AuthState authState) {
  final role = currentTenantRoleFromAuthState(authState);
  return role != null && canManageMasterData(role);
}

bool canCreateMasterData(String role) {
  final normalized = normalizeTenantRole(role);
  return normalized == 'admin' ||
      normalized == 'warehouse_keeper' ||
      normalized == 'accountant';
}

bool canCreateMasterDataForAuthState(AuthState authState) {
  final role = currentTenantRoleFromAuthState(authState);
  return role != null && canCreateMasterData(role);
}

bool canCreateOrSubmitStockDoc(String role) =>
    normalizeTenantRole(role) == 'admin' ||
    normalizeTenantRole(role) == 'warehouse_keeper';

bool canApproveOrCompleteStockDoc(String role) =>
    normalizeTenantRole(role) == 'admin' ||
    normalizeTenantRole(role) == 'accountant' ||
    normalizeTenantRole(role) == 'approver';

bool canCancelStockDoc(String role) =>
    normalizeTenantRole(role) == 'admin' ||
    normalizeTenantRole(role) == 'warehouse_keeper';

/// Tenant people management helpers.
bool canManageTenantPeople(String role) => normalizeTenantRole(role) == 'admin';

bool canViewInvitations(String role) => true;
