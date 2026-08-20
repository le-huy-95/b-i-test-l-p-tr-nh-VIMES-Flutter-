import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/features/document/workflow_approval_utils.dart';

WorkflowStep _step({
  required String id,
  required int sequence,
  required String status,
  String? assignedApproverId,
  String stepCode = '',
}) {
  return WorkflowStep(
    id: id,
    stepCode: stepCode,
    stepName: 'Step $sequence',
    sequence: sequence,
    status: status,
    assignedApproverId: assignedApproverId,
  );
}

void main() {
  group('workflow approval utils', () {
    test('maps signature labels to slots', () {
      expect(
        workflowSignatureSlotFromLabel('Thủ kho'),
        WorkflowSignatureSlot.warehouseKeeper,
      );
      expect(
        workflowSignatureSlotFromLabel('Kế toán trưởng'),
        WorkflowSignatureSlot.chiefAccountant,
      );
      expect(
        workflowSignatureSlotFromLabel('Người giao hàng'),
        WorkflowSignatureSlot.deliveryApprover,
      );
    });

    test('allows assigned user on active step only', () {
      final steps = [
        _step(
          id: 's1',
          sequence: 1,
          status: 'approved',
          assignedApproverId: 'u1',
        ),
        _step(
          id: 's2',
          sequence: 2,
          status: 'pending',
          assignedApproverId: 'u2',
        ),
        _step(
          id: 's3',
          sequence: 3,
          status: 'waiting',
          assignedApproverId: 'u3',
        ),
      ];

      expect(
        canUserApproveSignatureSlot(
          slot: WorkflowSignatureSlot.warehouseKeeper,
          steps: steps,
          userId: 'u2',
          userRole: 'warehouse_keeper',
          assignedApproverIds: ['u1', 'u2', 'u3'],
          documentStatus: 'pending_approval',
        ),
        isTrue,
      );

      expect(
        canUserApproveSignatureSlot(
          slot: WorkflowSignatureSlot.chiefAccountant,
          steps: steps,
          userId: 'u3',
          userRole: 'accountant',
          assignedApproverIds: ['u1', 'u2', 'u3'],
          documentStatus: 'pending_approval',
        ),
        isFalse,
      );
    });

    test('findApprovableStepForUser returns current active step', () {
      final steps = [
        _step(
          id: 's1',
          sequence: 1,
          status: 'approved',
          assignedApproverId: 'u1',
        ),
        _step(
          id: 's2',
          sequence: 2,
          status: 'in_review',
          assignedApproverId: 'u2',
        ),
      ];

      final step = findApprovableStepForUser(
        steps: steps,
        userId: 'u2',
        userRole: 'warehouse_keeper',
        documentStatus: 'in_review',
        assignedApproverIds: ['u1', 'u2', 'u3'],
      );

      expect(step?.id, 's2');
    });
  });
}
