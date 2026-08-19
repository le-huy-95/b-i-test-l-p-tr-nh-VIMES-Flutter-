import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';
import 'package:test_y_app/features/notification/bloc/notification_bloc.dart';
import 'package:test_y_app/features/notification/bloc/notification_event.dart';
import 'package:test_y_app/features/notification/bloc/notification_state.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      context.read<NotificationBloc>().add(const NotificationLoadMore());
    }
  }

  String _typeLabel(String type) {
    return switch (type) {
      'receipt_submitted' => 'Phiếu nhập chờ duyệt',
      'receipt_approved' => 'Phiếu nhập đã duyệt',
      'receipt_rejected' => 'Phiếu nhập bị từ chối',
      'receipt_completed' => 'Phiếu nhập hoàn tất',
      'receipt_cancelled' => 'Phiếu nhập bị hủy',
      'issue_submitted' => 'Phiếu xuất chờ duyệt',
      'issue_approved' => 'Phiếu xuất đã duyệt',
      'issue_rejected' => 'Phiếu xuất bị từ chối',
      'issue_completed' => 'Phiếu xuất hoàn tất',
      'issue_cancelled' => 'Phiếu xuất bị hủy',
      'invitation_created' => 'Lời mời tham gia',
      'invitation_accepted' => 'Lời mời được chấp nhận',
      'membership_removed' => 'Thành viên bị xóa',
      _ => 'Thông báo',
    };
  }

  IconData _typeIcon(String type) {
    if (type.startsWith('receipt_')) return Icons.inventory_2_outlined;
    if (type.startsWith('issue_')) return Icons.outbox_outlined;
    if (type.startsWith('invitation_')) return Icons.person_add_outlined;
    return Icons.notifications_outlined;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa nay';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleTap(NotificationItem item) {
    if (!item.isRead) {
      context.read<NotificationBloc>().add(NotificationMarkRead(item.id));
    }
    _navigate(item);
  }

  void _navigate(NotificationItem item) {
    if (item.deeplink != null && item.deeplink!.isNotEmpty) {
      final uri = Uri.tryParse(item.deeplink!);
      if (uri != null) {
        switch (uri.host) {
          case 'stock-receipts':
            if (uri.pathSegments.isNotEmpty) {
              SimpleSnackbarService.showInfo(
                'Phiếu nhập ${uri.pathSegments.first} — chi tiết sẽ có khi module Phiếu ra mắt',
              );
              return;
            }
          case 'stock-issues':
            if (uri.pathSegments.isNotEmpty) {
              SimpleSnackbarService.showInfo(
                'Phiếu xuất ${uri.pathSegments.first} — chi tiết sẽ có khi module Phiếu ra mắt',
              );
              return;
            }
        }
      }
    }
    if (item.routeName != null) {
      switch (item.routeName) {
        case 'stock_receipt_detail':
          final receiptId = item.routeParams?['receiptId'];
          if (receiptId != null) {
            SimpleSnackbarService.showInfo(
              'Phiếu nhập $receiptId — chi tiết sẽ có khi module Phiếu ra mắt',
            );
            return;
          }
        case 'stock_issue_detail':
          final issueId = item.routeParams?['issueId'];
          if (issueId != null) {
            SimpleSnackbarService.showInfo(
              'Phiếu xuất $issueId — chi tiết sẽ có khi module Phiếu ra mắt',
            );
            return;
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: const Text('Thông báo'),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            buildWhen: (prev, curr) =>
                curr is NotificationReady &&
                (prev is! NotificationReady ||
                    prev.items.any((i) => !i.isRead) !=
                        curr.items.any((i) => !i.isRead)),
            builder: (context, state) {
              final hasUnread = state is NotificationReady &&
                  state.items.any((i) => !i.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => context
                    .read<NotificationBloc>()
                    .add(const NotificationMarkAllRead()),
                child: const Text(
                  'Đọc tất cả',
                  style: TextStyle(color: ColorSkin.primary),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationInitial || state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationFailure) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<NotificationBloc>()
                  .add(const NotificationRefreshed()),
            );
          }
          if (state is NotificationReady) {
            if (state.items.isEmpty) {
              return _EmptyState(
                isWsConnected: state.isWsConnected,
                onRefresh: () => context
                    .read<NotificationBloc>()
                    .add(const NotificationRefreshed()),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<NotificationBloc>()
                    .add(const NotificationRefreshed());
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = state.items[index];
                  return _NotificationTile(
                    item: item,
                    typeLabel: _typeLabel(item.type),
                    typeIcon: _typeIcon(item.type),
                    timeText: _formatTime(item.createdAt),
                    onTap: () => _handleTap(item),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.typeLabel,
    required this.typeIcon,
    required this.timeText,
    required this.onTap,
  });

  final NotificationItem item;
  final String typeLabel;
  final IconData typeIcon;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    return Material(
      color: isUnread ? ColorSkin.tealLight.withValues(alpha: 0.4) : ColorSkin.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnread
                      ? ColorSkin.primary.withValues(alpha: 0.12)
                      : ColorSkin.grey3,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeIcon,
                  size: 20,
                  color: isUnread ? ColorSkin.primary : ColorSkin.subtitle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColorSkin.subtitle,
                            ),
                          ),
                        ),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorSkin.subtitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                        color: ColorSkin.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ColorSkin.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isWsConnected, required this.onRefresh});

  final bool isWsConnected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: ColorSkin.subtitle.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông báo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorSkin.subtitle,
            ),
          ),
          const SizedBox(height: 8),
          if (!isWsConnected)
            Text(
              'Kết nối realtime đang tắt',
              style: TextStyle(fontSize: 13, color: ColorSkin.subtitle.withValues(alpha: 0.6)),
            ),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: onRefresh, child: const Text('Tải lại')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: ColorSkin.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColorSkin.subtitle),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
