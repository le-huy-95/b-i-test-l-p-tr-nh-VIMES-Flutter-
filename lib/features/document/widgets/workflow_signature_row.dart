import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/features/document/workflow_approval_utils.dart';

/// Actions available for a specific step, derived from `AvailableActions`.
class StepAvailableActions {
  const StepAvailableActions({
    required this.stepId,
    required this.actions,
  });

  final String stepId;
  final List<String> actions;

  bool get canApprove => actions.contains('approve');
  bool get canReject => actions.contains('reject');
  bool get canSkip => actions.contains('skip');
  bool get canProxySign => actions.contains('proxy_sign');

  bool get hasMultipleActions => actions.length > 1;
}

class WorkflowSignatureRow extends StatelessWidget {
  const WorkflowSignatureRow({
    super.key,
    required this.roles,
    this.signatureNames,
    required this.steps,
    required this.assignedApproverIds,
    required this.documentStatus,
    required this.currentUserId,
    required this.currentUserRole,
    required this.actionSubmitting,
    required this.onActionTap,
    required this.fitOnOneLine,
    this.stepAvailableActions,
  });

  final List<String> roles;
  final Map<String, String>? signatureNames;
  final List<WorkflowStep> steps;
  final List<String> assignedApproverIds;
  final String documentStatus;
  final String? currentUserId;
  final String? currentUserRole;
  final bool actionSubmitting;
  /// Callback when user taps an action button on a signature slot.
  /// Provides the step and the action code.
  final void Function(WorkflowStep step, String action) onActionTap;
  final Widget Function(Widget child) fitOnOneLine;
  /// Available actions per step, keyed by stepId.
  /// If provided, buttons will reflect the actual available actions from API.
  final Map<String, StepAvailableActions>? stepAvailableActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in roles)
          Expanded(
            child: _SignatureColumn(
              role: role,
              signatureName: signatureNames?[role],
              step: _stepForRole(role),
              canPerformAction: _canPerformAction(role),
              availableActions: _availableActionsForRole(role),
              actionSubmitting: actionSubmitting,
              onActionTap: (action) {
                final step = _stepForRole(role);
                if (step != null) onActionTap(step, action);
              },
              fitOnOneLine: fitOnOneLine,
            ),
          ),
      ],
    );
  }

  bool _canPerformAction(String role) {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) return false;
    final slot = workflowSignatureSlotFromLabel(role);
    if (slot == null) return false;
    return canUserApproveSignatureSlot(
      slot: slot,
      steps: steps,
      userId: userId,
      userRole: currentUserRole,
      assignedApproverIds: assignedApproverIds,
      documentStatus: documentStatus,
    );
  }

  StepAvailableActions? _availableActionsForRole(String role) {
    final step = _stepForRole(role);
    if (step == null) return null;
    return stepAvailableActions?[step.id];
  }

  WorkflowStep? _stepForRole(String role) {
    final slot = workflowSignatureSlotFromLabel(role);
    if (slot == null) return null;
    return workflowStepForSlot(slot, steps);
  }
}

class _SignatureColumn extends StatelessWidget {
  const _SignatureColumn({
    required this.role,
    required this.signatureName,
    required this.step,
    required this.canPerformAction,
    required this.availableActions,
    required this.actionSubmitting,
    required this.onActionTap,
    required this.fitOnOneLine,
  });

  final String role;
  final String? signatureName;
  final WorkflowStep? step;
  final bool canPerformAction;
  final StepAvailableActions? availableActions;
  final bool actionSubmitting;
  final void Function(String action) onActionTap;
  final Widget Function(Widget child) fitOnOneLine;

  @override
  Widget build(BuildContext context) {
    // Use API actions if available, otherwise default to approve
    final hasApprove = availableActions?.canApprove ?? canPerformAction;
    final hasReject = availableActions?.canReject ?? false;

    // Default to approve if user can perform action but no specific actions from API
    final defaultAction = hasApprove ? 'approve' : (hasReject ? 'reject' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fitOnOneLine(
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
          ),
        ),
        if (canPerformAction && defaultAction != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: FilledButton(
              onPressed: actionSubmitting
                  ? null
                  : () => onActionTap(defaultAction),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                backgroundColor: ColorSkin.primary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: fitOnOneLine(
                Text(
                  _actionLabel(defaultAction),
                  style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else ...[
          const SizedBox(height: 30),
        ],
        SizedBox(
          height: 14,
          child: fitOnOneLine(
            Text(
              signatureName?.trim().isNotEmpty == true ? signatureName! : '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        fitOnOneLine(
          const Text(
            '(Ký, họ tên)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }

  String _actionLabel(String action) {
    return switch (action) {
      'approve' => 'Phê duyệt',
      'reject' => 'Từ chối',
      'skip' => 'Bỏ qua',
      'proxy_sign' => 'Ký thay',
      _ => 'Hành động',
    };
  }
}
