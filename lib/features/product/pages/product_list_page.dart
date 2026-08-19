import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/product/bloc/product_list_bloc.dart';
import 'package:test_y_app/features/product/product_formatters.dart';
import 'package:test_y_app/shared/utils/media_url.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_search_field.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final canManage = canManageMasterDataForAuthState(authState);

        final body = BlocBuilder<ProductListBloc, ProductListState>(
          builder: (context, state) {
            if (state is ProductListLoading || state is ProductListInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProductListFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.read<ProductListBloc>().add(
                          const ProductListRefreshed(),
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is! ProductListLoaded) return const SizedBox.shrink();
            final items = state.filtered;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ProductListBloc>().add(const ProductListRefreshed());
              },
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  AppSearchField<Product>(
                    hintText: 'Tìm theo SKU, tên hoặc barcode...',
                    searchApi: (query) async {
                      context.read<ProductListBloc>().add(
                        ProductListSearchChanged(query),
                      );
                      final current = context.read<ProductListBloc>().state;
                      if (current is ProductListLoaded) {
                        return current.filtered;
                      }
                      return const [];
                    },
                    onResultsChanged: (_) {},
                    onChanged: (q) => context.read<ProductListBloc>().add(
                      ProductListSearchChanged(q),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: const Center(child: _EmptyState()),
                    )
                  else
                    ...items.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductCard(product: p),
                      ),
                    ),
                ],
              ),
            );
          },
        );

        if (embedded) {
          return Stack(
            children: [
              body,
              if (canManage)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'product_add',
                    backgroundColor: ColorSkin.primary,
                    foregroundColor: ColorSkin.white,
                    tooltip: 'Thêm sản phẩm',
                    onPressed: () async {
                      final ok = await context.push<bool>('/products/new');
                      if (ok == true && context.mounted) {
                        context.read<ProductListBloc>().add(
                          const ProductListRefreshed(),
                        );
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          appBar: AppHeader(
            variant: AppHeaderVariant.detail,
            title: const Text('Sản phẩm'),
            actions: [
              IconButton(
                tooltip: 'Tra barcode',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => context.push('/products/lookup'),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.add, color: ColorSkin.primary),
                  onPressed: () async {
                    final ok = await context.push<bool>('/products/new');
                    if (ok == true && context.mounted) {
                      context.read<ProductListBloc>().add(
                        const ProductListRefreshed(),
                      );
                    }
                  },
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: ColorSkin.border1),
          const SizedBox(height: 12),
          const Text(
            'Chưa có sản phẩm',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo sản phẩm đầu tiên để bắt đầu quản lý danh mục.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorSkin.subtitle),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      product.sku,
      if (product.barcode != null && product.barcode!.isNotEmpty)
        product.barcode!,
      product.baseUnitName,
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/products/${product.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ColorSkin.border1.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ColorSkin.primary, ColorSkin.primarySub],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: () {
                      final resolved = resolveMediaUrl(product.imageUrl);
                      return resolved != null
                          ? Image.network(
                              resolved,
                              fit: BoxFit.cover,
                              width: 46,
                              height: 46,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white,
                              size: 24,
                            );
                    }(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ColorSkin.title,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColorSkin.subtitle,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(active: product.isActive),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: 'Tồn tối thiểu',
                    value: formatQty(product.minStockLevel),
                  ),
                  if (product.maxStockLevel != null)
                    _InfoChip(
                      label: 'Tồn tối đa',
                      value: formatQty(product.maxStockLevel!),
                    ),
                  if (product.reorderPoint != null)
                    _InfoChip(
                      label: 'Điểm đặt hàng',
                      value: formatQty(product.reorderPoint!),
                    ),
                  _InfoChip(
                    label: 'Giá vốn',
                    value: formatMoneyWithCurrency(product.averageCost),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ColorSkin.tealLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColorSkin.primarySub,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? ColorSkin.tealLight : ColorSkin.orangeLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Hoạt động' : 'Ngừng',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? ColorSkin.primarySub : const Color(0xFFB8860B),
        ),
      ),
    );
  }
}
