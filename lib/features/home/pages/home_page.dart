import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/domain/repositories/overview_repository.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';
import 'package:test_y_app/features/document/pages/document_page.dart';
import 'package:test_y_app/features/overview/bloc/overview_bloc.dart';
import 'package:test_y_app/features/overview/pages/overview_page.dart';
import 'package:test_y_app/features/product/bloc/product_list_bloc.dart';
import 'package:test_y_app/features/product/pages/product_list_page.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_list_bloc.dart';
import 'package:test_y_app/features/warehouse/pages/warehouse_list_page.dart';
import 'package:test_y_app/shared/widgets/sidebar_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;
  WarehouseListBloc? _warehouseListBloc;
  ProductListBloc? _productListBloc;
  OverviewBloc? _overviewBloc;
  StockDocumentBloc? _stockDocumentBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warehouseListBloc ??= WarehouseListBloc(
      repository: context.read<WarehouseRepository>(),
    )..add(const WarehouseListStarted());
    _productListBloc ??= ProductListBloc(
      repository: context.read<ProductRepository>(),
    )..add(const ProductListStarted());
    _overviewBloc ??= OverviewBloc(
      repository: context.read<OverviewRepository>(),
    )..add(const OverviewStarted());
    _stockDocumentBloc ??= StockDocumentBloc(
      repository: context.read<StockDocumentRepository>(),
    )..add(const StockDocumentStarted('stock_issue'));
  }

  @override
  void reassemble() {
    super.reassemble();
    _warehouseListBloc?.close();
    _productListBloc?.close();
    _overviewBloc?.close();
    _stockDocumentBloc?.close();
    _warehouseListBloc = WarehouseListBloc(
      repository: context.read<WarehouseRepository>(),
    )..add(const WarehouseListStarted());
    _productListBloc = ProductListBloc(
      repository: context.read<ProductRepository>(),
    )..add(const ProductListStarted());
    _overviewBloc = OverviewBloc(repository: context.read<OverviewRepository>())
      ..add(const OverviewStarted());
    _stockDocumentBloc = StockDocumentBloc(
      repository: context.read<StockDocumentRepository>(),
    )..add(const StockDocumentStarted('stock_issue'));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _warehouseListBloc?.close();
    _productListBloc?.close();
    _overviewBloc?.close();
    _stockDocumentBloc?.close();
    super.dispose();
  }

  static const _tabs = [
    (Icons.dashboard_outlined, 'Thống kê'),
    (Icons.warehouse_outlined, 'Kho'),
    (Icons.inventory_2_outlined, 'Sản phẩm'),
    (Icons.receipt_long_outlined, 'Phiếu'),
    (Icons.bar_chart_outlined, 'Báo cáo'),
    (Icons.person_outline, 'Tôi'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        return previous is AuthAuthenticated &&
            current is AuthAuthenticated &&
            previous.selectedTenantId != current.selectedTenantId;
      },
      listener: (context, state) {
        _warehouseListBloc?.add(const WarehouseListRefreshed());
        _productListBloc?.add(const ProductListRefreshed());
        _overviewBloc?.add(const OverviewRefreshed());
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! AuthAuthenticated) {
            return const Scaffold(
              body: Center(child: Text('Vui lòng đăng nhập')),
            );
          }

          return Scaffold(
            appBar: const SidebarHeader(),
            body: IndexedStack(
              index: _tabIndex,
              children: [
                BlocProvider.value(
                  value: _overviewBloc!,
                  child: const OverviewPage(),
                ),
                BlocProvider.value(
                  value: _warehouseListBloc!,
                  child: const WarehouseListPage(embedded: true),
                ),
                BlocProvider.value(
                  value: _productListBloc!,
                  child: const ProductListPage(embedded: true),
                ),
                BlocProvider.value(
                  value: _stockDocumentBloc!,
                  child: const DocumentPage(embedded: true),
                ),
                const _PlaceholderTab(title: 'Báo cáo', subtitle: 'Sắp ra mắt'),
                _ProfileTab(
                  userName: authState.user.name,
                  email: authState.user.email,
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              indicatorColor: ColorSkin.tealLight,
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.$1),
                    selectedIcon: Icon(tab.$1, color: ColorSkin.primary),
                    label: tab.$2,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: ColorSkin.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorSkin.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.userName, this.email});

  final String userName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: ColorSkin.tealLight,
            child: Text(
              (userName.isNotEmpty ? userName[0] : 'U').toUpperCase(),
              style: const TextStyle(
                color: ColorSkin.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            userName.isEmpty ? 'Người dùng' : userName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(email ?? '—'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.groups_outlined, color: ColorSkin.primary),
          title: const Text('Thành viên'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/members'),
        ),
      ],
    );
  }
}
