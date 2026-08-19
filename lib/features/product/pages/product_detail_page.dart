import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/auth/tenant_permissions.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/product/bloc/product_detail_bloc.dart';
import 'package:test_y_app/features/product/product_formatters.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/utils/media_url.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_section_card.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await AppBottomSheetService.showConfirm(
      context: context,
      title: 'Xóa sản phẩm?',
      message: 'Sản phẩm sẽ được vô hiệu hóa (soft delete).',
      confirmLabel: 'Xóa',
      cancelLabel: 'Hủy',
      confirmStyle: AppBottomSheetActionStyle.destructive,
    );
    if (ok == true && context.mounted) {
      context.read<ProductDetailBloc>().add(
        const ProductDetailDeleteRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final canManage = canManageMasterDataForAuthState(authState);

        return BlocConsumer<ProductDetailBloc, ProductDetailState>(
          listener: (context, state) {
            if (state is ProductDetailDeleted) {
              SimpleSnackbarService.showSuccess('Đã xóa sản phẩm');
              context.pop(true);
            }
            if (state is ProductDetailFailure) {
              SimpleSnackbarService.showError(state.message);
            }
          },
          builder: (context, state) {
            return Scaffold(
              appBar: AppHeader(
                title: const Text('Chi tiết Sản phẩm'),
                actions: [
                  if (canManage && state is ProductDetailLoaded)
                    IconButton(
                      tooltip: 'Xóa sản phẩm',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
              bottomNavigationBar: canManage && state is ProductDetailLoaded
                  ? SafeArea(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: ColorSkin.border1.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        child: AppButton(
                          label: 'Sửa sản phẩm',
                          onPressed: () async {
                            final ok = await context.push<bool>(
                              '/products/$productId/edit',
                            );
                            if (ok == true && context.mounted) {
                              context.read<ProductDetailBloc>().add(
                                ProductDetailStarted(productId),
                              );
                            }
                          },
                          variant: AppButtonVariant.primary,
                          icon: const Icon(Icons.edit_outlined),
                          expand: true,
                        ),
                      ),
                    )
                  : null,
              body: Builder(
                builder: (context) {
                  if (state is ProductDetailLoading ||
                      state is ProductDetailInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ProductDetailFailure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.message, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => context
                                  .read<ProductDetailBloc>()
                                  .add(ProductDetailStarted(productId)),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state is! ProductDetailLoaded) {
                    return const SizedBox.shrink();
                  }
                  return _ProductDetailBody(
                    product: state.product,
                    availability: state.availability,
                    canManage: canManage,
                    productId: productId,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({
    required this.product,
    required this.availability,
    required this.canManage,
    required this.productId,
  });

  final Product product;
  final ProductAvailability? availability;
  final bool canManage;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProductDetailBloc>().add(ProductDetailStarted(productId));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          _ProductHeader(product: product, availability: availability),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tổng quan',
            child: Column(
              children: [
                _DetailRow(label: 'Barcode', value: product.barcode ?? '—'),
                _DetailRow(label: 'Đơn vị gốc', value: product.baseUnitName),
                _DetailRow(
                  label: 'Mức tồn tối thiểu',
                  value: formatQty(product.minStockLevel),
                ),
                _DetailRow(
                  label: 'Mức tồn tối đa',
                  value: formatNullableQty(product.maxStockLevel),
                ),
                _DetailRow(
                  label: 'Điểm đặt hàng lại',
                  value: formatNullableQty(product.reorderPoint),
                ),
                _DetailRow(
                  label: 'Giá vốn',
                  value: formatMoneyWithCurrency(product.averageCost),
                ),
                _DetailRow(label: 'Trạng thái', value: product.statusText),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tồn kho theo kho',
            child: availability == null
                ? Text(
                    'Chưa có dữ liệu tồn kho',
                    style: TextStyle(color: ColorSkin.subtitle),
                  )
                : availability!.warehouses.isEmpty
                ? Text(
                    'Không có kho nào ghi nhận tồn cho sản phẩm này',
                    style: TextStyle(color: ColorSkin.subtitle),
                  )
                : Column(
                    children: [
                      for (final w in availability!.warehouses) ...[
                        _WarehouseStockCard(stock: w),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product, required this.availability});

  final Product product;
  final ProductAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(product.imageUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 160,
                color: ColorSkin.tealLight.withValues(alpha: 0.5),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: ColorSkin.subtitle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ColorSkin.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU ${product.sku}${product.barcode != null ? ' · ${product.barcode}' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: ColorSkin.subtitle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(active: product.isActive),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

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
        active ? 'Hoạt động' : 'Ngừng bán',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? ColorSkin.primarySub : const Color(0xFFB8860B),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(title: title, child: child);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ColorSkin.subtitle,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ColorSkin.title,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseStockCard extends StatelessWidget {
  const _WarehouseStockCard({required this.stock});

  final ProductWarehouseStock stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorSkin.tealLight.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stock.warehouseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (stock.warehouse?.code != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stock.warehouse!.code!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StockMetric(
                  label: 'Tồn',
                  value: formatQty(stock.onhandQty),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StockMetric(
                  label: 'Đặt giữ',
                  value: formatQty(stock.reservedQty),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StockMetric(
                  label: 'Khả dụng',
                  value: formatQty(stock.availableQty),
                ),
              ),
            ],
          ),
          if (stock.lots.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Chi tiết lô',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColorSkin.subtitle,
              ),
            ),
            const SizedBox(height: 8),
            for (final lot in stock.lots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lot.batchNo ?? 'Không theo dõi lô',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${formatQty(lot.availableQty)} / ${formatQty(lot.onhandQty)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorSkin.subtitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  const _StockMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: ColorSkin.subtitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
