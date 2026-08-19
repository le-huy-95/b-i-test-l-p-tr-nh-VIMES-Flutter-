import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/features/product/bloc/product_lookup_bloc.dart';

class ProductBarcodeLookupPage extends StatefulWidget {
  const ProductBarcodeLookupPage({super.key});

  @override
  State<ProductBarcodeLookupPage> createState() =>
      _ProductBarcodeLookupPageState();
}

class _ProductBarcodeLookupPageState extends State<ProductBarcodeLookupPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ProductLookupBloc>().add(
      ProductLookupSubmitted(_controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: Text('Tra cứu nhanh')),
      body: BlocConsumer<ProductLookupBloc, ProductLookupState>(
        listener: (context, state) {
          if (state is ProductLookupFound) {
            context.pushReplacement('/products/${state.product.id}');
          }
        },
        builder: (context, state) {
          final loading = state is ProductLookupLoading;
          return GestureDetector(
            onTap: () =>
                FocusScope.of(context, createDependency: false).unfocus(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ColorSkin.primary, ColorSkin.primarySub],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nhập barcode, SKU hoặc tên để mở nhanh chi tiết sản phẩm.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onTapOutside: (_) => FocusScope.of(
                    context,
                    createDependency: false,
                  ).unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Barcode / SKU / tên',
                    hintText: '893… hoặc SP001',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorSkin.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.manage_search),
                  label: Text(loading ? 'Đang tìm...' : 'Tra cứu'),
                ),
                const SizedBox(height: 20),
                if (state is ProductLookupEmpty)
                  _StateMessage(
                    icon: Icons.search_off,
                    title: 'Không tìm thấy sản phẩm',
                    message: 'Không có sản phẩm nào khớp với "${state.code}".',
                    color: ColorSkin.error,
                  ),
                if (state is ProductLookupFailure)
                  _StateMessage(
                    icon: Icons.error_outline,
                    title: 'Không thể tra cứu',
                    message: state.message,
                    color: ColorSkin.error,
                  ),
                if (state is ProductLookupFound) ...[
                  _PreviewCard(product: state.product),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/products/${state.product.id}'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Xem chi tiết'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ColorSkin.primary, ColorSkin.primarySub],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SKU ${product.sku}',
                      style: TextStyle(color: ColorSkin.subtitle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.barcode ?? 'Chưa có barcode',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: ColorSkin.subtitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
