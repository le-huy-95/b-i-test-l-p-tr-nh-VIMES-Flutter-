import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';
import 'package:test_y_app/features/document/widgets/workflow_action_dialog.dart';
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
    if (_tabController.indexIsChanging) return;
    if (_showDetailOnMobile) setState(() => _showDetailOnMobile = false);
    final type = _documentTypes[_tabController.index].$1;
    context.read<StockDocumentBloc>().add(StockDocumentTypeChanged(type));
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
  }) async {
    final request = await WorkflowActionDialog.show(
      context,
      title: '${workflowActionLabel(action)} - ${step.stepName}',
      stepId: step.id,
      action: workflowActionCode(action),
      fileRepository: context.read<FileRepository>(),
      needsProxy: action == StockDocAction.delegate,
      needsAuthorization: action == StockDocAction.delegate,
      needsNote:
          action == StockDocAction.reject || action == StockDocAction.delegate,
    );
    if (request == null || !mounted) return;
    final body = request.toBody();
    body['documentId'] = detail.documentId;
    context.read<StockDocumentBloc>().add(StockDocumentActionRequested(body));
  }

  String _typeLabel(String type) {
    return switch (type) {
      'stock_issue' => 'Lệnh xuất hàng',
      'stock_receipt' => 'Lệnh nhập hàng',
      _ => type,
    };
  }

  Widget _buildList(StockDocumentLoaded state) {
    if (state.items.isEmpty) {
      return const Center(child: Text('Chưa có phiếu nào'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = state.items[index];
        final selected = item.documentId == state.selectedId;
        return InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? ColorSkin.tealLight : ColorSkin.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? ColorSkin.primary : ColorSkin.border1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.code ?? item.documentId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusChip(status: item.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _typeLabel(item.documentType),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Bước hiện tại: ${item.currentStepCode ?? '—'}'),
                if (item.lastActionAt != null)
                  Text(
                    'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(item.lastActionAt!)}',
                  ),
              ],
            ),
          ),
        );
      },
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
    final activeSteps = detail.steps
        .where((step) => isWorkflowStepActive(step.status))
        .toList();
    final currentStep = activeSteps.isNotEmpty
        ? activeSteps.first
        : (detail.steps.isNotEmpty ? detail.steps.first : null);
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
                for (final action in [
                  StockDocAction.approve,
                  StockDocAction.delegate,
                  StockDocAction.reject,
                ])
                  FilledButton.tonal(
                    onPressed: state.isActionSubmitting
                        ? null
                        : () => _confirmAction(
                            detail: detail,
                            step: currentStep,
                            action: action,
                          ),
                    child: Text(workflowActionLabel(action)),
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
        if (currentIndex >= 0 && _tabController.index != currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tabController.animateTo(currentIndex);
          });
        }
        final showingMobileDetail =
            _showDetailOnMobile &&
            state is StockDocumentLoaded &&
            state.selectedId != null;
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
                                onPressed: () => _openCreate(
                                  _documentTypes[_tabController.index].$1,
                                ),
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
                          onPressed: () => _openCreate(
                            _documentTypes[_tabController.index].$1,
                          ),
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
    final loading = state is StockDocumentLoading && state.documentType == type;
    return loading
        ? const Center(child: CircularProgressIndicator())
        : const SizedBox.shrink();
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final StockDocument detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorSkin.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.code ?? detail.documentId,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('Loại phiếu: ${detail.documentType}'),
          Text('Bước hiện tại: ${detail.currentStepCode ?? '—'}'),
          if (detail.lastActionAt != null)
            Text(
              'Lần cập nhật cuối: ${DateFormat('dd/MM/yyyy HH:mm').format(detail.lastActionAt!)}',
            ),
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

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(stockDocStatusLabel(status)));
  }
}
