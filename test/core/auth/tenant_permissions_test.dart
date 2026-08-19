import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';

void main() {
  group('tenant selection helpers', () {
    test('current tenant resolves selected membership', () {
      final state = AuthAuthenticated(
        user: const User(id: 'u1', name: 'U'),
        tenants: const [
          TenantMembership(id: 't1', code: 'T1', name: 'One', role: 'viewer'),
          TenantMembership(id: 't2', code: 'T2', name: 'Two', role: 'admin'),
        ],
        selectedTenantId: 't2',
      );

      expect(currentTenantFromAuthState(state)?.id, 't2');
      expect(currentTenantRoleFromAuthState(state), 'admin');
      expect(hasSelectedTenant(state), isTrue);
      expect(canManageMasterDataForAuthState(state), isTrue);
    });

    test('unselected auth state has no tenant', () {
      final state = AuthAuthenticated(
        user: const User(id: 'u1', name: 'U'),
        tenants: const [],
        selectedTenantId: 'missing',
      );

      expect(currentTenantFromAuthState(state), isNull);
      expect(currentTenantRoleFromAuthState(state), isNull);
      expect(hasSelectedTenant(state), isFalse);
      expect(canManageMasterDataForAuthState(state), isFalse);
    });
  });

  group('canManageMasterData', () {
    test('admin, keeper and accountant can manage', () {
      expect(canManageMasterData('admin'), isTrue);
      expect(canManageMasterData('warehouse_keeper'), isTrue);
      expect(canManageMasterData('accountant'), isTrue);
    });

    test('other roles cannot manage', () {
      expect(canManageMasterData('approver'), isFalse);
      expect(canManageMasterData('viewer'), isFalse);
    });
  });

  group('stock doc RBAC', () {
    test('keeper can create/submit/cancel, cannot approve', () {
      expect(canCreateOrSubmitStockDoc('warehouse_keeper'), isTrue);
      expect(canCancelStockDoc('warehouse_keeper'), isTrue);
      expect(canApproveOrCompleteStockDoc('warehouse_keeper'), isFalse);
    });

    test('accountant can approve, cannot create', () {
      expect(canApproveOrCompleteStockDoc('accountant'), isTrue);
      expect(canApproveOrCompleteStockDoc('approver'), isTrue);
      expect(canCreateOrSubmitStockDoc('accountant'), isFalse);
      expect(canCancelStockDoc('accountant'), isFalse);
    });

    test('viewer cannot write', () {
      expect(canCreateOrSubmitStockDoc('viewer'), isFalse);
      expect(canApproveOrCompleteStockDoc('viewer'), isFalse);
      expect(canCancelStockDoc('viewer'), isFalse);
    });
  });

  group('visibleReceiptActions', () {
    test('draft + keeper → submit, cancel', () {
      expect(
        visibleReceiptActions(status: 'draft', role: 'warehouse_keeper'),
        [StockDocAction.submit, StockDocAction.cancel],
      );
    });

    test('pending_approval + approver → approve, delegate, reject', () {
      expect(
        visibleReceiptActions(status: 'pending_approval', role: 'approver'),
        [
          StockDocAction.approve,
          StockDocAction.delegate,
          StockDocAction.reject,
        ],
      );
    });

    test('pending_approval + keeper → cancel only', () {
      expect(
        visibleReceiptActions(status: 'pending_approval', role: 'warehouse_keeper'),
        [StockDocAction.cancel],
      );
    });

    test('approved + accountant → complete', () {
      expect(
        visibleReceiptActions(status: 'approved', role: 'accountant'),
        [StockDocAction.complete],
      );
    });

    test('rejected + keeper → clone', () {
      expect(
        visibleReceiptActions(status: 'rejected', role: 'warehouse_keeper'),
        [StockDocAction.clone],
      );
    });

    test('completed + admin → empty', () {
      expect(visibleReceiptActions(status: 'completed', role: 'admin'), isEmpty);
    });
  });

  group('visibleIssueActions', () {
    test('rejected has no clone', () {
      expect(
        visibleIssueActions(status: 'rejected', role: 'warehouse_keeper'),
        isEmpty,
      );
    });
  });
}
