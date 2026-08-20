import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_list_bloc.dart';
import 'package:test_y_app/shared/widgets/app_search_field.dart';
import 'package:test_y_app/shared/widgets/status_toggle.dart';

class WarehouseListPage extends StatelessWidget {
  const WarehouseListPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final canManage = canManageMasterDataForAuthState(authState);
        final canCreate = canCreateMasterDataForAuthState(authState);

        final body = BlocListener<WarehouseListBloc, WarehouseListState>(
          listenWhen: (previous, current) =>
              current is WarehouseListLoaded &&
              current.errorMessage != null &&
              (previous is! WarehouseListLoaded ||
                  previous.errorMessage != current.errorMessage),
          listener: (context, state) {
            final message = (state as WarehouseListLoaded).errorMessage!;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          },
          child: BlocBuilder<WarehouseListBloc, WarehouseListState>(
            builder: (context, state) {
              if (state is WarehouseListLoading ||
                  state is WarehouseListInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is WarehouseListFailure) {
                return _ErrorView(message: state.message);
              }
              if (state is! WarehouseListLoaded) {
                return const SizedBox.shrink();
              }

              final items = state.filtered;
              return RefreshIndicator(
                onRefresh: () => _pullRefresh(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    AppSearchField<Warehouse>(
                      hintText: 'Tìm theo tên hoặc mã kho...',
                      searchApi: (query) async {
                        context.read<WarehouseListBloc>().add(
                          WarehouseListSearchChanged(query),
                        );
                        final current = context.read<WarehouseListBloc>().state;
                        if (current is WarehouseListLoaded) {
                          return current.filtered;
                        }
                        return const [];
                      },
                      onResultsChanged: (_) {},
                      onChanged: (q) => context.read<WarehouseListBloc>().add(
                        WarehouseListSearchChanged(q),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryBar(count: items.length),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const _EmptyView()
                    else
                      ...items.map(
                        (w) =>
                            _WarehouseCard(warehouse: w, canManage: canManage),
                      ),
                  ],
                ),
              );
            },
          ),
        );

        if (embedded) {
          return Stack(
            children: [
              body,
              if (canCreate) _AddFab(onRefresh: () => _refresh(context)),
            ],
          );
        }

        return Scaffold(
          appBar: AppHeader(
            title: const Text('Danh sách Kho'),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.add, color: ColorSkin.primary),
                  onPressed: () => _addWarehouse(context),
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Future<void> _addWarehouse(BuildContext context) async {
    final ok = await context.push<bool>('/warehouses/new');
    if (ok == true && context.mounted) _refresh(context);
  }

  Future<void> _pullRefresh(BuildContext context) async {
    final bloc = context.read<WarehouseListBloc>();
    bloc.add(const WarehouseListRefreshed());
    await bloc.stream.firstWhere(
      (state) =>
          (state is WarehouseListLoaded && !state.isRefreshing) ||
          state is WarehouseListFailure,
    );
  }

  void _refresh(BuildContext context) {
    context.read<WarehouseListBloc>().add(const WarehouseListRefreshed());
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ColorSkin.tealLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count kho',
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.warehouse_outlined, size: 56, color: ColorSkin.border1),
          const SizedBox(height: 12),
          Text(
            'Chưa có kho hàng',
            style: TextStyle(
              color: ColorSkin.subtitle,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<WarehouseListBloc>().add(
                const WarehouseListRefreshed(),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'warehouse_add',
        backgroundColor: ColorSkin.primary,
        onPressed: () async {
          final ok = await context.push<bool>('/warehouses/new');
          if (ok == true && context.mounted) onRefresh();
        },
        child: const Icon(Icons.add, color: ColorSkin.white),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse, this.canManage = false});
  final Warehouse warehouse;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/warehouses/${warehouse.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ColorSkin.border1.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildIcon(),
                    const SizedBox(width: 12),
                    Expanded(child: _buildHeader()),
                    _buildStatusChip(),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: ColorSkin.grey3),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  warehouse.address ?? 'Chưa có địa chỉ',
                ),
                if (warehouse.phone != null && warehouse.phone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildInfoRow(
                      Icons.phone_outlined,
                      warehouse.phone!,
                    ),
                  ),
                if (canManage) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: ColorSkin.grey3),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatusToggle(
                      isActive: warehouse.isActive,
                      onToggle: (_) => context.read<WarehouseListBloc>().add(
                        WarehouseListToggleStatus(warehouse.id),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ColorSkin.primary, ColorSkin.primarySub],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.warehouse_outlined,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          warehouse.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: ColorSkin.title,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          warehouse.code,
          style: const TextStyle(
            fontSize: 12,
            color: ColorSkin.subtitle,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    final isActive = warehouse.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? ColorSkin.tealLight : ColorSkin.orangeLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        warehouse.statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive ? ColorSkin.primarySub : const Color(0xFFB8860B),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: ColorSkin.subtitle),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: ColorSkin.subtitle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
