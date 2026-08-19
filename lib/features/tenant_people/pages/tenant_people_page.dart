import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/tenant/tenant_invitation.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';
import 'package:test_y_app/data/repositories/tenant_people_repository_impl.dart';
import 'package:test_y_app/domain/repositories/tenant_people_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/tenant_people/bloc/tenant_people_bloc.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';
import 'package:test_y_app/shared/widgets/app_search_field.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';

class TenantPeoplePage extends StatelessWidget {
  const TenantPeoplePage({super.key});

  String _roleLabel(String role) {
    return switch (role) {
      'admin' => 'Admin',
      'warehouse_keeper' => 'Thủ kho',
      'accountant' => 'Kế toán',
      'approver' => 'Duyệt',
      'viewer' => 'Viewer',
      _ => role,
    };
  }

  IconData _roleIcon(String role) {
    return switch (role) {
      'admin' => Icons.verified_user_outlined,
      'warehouse_keeper' => Icons.warehouse_outlined,
      'accountant' => Icons.calculate_outlined,
      'approver' => Icons.fact_check_outlined,
      _ => Icons.person_outline,
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String? _currentRole(AuthState authState) {
    if (authState case AuthAuthenticated(
      :final tenants,
      :final selectedTenantId,
    )) {
      for (final tenant in tenants) {
        if (tenant.id == selectedTenantId) return tenant.role;
      }
      return tenants.isNotEmpty ? tenants.first.role : null;
    }
    if (authState case AuthNeedsTenant(:final tenants)) {
      return tenants.isNotEmpty ? tenants.first.role : null;
    }
    return null;
  }

  String? _currentTenantName(AuthState authState) {
    if (authState case AuthAuthenticated(
      :final tenants,
      :final selectedTenantId,
    )) {
      for (final tenant in tenants) {
        if (tenant.id == selectedTenantId) return tenant.name;
      }
      return tenants.isNotEmpty ? tenants.first.name : null;
    }
    if (authState case AuthNeedsTenant(:final tenants)) {
      return tenants.isNotEmpty ? tenants.first.name : null;
    }
    return null;
  }

  Future<void> _openCreateInvitationSheet(BuildContext context) async {
    final formKey = GlobalKey<_CreateInvitationFormState>();
    await AppBottomSheetService.show<void>(
      context: context,
      title: 'Mời thành viên',
      content: _CreateInvitationForm(
        key: formKey,
        onSubmitted: (email, role) {
          context.read<TenantPeopleBloc>().add(
            TenantPeopleCreateInvitationSubmitted(email: email, role: role),
          );
        },
      ),
      actions: [
        AppBottomSheetAction(label: 'Huỷ'),
        AppBottomSheetAction(
          label: 'Gửi lời mời',
          style: AppBottomSheetActionStyle.primary,
          dismissOnTap: false,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
  }

  Future<void> _openCreateUserSheet(BuildContext context) async {
    final formKey = GlobalKey<_CreateUserFormState>();
    await AppBottomSheetService.show<void>(
      context: context,
      title: 'Tạo user nội bộ',
      content: _CreateUserForm(
        key: formKey,
        onSubmitted: (data) {
          context.read<TenantPeopleBloc>().add(
            TenantPeopleCreateTenantUserSubmitted(
              email: data.email,
              phone: data.phone,
              name: data.name,
              password: data.password,
              role: data.role,
            ),
          );
        },
      ),
      actions: [
        AppBottomSheetAction(label: 'Huỷ'),
        AppBottomSheetAction(
          label: 'Tạo user',
          style: AppBottomSheetActionStyle.primary,
          dismissOnTap: false,
          onPressed: () => formKey.currentState?.submit(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TenantPeopleRepository>(
      create: (_) => TenantPeopleRepositoryImpl(),
      child: BlocProvider(
        create: (context) =>
            TenantPeopleBloc(repository: context.read<TenantPeopleRepository>())
              ..add(const TenantPeopleStarted()),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final role = _currentRole(authState);
            final canManagePeople = role != null && canManageTenantPeople(role);
            final canViewInvitationsInUi =
                role != null && canViewInvitations(role);
            final currentTenantName = _currentTenantName(authState);

            return Scaffold(
              appBar: AppHeader(
                title: const Text('Thành viên'),
                actions: [
                  if (canManagePeople)
                    IconButton(
                      tooltip: 'Mời thành viên',
                      onPressed: () => _openCreateInvitationSheet(context),
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: ColorSkin.primary,
                      ),
                    ),
                  if (canManagePeople)
                    IconButton(
                      tooltip: 'Tạo user nội bộ',
                      onPressed: () => _openCreateUserSheet(context),
                      icon: const Icon(Icons.badge_outlined),
                    ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: BlocBuilder<TenantPeopleBloc, TenantPeopleState>(
                      builder: (context, state) {
                        final currentTab = state is TenantPeopleLoaded
                            ? state.tab
                            : TenantPeopleTab.members;
                        return _SectionTabs(
                          showInvitations: canViewInvitationsInUi,
                          currentTab: currentTab,
                          onChanged: (tab) {
                            context.read<TenantPeopleBloc>().add(
                              TenantPeopleTabChanged(tab),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: AppSearchField<TenantMember>(
                      hintText: 'Tìm theo tên, email, số điện thoại',
                      fillColor: ColorSkin.grey3,
                      borderSide: BorderSide.none,
                      focusedBorderSide: const BorderSide(
                        color: ColorSkin.primary,
                        width: 1.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      searchApi: (query) async {
                        context.read<TenantPeopleBloc>().add(
                          TenantPeopleSearchChanged(query),
                        );
                        final current = context.read<TenantPeopleBloc>().state;
                        if (current is TenantPeopleLoaded) {
                          final isMembers =
                              !canViewInvitationsInUi ||
                              current.tab == TenantPeopleTab.members;
                          return isMembers
                              ? current.members
                              : current.invitations
                                    .map(
                                      (item) => TenantMember(
                                        id: item.id,
                                        userId: item.id,
                                        name: item.email,
                                        email: item.email,
                                        phone: null,
                                        role: item.role,
                                        isActive: !item.isExpired,
                                        joinedAt: item.invitedAt,
                                      ),
                                    )
                                    .toList();
                        }
                        return const [];
                      },
                      onResultsChanged: (_) {},
                      onChanged: (value) => context
                          .read<TenantPeopleBloc>()
                          .add(TenantPeopleSearchChanged(value)),
                    ),
                  ),
                  Expanded(
                    child: BlocConsumer<TenantPeopleBloc, TenantPeopleState>(
                      listener: (context, state) {
                        if (state is TenantPeopleLoaded) {
                          if (state.error != null) {
                            SimpleSnackbarService.showError(state.error!);
                          }
                          if (state.recentMessage != null) {
                            SimpleSnackbarService.showSuccess(
                              state.recentMessage!,
                            );
                          }
                          if (state.recentInviteLink != null) {
                            SimpleSnackbarService.showInfo(
                              'Link mời: ${state.recentInviteLink!}',
                            );
                          }
                        }
                      },
                      builder: (context, state) {
                        if (state is TenantPeopleInitial ||
                            state is TenantPeopleLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (state is TenantPeopleFailure) {
                          return _ErrorView(
                            message: state.message,
                            onRetry: () => context.read<TenantPeopleBloc>().add(
                              const TenantPeopleRefreshed(),
                            ),
                          );
                        }

                        if (state is TenantPeopleLoaded) {
                          final showInvitationTab = canViewInvitationsInUi;
                          final isMembers =
                              !showInvitationTab ||
                              state.tab == TenantPeopleTab.members;
                          final items = isMembers
                              ? state.members
                              : state.invitations;
                          if (items.isEmpty) {
                            return _EmptyState(
                              search: state.search,
                              title: isMembers
                                  ? 'Chưa có thành viên nào'
                                  : 'Chưa có lời mời nào',
                              subtitle: isMembers
                                  ? 'Dữ liệu được lấy từ API thành viên của tenant hiện tại.'
                                  : 'Lời mời nhận được từ tổ chức khác sẽ xuất hiện tại đây.',
                              onRefresh: () => context
                                  .read<TenantPeopleBloc>()
                                  .add(const TenantPeopleRefreshed()),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: () async {
                              context.read<TenantPeopleBloc>().add(
                                const TenantPeopleRefreshed(),
                              );
                            },
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.pixels >=
                                    notification.metrics.maxScrollExtent -
                                        200) {
                                  context.read<TenantPeopleBloc>().add(
                                    const TenantPeopleLoadMore(),
                                  );
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                itemCount:
                                    items.length + (state.hasMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  if (index == items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  if (isMembers) {
                                    final item = items[index] as TenantMember;
                                    return _MemberCard(
                                      item: item,
                                      roleLabel: _roleLabel(item.role),
                                      icon: _roleIcon(item.role),
                                      tenantName: currentTenantName,
                                      joinedText:
                                          'Tham gia ${_formatDate(item.joinedAt)}',
                                    );
                                  }

                                  final item = items[index] as TenantInvitation;
                                  return _InvitationCard(
                                    item: item,
                                    roleLabel: _roleLabel(item.role),
                                    statusLabel: item.statusLabel,
                                    directionLabel: item.isIncoming
                                        ? 'Lời mời đến từ ${item.tenantName.isNotEmpty ? item.tenantName : 'tổ chức khác'}'
                                        : 'Lời mời do ${item.tenantName.isNotEmpty ? item.tenantName : 'tổ chức hiện tại'} gửi đi',
                                    invitedBy:
                                        item.invitedBy.name
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? item.invitedBy.name!.trim()
                                        : (item.invitedBy.email ?? '—'),
                                    invitedAt: _formatDate(item.invitedAt),
                                    expiresAt: _formatDate(item.expiresAt),
                                    onAccept: item.canAccept
                                        ? () => context
                                              .read<TenantPeopleBloc>()
                                              .add(
                                                TenantPeopleAcceptInvitationSubmitted(
                                                  invitation: item,
                                                ),
                                              )
                                        : null,
                                    onDecline: item.canDecline
                                        ? () => context
                                              .read<TenantPeopleBloc>()
                                              .add(
                                                TenantPeopleDeclineInvitationSubmitted(
                                                  invitation: item,
                                                ),
                                              )
                                        : null,
                                  );
                                },
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.showInvitations,
    required this.currentTab,
    required this.onChanged,
  });

  final bool showInvitations;
  final TenantPeopleTab currentTab;
  final ValueChanged<TenantPeopleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorSkin.grey3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: 'Thành viên',
              icon: Icons.groups_outlined,
              selected: currentTab == TenantPeopleTab.members,
              onTap: () => onChanged(TenantPeopleTab.members),
            ),
          ),
          if (showInvitations) ...[
            const SizedBox(width: 4),
            Expanded(
              child: _TabItem(
                label: 'Lời mời',
                icon: Icons.mail_outline,
                selected: currentTab == TenantPeopleTab.invitations,
                onTap: () => onChanged(TenantPeopleTab.invitations),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ColorSkin.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : ColorSkin.subtitle,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : ColorSkin.subtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.item,
    required this.roleLabel,
    required this.icon,
    required this.tenantName,
    required this.joinedText,
  });

  final TenantMember item;
  final String roleLabel;
  final IconData icon;
  final String? tenantName;
  final String joinedText;

  @override
  Widget build(BuildContext context) {
    final displayName = item.name?.trim().isNotEmpty == true
        ? item.name!.trim()
        : (item.email?.trim().isNotEmpty == true
              ? item.email!.trim()
              : item.phone ?? '—');

    return Material(
      color: ColorSkin.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorSkin.border1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ColorSkin.tealLight,
                child: Icon(icon, color: ColorSkin.primary),
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
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ColorSkin.title,
                            ),
                          ),
                        ),
                        if (!item.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ColorSkin.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Ngưng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ColorSkin.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.email ?? item.phone ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$roleLabel · $joinedText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorSkin.subtitle,
                      ),
                    ),
                    if (tenantName != null &&
                        tenantName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Đơn vị: ${tenantName!.trim()}',
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
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.item,
    required this.roleLabel,
    required this.statusLabel,
    required this.directionLabel,
    required this.invitedBy,
    required this.invitedAt,
    required this.expiresAt,
    required this.onAccept,
    required this.onDecline,
  });

  final TenantInvitation item;
  final String roleLabel;
  final String statusLabel;
  final String directionLabel;
  final String invitedBy;
  final String invitedAt;
  final String expiresAt;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    final accepted = item.isAccepted;
    final declined = item.isDeclined;

    final Color chipBackground;
    final Color chipForeground;
    final IconData avatarIcon;
    final Color avatarBackground;
    final Color avatarForeground;

    if (accepted) {
      chipBackground = ColorSkin.tealLight;
      chipForeground = ColorSkin.primary;
      avatarIcon = Icons.check_circle_outline;
      avatarBackground = ColorSkin.tealLight;
      avatarForeground = ColorSkin.primary;
    } else if (declined) {
      chipBackground = ColorSkin.error.withValues(alpha: 0.08);
      chipForeground = ColorSkin.error;
      avatarIcon = Icons.cancel_outlined;
      avatarBackground = ColorSkin.error.withValues(alpha: 0.08);
      avatarForeground = ColorSkin.error;
    } else if (expired) {
      chipBackground = ColorSkin.orangeLight;
      chipForeground = ColorSkin.secondary1;
      avatarIcon = Icons.mail_lock_outlined;
      avatarBackground = ColorSkin.orangeLight;
      avatarForeground = ColorSkin.secondary1;
    } else {
      chipBackground = item.isIncoming
          ? ColorSkin.primary.withValues(alpha: 0.12)
          : ColorSkin.tealLight;
      chipForeground = ColorSkin.primary;
      avatarIcon = item.isIncoming ? Icons.mail_outline : Icons.send_outlined;
      avatarBackground = item.isIncoming
          ? ColorSkin.primary.withValues(alpha: 0.12)
          : ColorSkin.tealLight;
      avatarForeground = ColorSkin.primary;
    }

    return Material(
      color: ColorSkin.white,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorSkin.border1),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: avatarBackground,
              child: Icon(avatarIcon, color: avatarForeground),
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
                          item.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ColorSkin.title,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: chipBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: chipForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    directionLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accepted
                        ? '$roleLabel · Đã chấp nhận'
                        : declined
                        ? '$roleLabel · Đã từ chối'
                        : '$roleLabel · Hết hạn $expiresAt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mời bởi $invitedBy · $invitedAt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorSkin.subtitle,
                    ),
                  ),
                  if (item.canAccept || item.canDecline) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (onDecline != null)
                          Expanded(
                            child: AppButton(
                              label: 'Từ chối',
                              onPressed: onDecline,
                              variant: AppButtonVariant.destructive,
                              height: 40,
                            ),
                          ),
                        if (onDecline != null && onAccept != null)
                          const SizedBox(width: 10),
                        if (onAccept != null)
                          Expanded(
                            child: AppButton(
                              label: 'Chấp nhận',
                              onPressed: onAccept,
                              variant: AppButtonVariant.primary,
                              height: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.search,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String? search;
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 56,
              color: ColorSkin.primary,
            ),
            const SizedBox(height: 12),
            Text(
              search == null || search!.isEmpty
                  ? title
                  : 'Không tìm thấy kết quả',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorSkin.subtitle),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Tải lại')),
          ],
        ),
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
      child: SingleChildScrollView(
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

class _CreateInvitationForm extends StatefulWidget {
  const _CreateInvitationForm({super.key, required this.onSubmitted});

  final void Function(String email, String role) onSubmitted;

  @override
  State<_CreateInvitationForm> createState() => _CreateInvitationFormState();
}

class _CreateInvitationFormState extends State<_CreateInvitationForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _role = 'viewer';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void submit() {
    if (_formKey.currentState?.validate() != true) return;
    widget.onSubmitted(_emailController.text.trim(), _role);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFormField(
            label: 'Email',
            controller: _emailController,
            hintText: 'invitee@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập email';
              }
              if (!value.contains('@')) return 'Email không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: const [
              DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              DropdownMenuItem(
                value: 'warehouse_keeper',
                child: Text('Thủ kho'),
              ),
              DropdownMenuItem(value: 'accountant', child: Text('Kế toán')),
              DropdownMenuItem(value: 'approver', child: Text('Duyệt')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _role = value);
            },
          ),
        ],
      ),
    );
  }
}

class _CreateUserForm extends StatefulWidget {
  const _CreateUserForm({super.key, required this.onSubmitted});

  final void Function(_CreateUserFormData data) onSubmitted;

  @override
  State<_CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormData {
  const _CreateUserFormData({
    this.email,
    this.phone,
    this.name,
    required this.password,
    required this.role,
  });

  final String? email;
  final String? phone;
  final String? name;
  final String password;
  final String role;
}

class _CreateUserFormState extends State<_CreateUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'warehouse_keeper';

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void submit() {
    if (_formKey.currentState?.validate() != true) return;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty && phone.isEmpty) {
      SimpleSnackbarService.showError('Cần ít nhất email hoặc số điện thoại');
      return;
    }
    widget.onSubmitted(
      _CreateUserFormData(
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        name: name.isEmpty ? null : name,
        password: password,
        role: _role,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFormField(
            label: 'Tên hiển thị',
            controller: _nameController,
            hintText: 'Nguyễn Văn A',
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'Email',
            controller: _emailController,
            hintText: 'staff@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'Số điện thoại',
            controller: _phoneController,
            hintText: '0901234567',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'Mật khẩu',
            controller: _passwordController,
            hintText: 'Ít nhất 6 ký tự',
            keyboardType: TextInputType.visiblePassword,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Mật khẩu tối thiểu 6 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: const [
              DropdownMenuItem(
                value: 'warehouse_keeper',
                child: Text('Thủ kho'),
              ),
              DropdownMenuItem(value: 'accountant', child: Text('Kế toán')),
              DropdownMenuItem(value: 'approver', child: Text('Duyệt')),
              DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _role = value);
            },
          ),
        ],
      ),
    );
  }
}
