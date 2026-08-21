import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';
import 'package:test_y_app/features/document/document_formatters.dart';
import 'package:test_y_app/features/document/workflow_approval_utils.dart';
import 'package:test_y_app/features/document/widgets/workflow_action_dialog.dart';
import 'package:test_y_app/features/document/widgets/workflow_approval_bottom_sheet.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';

/// Bottom sheet showing workflow approval steps, notes, and available actions.
class DocumentDetailBottomSheet extends StatelessWidget {
  const DocumentDetailBottomSheet({super.key, required this.listItem});

  final StockDocument listItem;

  static Future<void> show(
    BuildContext context, {
    required StockDocument item,
  }) {
    final bloc = context.read<StockDocumentBloc>();
    bloc.add(StockDocumentSelected(item.documentId));
    return AppBottomSheetService.show<void>(
      context: context,
      title: stockDocumentDisplayCode(item),
      showCloseButton: true,
      maxHeightFactor: 0.85,
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      // Modal route sits outside DocumentPage's provider tree.
      content: BlocProvider.value(
        value: bloc,
        child: DocumentDetailBottomSheet(listItem: item),
      ),
      actions: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockDocumentBloc, StockDocumentState>(
      builder: (context, state) {
        if (state is! StockDocumentLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.isDetailLoading ||
            state.selectedId != listItem.documentId) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final detail = state.detail;
        if (detail == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Không tải được chi tiết phiếu'),
          );
        }

        return _DocumentDetailContent(
          detail: detail,
          available: state.availableActions,
          timeline: state.timeline,
          isActionSubmitting: state.isActionSubmitting,
        );
      },
    );
  }
}

class _DocumentDetailContent extends StatelessWidget {
  const _DocumentDetailContent({
    required this.detail,
    required this.available,
    required this.timeline,
    required this.isActionSubmitting,
  });

  final StockDocument detail;
  final AvailableActions? available;
  final List<TimelineEvent> timeline;
  final bool isActionSubmitting;

  String? _currentUserId(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated && auth.user.id.isNotEmpty) {
      return auth.user.id;
    }
    return null;
  }

  Future<void> _openEdit(BuildContext context) async {
    Navigator.of(context).pop();
    final path = detail.documentType == 'stock_issue'
        ? AppRoutes.stockIssueEdit.path.replaceFirst(':id', detail.documentId)
        : AppRoutes.stockReceiptEdit.path.replaceFirst(
            ':id',
            detail.documentId,
          );
    await context.push<bool>(path);
    if (!context.mounted) return;
    context.read<StockDocumentBloc>().add(
      StockDocumentRefreshRequested(detail.documentType),
    );
  }

  Future<void> _confirmAction({
    required BuildContext context,
    required WorkflowStep step,
    required StockDocAction action,
  }) async {
    if (action == StockDocAction.approve) {
      await WorkflowApprovalBottomSheet.show(
        context,
        stepName: step.stepName,
        stepId: step.id,
        actions: const ['approve'],
        onSubmit:
            (selectedAction, note, proxySignerId, authorizationIds) async {
              final body = <String, dynamic>{
                'action': selectedAction,
                'stepId': step.id,
                if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
              };
              if (!context.mounted) return;
              context.read<StockDocumentBloc>().add(
                StockDocumentActionRequested(body),
              );
            },
      );
      return;
    }

    final needsNote =
        action == StockDocAction.reject ||
        action == StockDocAction.skip ||
        action == StockDocAction.cancel ||
        action == StockDocAction.complete;
    final needsProxy = action == StockDocAction.proxySign;

    final request = await WorkflowActionDialog.show(
      context,
      title: '${workflowActionLabel(action)} — ${step.stepName}',
      stepId: step.id,
      action: workflowActionCode(action),
      fileRepository: context.read<FileRepository>(),
      needsProxy: needsProxy,
      needsAuthorization: needsProxy,
      needsNote: needsNote,
      needsSkip: action == StockDocAction.skip,
    );
    if (request == null || !context.mounted) return;
    context.read<StockDocumentBloc>().add(
      StockDocumentActionRequested(request.toBody()),
    );
  }

  Future<void> _confirmDocumentAction({
    required BuildContext context,
    required StockDocAction action,
  }) async {
    final needsNote =
        action == StockDocAction.cancel || action == StockDocAction.complete;
    final request = await WorkflowActionDialog.show(
      context,
      title: workflowActionLabel(action),
      stepId: '',
      action: workflowActionCode(action),
      fileRepository: context.read<FileRepository>(),
      needsProxy: false,
      needsAuthorization: false,
      needsNote: needsNote,
    );
    if (request == null || !context.mounted) return;
    context.read<StockDocumentBloc>().add(
      StockDocumentActionRequested(request.toBody()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId(context);
    final userRole = currentTenantRoleFromAuthState(
      context.read<AuthBloc>().state,
    );
    final canEdit = detail.status == 'draft';

    final isAssignedApprover =
        available?.currentStepAssignedApproverId == null ||
        available?.currentStepAssignedApproverId == userId;
    final WorkflowStep? approvableStep;
    if (userId == null || available == null || !isAssignedApprover) {
      approvableStep = null;
    } else {
      approvableStep = detail.steps.cast<WorkflowStep?>().firstWhere(
        (s) => s?.id == available!.currentStepId,
        orElse: () => null,
      );
    }

    WorkflowStep? fallbackStep;
    if (approvableStep == null && userId != null) {
      fallbackStep = findApprovableStepForUser(
        steps: detail.steps,
        userId: userId,
        userRole: userRole,
        documentStatus: detail.status,
        assignedApproverIds: assignedApproverIdsFromWorkflowSteps(detail.steps),
      );
    }
    final currentStep = approvableStep ?? fallbackStep;

    final primaryActions = available?.actions ?? <String>[];
    final roleBasedActions = detail.documentType == 'stock_receipt'
        ? visibleReceiptActions(status: detail.status, role: userRole ?? '')
        : visibleIssueActions(status: detail.status, role: userRole ?? '');

    bool hasAction(String code) {
      if (primaryActions.contains(code)) return true;
      return roleBasedActions.any((a) => workflowActionCode(a) == code);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(detail: detail),
        const SizedBox(height: 16),
        const Text(
          'Thông tin duyệt',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (detail.steps.isEmpty)
          const Text(
            'Chưa có bước duyệt',
            style: TextStyle(color: ColorSkin.subtitle),
          )
        else
          ...detail.steps.map((step) => _WorkflowStepTile(step: step)),
        const SizedBox(height: 16),
        const Text(
          'Lịch sử / Ghi chú',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (timeline.isEmpty)
          const Text(
            'Chưa có ghi chú hoặc lịch sử',
            style: TextStyle(color: ColorSkin.subtitle),
          )
        else
          ...timeline.map((event) => _TimelineTile(event: event)),
        if (currentStep != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Hành động',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasAction('approve'))
                FilledButton.tonal(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmAction(
                          context: context,
                          step: currentStep,
                          action: StockDocAction.approve,
                        ),
                  child: const Text('Phê duyệt'),
                ),
              if (hasAction('reject'))
                FilledButton.tonal(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmAction(
                          context: context,
                          step: currentStep,
                          action: StockDocAction.reject,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.reject)),
                ),
              if (hasAction('skip'))
                FilledButton.tonal(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmAction(
                          context: context,
                          step: currentStep,
                          action: StockDocAction.skip,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.skip)),
                ),
              if (hasAction('proxy_sign'))
                FilledButton.tonal(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmAction(
                          context: context,
                          step: currentStep,
                          action: StockDocAction.proxySign,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.proxySign)),
                ),
            ],
          ),
        ],
        if (hasAction('submit') ||
            hasAction('complete') ||
            hasAction('cancel')) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasAction('submit'))
                FilledButton(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmDocumentAction(
                          context: context,
                          action: StockDocAction.submit,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.submit)),
                ),
              if (hasAction('complete'))
                FilledButton(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmDocumentAction(
                          context: context,
                          action: StockDocAction.complete,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.complete)),
                ),
              if (hasAction('cancel'))
                FilledButton.tonal(
                  onPressed: isActionSubmitting
                      ? null
                      : () => _confirmDocumentAction(
                          context: context,
                          action: StockDocAction.cancel,
                        ),
                  child: Text(workflowActionLabel(StockDocAction.cancel)),
                ),
            ],
          ),
        ],
        if (canEdit) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isActionSubmitting ? null : () => _openEdit(context),
            child: const Text('Sửa phiếu'),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.detail});

  final StockDocument detail;

  @override
  Widget build(BuildContext context) {
    final isReceipt = detail.documentType == 'stock_receipt';
    final accent = isReceipt ? ColorSkin.primary : ColorSkin.secondary1;
    final accentBg = isReceipt ? ColorSkin.tealLight : ColorSkin.orangeLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isReceipt ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
            color: accent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stockDocumentTypeLabel(detail.documentType),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorSkin.subtitle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bước: ${stockDocumentCurrentStepLabel(detail)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorSkin.title,
                ),
              ),
              if (detail.lastActionAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(detail.lastActionAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorSkin.subtitle,
                  ),
                ),
              ],
            ],
          ),
        ),
        _StatusChip(status: detail.status),
      ],
    );
  }
}

class _WorkflowStepTile extends StatelessWidget {
  const _WorkflowStepTile({required this.step});

  final WorkflowStep step;

  Color _color() {
    return switch (step.status) {
      'approved' => Colors.green,
      'signed_by_proxy' => Colors.blue,
      'rejected' => Colors.red,
      'skipped' => Colors.orange,
      'cancelled' => Colors.grey,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final note = step.note?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorSkin.grey3.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _color().withValues(alpha: 0.12),
            child: Icon(Icons.check, size: 16, color: _color()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.stepName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trạng thái: ${stockDocStatusLabel(step.status)}',
                  style: const TextStyle(fontSize: 13, color: ColorSkin.subtitle),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ghi chú: $note',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorSkin.title,
                    ),
                  ),
                ],
                if (step.actionAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(step.actionAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final note = event.note?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.history, size: 18, color: ColorSkin.subtitle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.fromStatus ?? '—'} → ${event.toStatus}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(event.changedAt),
                  style: const TextStyle(fontSize: 12, color: ColorSkin.subtitle),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColorSkin.title,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  ({Color bg, Color fg}) _colors() {
    return switch (status) {
      'draft' => (bg: const Color(0xFFF2F4F7), fg: const Color(0xFF667085)),
      'in_review' ||
      'pending_approval' ||
      'pending' ||
      'waiting' => (bg: ColorSkin.orangeLight, fg: const Color(0xFFB8860B)),
      'approved' ||
      'delegated' => (bg: ColorSkin.tealLight, fg: ColorSkin.primarySub),
      'completed' => (bg: const Color(0xFFE8F5E9), fg: const Color(0xFF2E7D32)),
      'rejected' => (bg: const Color(0xFFFFEBEE), fg: ColorSkin.error),
      'cancelled' => (bg: const Color(0xFFF2F4F7), fg: const Color(0xFF98A2B3)),
      _ => (bg: ColorSkin.tealLight, fg: ColorSkin.primarySub),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stockDocStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.fg,
        ),
      ),
    );
  }
}
