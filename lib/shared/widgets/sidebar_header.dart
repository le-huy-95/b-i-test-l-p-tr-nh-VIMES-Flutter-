import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/assets/default_tenant_logo.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/notification/bloc/notification_bloc.dart';
import 'package:test_y_app/features/notification/bloc/notification_state.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';

/// Header chung dùng cho các trang trong sidebar (các tab chính của ứng dụng).
/// Hiển thị avatar + tên tổ chức (bấm để đổi tổ chức), thông báo và đăng xuất.
class SidebarHeader extends StatelessWidget implements PreferredSizeWidget {
  const SidebarHeader({super.key});

  @override
  Size get preferredSize =>
      AppHeader(variant: AppHeaderVariant.sidebar).preferredSize;

  static String roleLabel(String role) {
    return switch (role.trim().toLowerCase()) {
      'admin' => 'Admin',
      'warehouse_keeper' => 'Thủ kho',
      'accountant' => 'Kế toán',
      'approver' => 'Duyệt',
      'viewer' => 'Người xem',
      _ => role.trim().isEmpty ? '—' : role.trim(),
    };
  }

  static TenantMembership? selectedTenant(AuthAuthenticated state) {
    for (final t in state.tenants) {
      if (t.id == state.selectedTenantId) return t;
    }
    return state.tenants.isEmpty ? null : state.tenants.first;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return AppHeader(
            variant: AppHeaderVariant.sidebar,
            title: const Text('VIMES'),
            showNotificationAction: false,
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                icon: const Icon(Icons.logout),
                onPressed: () {},
              ),
            ],
          );
        }

        final tenant = selectedTenant(authState);

        return AppHeader(
          variant: AppHeaderVariant.sidebar,
          leadingWidth: 64,
          showNotificationAction: false,
          leading: tenant == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: InkWell(
                    onTap: () => _showTenantSwitcher(context, authState),
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _TenantAvatar(tenant: tenant, size: 36),
                          Positioned(
                            right: -6,
                            bottom: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: ColorSkin.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: ColorSkin.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          titleSpacing: 8,
          title: InkWell(
            onTap: tenant == null
                ? null
                : () => _showTenantSwitcher(context, authState),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant?.name ?? 'VIMES',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tenant != null)
                  Text(
                    '${tenant.code} · ${roleLabel(tenant.role)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            BlocBuilder<NotificationBloc, NotificationState>(
              buildWhen: (prev, curr) {
                final prevCount = prev is NotificationReady
                    ? prev.unreadCount
                    : 0;
                final currCount = curr is NotificationReady
                    ? curr.unreadCount
                    : 0;
                return prevCount != currCount;
              },
              builder: (context, notifState) {
                final unread = notifState is NotificationReady
                    ? notifState.unreadCount
                    : 0;
                return IconButton(
                  tooltip: 'Thông báo và lời mời',
                  onPressed: () =>
                      context.push(AppRoutes.notificationInbox.path),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: unread > 99 ? const Text('99+') : Text('$unread'),
                    child: const Icon(Icons.notifications_none_outlined),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout),
              onPressed: () => AppBottomSheetService.showLogoutConfirm(
                context: context,
                onConfirm: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTenantSwitcher(
    BuildContext context,
    AuthAuthenticated authState,
  ) async {
    BuildContext? sheetContext;
    final selectedId = await AppBottomSheetService.show<String>(
      context: context,
      title: 'Chọn tổ chức',
      content: Builder(
        builder: (sc) {
          sheetContext = sc;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tenant in authState.tenants) ...[
                _TenantSwitchTile(
                  tenant: tenant,
                  selected: tenant.id == authState.selectedTenantId,
                  roleLabel: roleLabel(tenant.role),
                  onTap: () => Navigator.of(sheetContext!).pop(tenant.id),
                ),
                if (tenant != authState.tenants.last)
                  const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      actions: const [AppBottomSheetAction(label: 'Đóng')],
    );

    if (!context.mounted ||
        selectedId == null ||
        selectedId == authState.selectedTenantId) {
      return;
    }

    context.read<AuthBloc>().add(AuthTenantSelected(selectedId));
  }
}

class _TenantAvatar extends StatelessWidget {
  const _TenantAvatar({required this.tenant, this.size = 36});

  final TenantMembership tenant;
  final double size;

  String? _resolveLogoUrl(String? rawUrl) {
    final raw = rawUrl?.trim();
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    final base = EnvConfig.mediaBaseUrl.trim();
    final baseUri = base.isEmpty ? null : Uri.tryParse(base);
    final isLoopbackHost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';

    if (uri.hasScheme && !isLoopbackHost) {
      return raw;
    }

    final path = uri.hasScheme
        ? uri.path
        : (raw.startsWith('/') ? raw : '/$raw');
    final relativePath = path.startsWith('/') ? path.substring(1) : path;

    if (baseUri == null) {
      return uri.hasScheme && isLoopbackHost
          ? null
          : (raw.startsWith('/') ? raw : '/$raw');
    }

    return baseUri.resolve(relativePath).toString();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.3);
    final logoUrl = _resolveLogoUrl(tenant.logoUrl);
    return ClipRRect(
      borderRadius: borderRadius,
      child: logoUrl != null
          ? Image.network(
              logoUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Image.asset(
      defaultTenantLogoAssetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

class _TenantSwitchTile extends StatelessWidget {
  const _TenantSwitchTile({
    required this.tenant,
    required this.selected,
    required this.roleLabel,
    required this.onTap,
  });

  final TenantMembership tenant;
  final bool selected;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ColorSkin.tealLight : ColorSkin.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? ColorSkin.primary : ColorSkin.border1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _TenantAvatar(tenant: tenant, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ColorSkin.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tenant.code} · $roleLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? ColorSkin.primary : ColorSkin.subtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
