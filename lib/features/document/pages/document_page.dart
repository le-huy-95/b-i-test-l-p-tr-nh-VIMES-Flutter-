import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/auth/stock_doc_actions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/stock_document/stock_document.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';
import 'package:test_y_app/features/document/document_formatters.dart';
import 'package:test_y_app/features/document/widgets/document_detail_bottom_sheet.dart';
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
  }

  Future<void> _openDetail(StockDocument item) async {
    await DocumentDetailBottomSheet.show(context, item: item);
  }

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
    await context.push<bool>(path);
    if (!mounted) return;
    context.read<StockDocumentBloc>().add(
      StockDocumentRefreshRequested(type),
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
        if (currentIndex >= 0 &&
            _tabController.index != currentIndex &&
            !_tabController.indexIsChanging) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tabController.animateTo(currentIndex);
          });
        }
        final currentTabType = _documentTypes[_tabController.index].$1;
        final isActionSubmitting =
            state is StockDocumentLoaded && state.isActionSubmitting;

        final page = widget.embedded
            ? Column(
                children: [
                  _buildHeaderBar(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildBody(context, state),
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
                  title: const Text(''),
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: [
                      for (final tab in _documentTypes) Tab(text: tab.$2),
                    ],
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  tooltip: 'Tạo phiếu mới',
                  backgroundColor: ColorSkin.white,
                  onPressed: () => _openCreate(currentTabType),
                  child: const Icon(
                    Icons.add,
                    color: ColorSkin.primary,
                  ),
                ),
                body: _buildBody(context, state),
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

  Widget _buildHeaderBar() {
    return Material(
      color: ColorSkin.white,
      child: TabBar(
        controller: _tabController,
        tabs: [for (final tab in _documentTypes) Tab(text: tab.$2)],
      ),
    );
  }

  Widget _buildBody(BuildContext context, StockDocumentState state) {
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
              _buildTabBody(context, state, _documentTypes[0].$1),
              _buildTabBody(context, state, _documentTypes[1].$1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    StockDocumentState state,
    String type,
  ) {
    if (state is StockDocumentLoaded && state.documentType == type) {
      return _buildList(state);
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
