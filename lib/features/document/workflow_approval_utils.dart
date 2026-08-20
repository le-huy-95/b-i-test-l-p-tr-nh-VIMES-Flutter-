import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';

/// Vị trí ký duyệt trên phiếu (theo thứ tự `workflowAssignedApproverIds`).
enum WorkflowSignatureSlot {
  deliveryApprover,
  warehouseKeeper,
  chiefAccountant,
}

WorkflowSignatureSlot? workflowSignatureSlotFromLabel(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized.contains('giao hàng') && normalized.contains('ký')) {
    return WorkflowSignatureSlot.deliveryApprover;
  }
  if (normalized == 'người giao hàng' ||
      (normalized.contains('giao hàng') && !normalized.contains('ký'))) {
    return WorkflowSignatureSlot.deliveryApprover;
  }
  if (normalized.contains('thủ kho')) {
    return WorkflowSignatureSlot.warehouseKeeper;
  }
  if (normalized.contains('kế toán')) {
    return WorkflowSignatureSlot.chiefAccountant;
  }
  return null;
}

int workflowApproverIndex(WorkflowSignatureSlot slot) {
  return switch (slot) {
    WorkflowSignatureSlot.deliveryApprover => 0,
    WorkflowSignatureSlot.warehouseKeeper => 1,
    WorkflowSignatureSlot.chiefAccountant => 2,
  };
}

List<String> assignedApproverIdsFromWorkflowSteps(List<WorkflowStep> steps) {
  final sorted = [...steps]..sort((a, b) => a.sequence.compareTo(b.sequence));
  return sorted
      .map((step) => step.assignedApproverId ?? step.requiredSignerId ?? '')
      .toList();
}

String? assignedApproverIdForSlot(
  WorkflowSignatureSlot slot,
  List<String> assignedApproverIds,
) {
  final index = workflowApproverIndex(slot);
  if (index >= assignedApproverIds.length) return null;
  final id = assignedApproverIds[index].trim();
  return id.isEmpty ? null : id;
}

WorkflowStep? workflowStepForSlot(
  WorkflowSignatureSlot slot,
  List<WorkflowStep> steps,
) {
  final index = workflowApproverIndex(slot);
  final sorted = [...steps]..sort((a, b) => a.sequence.compareTo(b.sequence));

  if (index < sorted.length) {
    return sorted[index];
  }

  final codeHints = switch (slot) {
    WorkflowSignatureSlot.deliveryApprover => ['delivery', 'giao', 'step_1'],
    WorkflowSignatureSlot.warehouseKeeper => [
        'warehouse',
        'keeper',
        'thu_kho',
        'step_2',
      ],
    WorkflowSignatureSlot.chiefAccountant => [
        'accountant',
        'ke_toan',
        'step_3',
      ],
  };

  for (final step in sorted) {
    final code = step.stepCode.toLowerCase();
    if (codeHints.any(code.contains)) return step;
  }
  return null;
}

WorkflowStep? currentActiveWorkflowStep(List<WorkflowStep> steps) {
  final activeSteps =
      steps.where((step) => isWorkflowStepActive(step.status)).toList();
  if (activeSteps.isEmpty) return null;
  activeSteps.sort((a, b) => a.sequence.compareTo(b.sequence));
  return activeSteps.first;
}

bool isDocumentAwaitingWorkflowApproval(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'pending_approval' ||
      normalized == 'in_review' ||
      normalized == 'pending' ||
      normalized == 'waiting';
}

bool canUserApproveWorkflowStep({
  required WorkflowStep step,
  required String userId,
  required String? userRole,
  String? expectedApproverId,
}) {
  if (!isWorkflowStepActive(step.status)) return false;

  final assignee = (step.assignedApproverId ??
          step.requiredSignerId ??
          expectedApproverId)
      ?.trim();
  if (assignee == null || assignee.isEmpty) return false;
  if (assignee != userId) return false;

  final normalizedRole = normalizeTenantRole(userRole ?? '');
  if (normalizedRole == 'admin') return true;
  return canApproveOrCompleteStockDoc(normalizedRole) ||
      normalizedRole == 'warehouse_keeper';
}

bool canUserApproveSignatureSlot({
  required WorkflowSignatureSlot slot,
  required List<WorkflowStep> steps,
  required String userId,
  required String? userRole,
  required List<String> assignedApproverIds,
  required String documentStatus,
}) {
  if (!isDocumentAwaitingWorkflowApproval(documentStatus)) return false;

  final step = workflowStepForSlot(slot, steps);
  if (step == null) return false;

  final activeStep = currentActiveWorkflowStep(steps);
  if (activeStep == null || activeStep.id != step.id) return false;

  final expectedId = assignedApproverIdForSlot(slot, assignedApproverIds);
  return canUserApproveWorkflowStep(
    step: step,
    userId: userId,
    userRole: userRole,
    expectedApproverId: expectedId,
  );
}

WorkflowStep? findApprovableStepForUser({
  required List<WorkflowStep> steps,
  required String userId,
  required String? userRole,
  required String documentStatus,
  List<String> assignedApproverIds = const [],
}) {
  if (!isDocumentAwaitingWorkflowApproval(documentStatus)) return null;

  final activeStep = currentActiveWorkflowStep(steps);
  if (activeStep == null) return null;

  final approverIds = assignedApproverIds.isNotEmpty
      ? assignedApproverIds
      : assignedApproverIdsFromWorkflowSteps(steps);

  for (final slot in WorkflowSignatureSlot.values) {
    if (canUserApproveSignatureSlot(
      slot: slot,
      steps: steps,
      userId: userId,
      userRole: userRole,
      assignedApproverIds: approverIds,
      documentStatus: documentStatus,
    )) {
      return workflowStepForSlot(slot, steps);
    }
  }

  if (canUserApproveWorkflowStep(
    step: activeStep,
    userId: userId,
    userRole: userRole,
    expectedApproverId:
        activeStep.assignedApproverId ?? activeStep.requiredSignerId,
  )) {
    return activeStep;
  }

  return null;
}

void seedApproverControllersFromWorkflowSteps({
  required List<WorkflowStep> steps,
  required void Function(String deliveryApproverId) setDeliveryApprover,
  required void Function(String warehouseKeeperId) setWarehouseKeeper,
  required void Function(String chiefAccountantId) setChiefAccountant,
  required bool Function() hasDeliveryApprover,
  required bool Function() hasWarehouseKeeper,
  required bool Function() hasChiefAccountant,
}) {
  final sorted = [...steps]..sort((a, b) => a.sequence.compareTo(b.sequence));
  if (sorted.isEmpty) return;

  void apply(int index, void Function(String id) setter, bool Function() hasValue) {
    if (index >= sorted.length || hasValue()) return;
    final id =
        (sorted[index].assignedApproverId ?? sorted[index].requiredSignerId)
            ?.trim();
    if (id == null || id.isEmpty) return;
    setter(id);
  }

  apply(0, setDeliveryApprover, hasDeliveryApprover);
  apply(1, setWarehouseKeeper, hasWarehouseKeeper);
  apply(2, setChiefAccountant, hasChiefAccountant);
}
