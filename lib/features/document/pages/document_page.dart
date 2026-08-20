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
import 'package:test_y_app/shared/widgets/app_header.dart';

class DocumentPage extends StatefulWidget {
  const DocumentPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showDetailOnMobile = false;

  static const _documentTypes = [
    ('stock_issue', 'Lệnh xuất hàng'),
    ('stock_receipt', 'Lệnh nhập hàng'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _documentTypes.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final type = _documentTypes[_tabController.index].$1;
    context.read<StockDocumentBloc>().add(StockDocumentTypeChanged(type));

    if (_tabController.indexIsChanging) {
      setState(() {});
      return;
    }

    if (_showDetailOnMobile) {
      setState(() => _showDetailOnMobile = false);
    }
  }

  void _openDetail(StockDocument item) {
    setState(() => _showDetailOnMobile = true);
    context.read<StockDocumentBloc>().add(
      StockDocumentSelected(item.documentId),
    );
  }

  Future<void> _confirmAction({
    required StockDocument detail,
    required WorkflowStep step,
    required StockDocAction action,
    required AvailableActions? available,
  }) async {
    if (action == StockDocAction.approve) {
      await WorkflowApprovalBottomSheet.show(
        context,
        stepName: step.stepName,
        stepId: step.id,
        actions: const ['approve'],
        onSubmit: (selectedAction, note, proxySignerId, authorizationIds) async {
          final body = <String, dynamic>{
            'action': selectedAction,
            'stepId': step.id,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          };
          if (!mounted) return;
          context.read<StockDocumentBloc>().add(StockDocumentActionRequested(body));
        },
      );
      return;
    }

    final needsNote = action == StockDocAction.reject ||
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
    if (request == null || !mounted) return;
    final body = request.toBody();
    context.read<StockDocumentBloc>().add(StockDocumentActionRequested(body));
  }

  String? _currentUserId(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated && auth.user.id.isNotEmpty) {
      return auth.user.id;
    }
    return null;
  }

  String _typeLabel(String type) => stockDocumentTypeLabel(type);

  Widget _buildList(StockDocumentLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<StockDocumentBloc>().add(
          StockDocumentRefreshRequested(state.documentType),
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          _DocumentSummaryBar(count: state.items.length),
          const SizedBox(height: 12),
          if (state.items.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: _DocumentEmptyState(documentType: state.documentType),
            )
          else
            ...state.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DocumentListCard(
                  item: item,
                  selected: item.documentId == state.selectedId,
                  onTap: () => _openDetail(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCreate(String type) async {
    final path = switch (type) {
      'stock_issue' => AppRoutes.stockIssueNew.path,
      'stock_receipt' => AppRoutes.stockReceiptNew.path,
      _ => AppRoutes.documents.path,
    };
    final result = await context.push<bool>(path);
    if (result == true && mounted) {
      context.read<StockDocumentBloc>().add(
        StockDocumentRefreshRequested(type),
      );
    }
  }

  Future<void> _openEdit(StockDocument detail) async {
    final path = detail.documentType == 'stock_issue'
        ? AppRoutes.stockIssueEdit.path.replaceFirst(':id', detail.documentId)
        : AppRoutes.stockReceiptEdit.path.replaceFirst(
            ':id',
            detail.documentId,
          );
    final result = await context.push<bool>(path);
    if (result == true && mounted) {
      context.read<StockDocumentBloc>().add(
        StockDocumentRefreshRequested(detail.documentType),
      );
    }
  }

  Widget _buildTabContent(StockDocumentLoaded state, bool isWide) {
    if (isWide) {
      return Row(
        children: [
          SizedBox(width: 360, child: _buildList(state)),
          const VerticalDivider(width: 1),
          Expanded(child: _buildDetail(state)),
        ],
      );
    }
    if (_showDetailOnMobile && state.selectedId != null) {
      return _buildDetail(state);
    }
    return _buildList(state);
  }

  Widget _buildDetail(StockDocumentLoaded state) {
    final detail = state.detail;
    final available = state.availableActions;
    if (state.isDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chọn một phiếu để xem chi tiết'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openCreate(state.documentType),
              child: Text('Tạo ${_typeLabel(state.documentType)}'),
            ),
          ],
        ),
      );
    }
    final canEdit = detail.status == 'draft';
    // Use available-actions from API as primary source; fall back to role-based check.
    final userId = _currentUserId(context);
    final userRole = currentTenantRoleFromAuthState(context.read<AuthBloc>().state);
    final isAssignedApprover = available?.currentStepAssignedApproverId == null ||
        available?.currentStepAssignedApproverId == userId;
    final approvableStep = userId == null || available == null
        ? null
        : (isAssignedApprover
            ? detail.steps.cast<WorkflowStep?>().firstWhere(
                  (s) => s?.id == available.currentStepId,
                  orElse: () => null,
                )
            : null);

    // If no available-actions (API unavailable), fall back to role-based step finder.
    final WorkflowStep? fallbackStep;
    if (approvableStep == null && userId != null) {
      fallbackStep = findApprovableStepForUser(
        steps: detail.steps,
        userId: userId,
        userRole: userRole,
        documentStatus: detail.status,
        assignedApproverIds: assignedApproverIdsFromWorkflowSteps(detail.steps),
      );
    } else {
      fallbackStep = null;
    }
    final currentStep = approvableStep ?? fallbackStep;

    // Primary action sources from API; fall back to role-based actions.
    final primaryActions = available?.actions ?? <String>[];
    final List<StockDocAction> roleBasedActions;
    if (detail.documentType == 'stock_receipt') {
      roleBasedActions = visibleReceiptActions(
        status: detail.status,
        role: userRole ?? '',
      );
    } else {
      roleBasedActions = visibleIssueActions(
        status: detail.status,
        role: userRole ?? '',
      );
    }

    bool hasAction(String code) {
      if (primaryActions.contains(code)) return true;
      return roleBasedActions.any((a) => workflowActionCode(a) == code);
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StockDocumentBloc>().add(
          StockDocumentRefreshRequested(state.documentType),
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HeaderCard(detail: detail),
          const SizedBox(height: 16),
          const Text(
            'Workflow 4 bước',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...detail.steps.map((step) => _WorkflowStepCard(step: step)),
          const SizedBox(height: 16),
          const Text(
            'Lịch sử',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (state.timeline.isEmpty)
            const Text('Chưa có timeline')
          else
            ...state.timeline.map(
              (event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text('${event.fromStatus ?? '—'} → ${event.toStatus}'),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy HH:mm').format(event.changedAt)}${event.note != null ? '\n${event.note}' : ''}',
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (currentStep != null) ...[
            const Text(
              'Hành động bước hiện tại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (hasAction('approve'))
                  FilledButton.tonal(
                    onPressed: state.isActionSubmitting
                        ? null
                        : () => _confirmAction(
                              detail: detail,
                              step: currentStep,
                              action: StockDocAction.approve,
                              available: available,
                            ),
                    child: const Text('Phê duyệt'),
                  ),
                if (hasAction('reject'))
                  FilledButton.tonal(
                    onPressed: state.isActionSubmitting
                        ? null
                        : () => _confirmAction(
                              detail: detail,
                              step: currentStep,
                              action: StockDocAction.reject,
                              available: available,
                            ),
                    child: Text(workflowActionLabel(StockDocAction.reject)),
                  ),
                if (hasAction('skip'))
                  FilledButton.tonal(
                    onPressed: state.isActionSubmitting
                        ? null
                        : () => _confirmAction(
                              detail: detail,
                              step: currentStep,
                              action: StockDocAction.skip,
                              available: available,
                            ),
                    child: Text(workflowActionLabel(StockDocAction.skip)),
                  ),
                if (hasAction('proxy_sign'))
                  FilledButton.tonal(
                    onPressed: state.isActionSubmitting
                        ? null
                        : () => _confirmAction(
                              detail: detail,
                              step: currentStep,
                              action: StockDocAction.proxySign,
                              available: available,
                            ),
                    child: Text(workflowActionLabel(StockDocAction.proxySign)),
                  ),
              ],
            ),
          ],
          // Document-level actions (submit / complete / cancel) — no stepId needed.
          if (hasAction('submit') || hasAction('complete') || hasAction('cancel')) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
          if (hasAction('submit'))
            FilledButton(
              onPressed: state.isActionSubmitting
                  ? null
                  : () => _confirmDocumentAction(
                        action: StockDocAction.submit,
                      ),
              child: Text(workflowActionLabel(StockDocAction.submit)),
            ),
          if (hasAction('complete'))
            FilledButton(
              onPressed: state.isActionSubmitting
                  ? null
                  : () => _confirmDocumentAction(
                        action: StockDocAction.complete,
                      ),
              child: Text(workflowActionLabel(StockDocAction.complete)),
            ),
          if (hasAction('cancel'))
            FilledButton.tonal(
              onPressed: state.isActionSubmitting
                  ? null
                  : () => _confirmDocumentAction(
                        action: StockDocAction.cancel,
                      ),
              child: Text(workflowActionLabel(StockDocAction.cancel)),
            ),
              ],
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.isActionSubmitting
                  ? null
                  : () => _openEdit(detail),
              child: const Text('Sửa phiếu'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDocumentAction({
    required StockDocAction action,
  }) async {
    final needsNote = action == StockDocAction.cancel ||
        action == StockDocAction.complete;
    final request = await WorkflowActionDialog.show(
      context,
      title: workflowActionLabel(action),
      stepId: '', // Document-level actions don't need stepId.
      action: workflowActionCode(action),
      fileRepository: context.read<FileRepository>(),
      needsProxy: false,
      needsAuthorization: false,
      needsNote: needsNote,
    );
    if (request == null || !mounted) return;
    context.read<StockDocumentBloc>().add(StockDocumentActionRequested(request.toBody()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockDocumentBloc, StockDocumentState>(
      builder: (context, state) {
        final currentType = state is StockDocumentLoaded
            ? state.documentType
            : _documentTypes[_tabController.index].$1;
        final currentIndex = _documentTypes.indexWhere(
          (e) => e.$1 == currentType,
        );
        if (currentIndex >= 0 &&
            _tabController.index != currentIndex &&
            !_tabController.indexIsChanging) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tabController.animateTo(currentIndex);
          });
        }
        final showingMobileDetail =
            _showDetailOnMobile &&
            state is StockDocumentLoaded &&
            state.selectedId != null;
        final currentTabType = _documentTypes[_tabController.index].$1;
        final isActionSubmitting =
            state is StockDocumentLoaded && state.isActionSubmitting;

        final page = PopScope(
          canPop: !showingMobileDetail,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && showingMobileDetail) {
              setState(() => _showDetailOnMobile = false);
            }
          },
          child: widget.embedded
              ? Column(
                  children: [
                    _buildHeaderBar(context, showingMobileDetail),
                    Expanded(
                      child: Stack(
                        children: [
                          _buildBody(context, state, showingMobileDetail),
                          if (!showingMobileDetail)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton(
                                tooltip: 'Tạo phiếu mới',
                                backgroundColor: ColorSkin.primary,
                                onPressed: () => _openCreate(currentTabType),
                                child: const Icon(
                                  Icons.add,
                                  color: ColorSkin.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : Scaffold(
                  appBar: AppHeader(
                    leading: showingMobileDetail
                        ? BackButton(
                            onPressed: () =>
                                setState(() => _showDetailOnMobile = false),
                          )
                        : null,
                    onTitleTap: () =>
                        setState(() => _showDetailOnMobile = false),
                    title: Text(showingMobileDetail ? 'Chi tiết phiếu' : ''),
                    bottom: TabBar(
                      controller: _tabController,
                      tabs: [
                        for (final tab in _documentTypes) Tab(text: tab.$2),
                      ],
                    ),
                  ),
                  floatingActionButton: showingMobileDetail
                      ? null
                      : FloatingActionButton(
                          tooltip: 'Tạo phiếu mới',
                          backgroundColor: ColorSkin.white,
                          onPressed: () => _openCreate(currentTabType),
                          child: const Icon(
                            Icons.add,
                            color: ColorSkin.primary,
                          ),
                        ),
                  body: _buildBody(context, state, showingMobileDetail),
                ),
        );

        if (!isActionSubmitting) return page;

        return Stack(
          children: [
            page,
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  Widget _buildHeaderBar(BuildContext context, bool showingMobileDetail) {
    return Material(
      color: ColorSkin.white,
      child: TabBar(
        controller: _tabController,
        tabs: [for (final tab in _documentTypes) Tab(text: tab.$2)],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    StockDocumentState state,
    bool showingMobileDetail,
  ) {
    if (state is StockDocumentFailure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.message, textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: () => context.read<StockDocumentBloc>().add(
                StockDocumentRefreshRequested(state.documentType),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return Column(
          children: [
            if (state is StockDocumentLoaded && state.message != null)
              MaterialBanner(
                content: Text(state.message!),
                actions: [
                  TextButton(
                    onPressed: () => context.read<StockDocumentBloc>().add(
                      StockDocumentRefreshRequested(state.documentType),
                    ),
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabBody(context, state, isWide, _documentTypes[0].$1),
                  _buildTabBody(context, state, isWide, _documentTypes[1].$1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    StockDocumentState state,
    bool isWide,
    String type,
  ) {
    if (state is StockDocumentLoaded && state.documentType == type) {
      return _buildTabContent(state, isWide);
    }
    if (state is StockDocumentFailure && state.documentType == type) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.message, textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: () => context.read<StockDocumentBloc>().add(
                StockDocumentRefreshRequested(type),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (state is StockDocumentLoading && state.documentType == type) {
      return const Center(child: CircularProgressIndicator());
    }
    // Tab is selected but bloc still holds another type — keep UI alive while syncing.
    if (_documentTypes[_tabController.index].$1 == type) {
      return const Center(child: CircularProgressIndicator());
    }
    return const SizedBox.shrink();
  }
}

class _DocumentSummaryBar extends StatelessWidget {
  const _DocumentSummaryBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ColorSkin.tealLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count phiếu',
            style: const TextStyle(
              color: ColorSkin.primarySub,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentEmptyState extends StatelessWidget {
  const _DocumentEmptyState({required this.documentType});

  final String documentType;

  @override
  Widget build(BuildContext context) {
    final isReceipt = documentType == 'stock_receipt';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorSkin.tealLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isReceipt
                    ? Icons.move_to_inbox_outlined
                    : Icons.outbox_outlined,
                size: 34,
                color: ColorSkin.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có phiếu nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ColorSkin.title,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo ${stockDocumentTypeLabel(documentType).toLowerCase()} đầu tiên để bắt đầu quy trình duyệt.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: ColorSkin.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentListCard extends StatelessWidget {
  const _DocumentListCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final StockDocument item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReceipt = item.documentType == 'stock_receipt';
    final accent = isReceipt ? ColorSkin.primary : ColorSkin.secondary1;
    final accentBg = isReceipt ? ColorSkin.tealLight : ColorSkin.orangeLight;

    return Material(
      color: selected
          ? ColorSkin.tealLight.withValues(alpha: 0.55)
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? ColorSkin.primary
                  : ColorSkin.border1.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isReceipt
                          ? Icons.move_to_inbox_outlined
                          : Icons.outbox_outlined,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stockDocumentDisplayCode(item),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ColorSkin.title,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stockDocumentTypeLabel(item.documentType),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorSkin.subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: ColorSkin.grey3),
              const SizedBox(height: 12),
              _DocumentMetaRow(
                icon: Icons.route_outlined,
                label: 'Bước hiện tại',
                value: stockDocumentCurrentStepLabel(item),
              ),
              if (item.lastActionAt != null) ...[
                const SizedBox(height: 8),
                _DocumentMetaRow(
                  icon: Icons.schedule_outlined,
                  label: 'Cập nhật',
                  value: DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(item.lastActionAt!),
                  trailing: stockDocumentRelativeUpdateLabel(item.lastActionAt),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentMetaRow extends StatelessWidget {
  const _DocumentMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ColorSkin.subtitle),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: ColorSkin.subtitle,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorSkin.title,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorSkin.subtitle,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final StockDocument detail;

  @override
  Widget build(BuildContext context) {
    final isReceipt = detail.documentType == 'stock_receipt';
    final accent = isReceipt ? ColorSkin.primary : ColorSkin.secondary1;
    final accentBg = isReceipt ? ColorSkin.tealLight : ColorSkin.orangeLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isReceipt
                      ? Icons.move_to_inbox_outlined
                      : Icons.outbox_outlined,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stockDocumentDisplayCode(detail),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ColorSkin.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stockDocumentTypeLabel(detail.documentType),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: ColorSkin.grey3),
          const SizedBox(height: 12),
          _DocumentMetaRow(
            icon: Icons.route_outlined,
            label: 'Bước hiện tại',
            value: stockDocumentCurrentStepLabel(detail),
          ),
          if (detail.lastActionAt != null) ...[
            const SizedBox(height: 8),
            _DocumentMetaRow(
              icon: Icons.schedule_outlined,
              label: 'Lần cập nhật cuối',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(detail.lastActionAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowStepCard extends StatelessWidget {
  const _WorkflowStepCard({required this.step});

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorSkin.border1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: _color().withValues(alpha: 0.12),
            child: Icon(Icons.check, color: _color()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.stepName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Trạng thái: ${stockDocStatusLabel(step.status)}'),
                if (step.note != null && step.note!.isNotEmpty)
                  Text('Ghi chú: ${step.note}'),
                if (step.actionAt != null)
                  Text(
                    'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(step.actionAt!)}',
                  ),
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
