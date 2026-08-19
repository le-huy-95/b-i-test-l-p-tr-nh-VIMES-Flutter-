import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/domain/repositories/notification_repository.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_bloc.dart';
import 'package:test_y_app/features/auth/bloc/login_bloc.dart';
import 'package:test_y_app/features/auth/bloc/otp_bloc.dart';
import 'package:test_y_app/features/auth/bloc/register_bloc.dart';
import 'package:test_y_app/features/auth/bloc/reset_password_bloc.dart';
import 'package:test_y_app/features/auth/pages/forgot_password_page.dart';
import 'package:test_y_app/features/auth/pages/login_page.dart';
import 'package:test_y_app/features/auth/pages/register_page.dart';
import 'package:test_y_app/features/auth/pages/reset_password_page.dart';
import 'package:test_y_app/features/auth/pages/select_tenant_page.dart';
import 'package:test_y_app/features/auth/pages/verify_otp_page.dart';
import 'package:test_y_app/features/document/bloc/stock_document_bloc.dart';
import 'package:test_y_app/features/document/pages/document_page.dart';
import 'package:test_y_app/features/document/pages/stock_issue_form_page.dart';
import 'package:test_y_app/features/document/pages/stock_receipt_form_page.dart';
import 'package:test_y_app/features/home/pages/home_page.dart';
import 'package:test_y_app/features/notification/bloc/notification_bloc.dart';
import 'package:test_y_app/features/tenant_people/pages/tenant_people_page.dart';
import 'package:test_y_app/features/notification/bloc/notification_event.dart';
import 'package:test_y_app/features/notification/pages/notification_inbox_page.dart';
import 'package:test_y_app/features/product/bloc/product_detail_bloc.dart';
import 'package:test_y_app/features/product/bloc/product_form_bloc.dart';
import 'package:test_y_app/features/product/bloc/product_list_bloc.dart';
import 'package:test_y_app/features/product/bloc/product_lookup_bloc.dart';
import 'package:test_y_app/features/product/pages/product_barcode_lookup_page.dart';
import 'package:test_y_app/features/product/pages/product_detail_page.dart';
import 'package:test_y_app/features/product/pages/product_form_page.dart';
import 'package:test_y_app/features/product/pages/product_list_page.dart';
import 'package:test_y_app/features/splash/pages/splash_page.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_detail_bloc.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_form_bloc.dart';
import 'package:test_y_app/features/warehouse/pages/warehouse_detail_page.dart';
import 'package:test_y_app/features/warehouse/pages/warehouse_form_page.dart';

enum AppRoutes {
  splash('/'),
  login('/login'),
  register('/register'),
  verifyOtp('/verify-otp'),
  forgotPassword('/forgot-password'),
  resetPassword('/reset-password'),
  selectTenant('/select-tenant'),
  home('/home'),
  members('/members'),
  warehousesNew('/warehouses/new'),
  warehouseDetail('/warehouses/:id'),
  warehouseEdit('/warehouses/:id/edit'),
  products('/products'),
  productsLookup('/products/lookup'),
  productsNew('/products/new'),
  productDetail('/products/:id'),
  productEdit('/products/:id/edit'),
  notificationInbox('/notifications'),
  documents('/documents'),
  stockIssueNew('/documents/stock-issue/new'),
  stockIssueEdit('/documents/stock-issue/:id/edit'),
  stockReceiptNew('/documents/stock-receipt/new'),
  stockReceiptEdit('/documents/stock-receipt/:id/edit');

  const AppRoutes(this.path);
  final String path;
}

class AppRouterConfig {
  AppRouterConfig._();

  static final AppRouterConfig instance = AppRouterConfig._();

  bool _isAuthenticated = false;
  bool _hasTenant = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get hasTenant => _hasTenant;

  void setAuthState(bool isAuthenticated, {bool? hasTenant}) {
    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) {
      _hasTenant = false;
    } else if (hasTenant != null) {
      _hasTenant = hasTenant;
    }
  }

  bool _needsTenant(String location) {
    return location == AppRoutes.home.path ||
        location.startsWith('/warehouses') ||
        location.startsWith('/products') ||
        location == AppRoutes.notificationInbox.path ||
        location.startsWith('/documents') ||
        location == AppRoutes.members.path ||
        location.startsWith('/members');
  }

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash.path,
    observers: [BotToastNavigatorObserver()],
    routes: [
      GoRoute(
        path: AppRoutes.splash.path,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login.path,
        builder: (context, state) {
          final extra = state.extra;
          String? message;
          if (extra is Map) {
            message = extra['message']?.toString();
          } else if (state.uri.queryParameters['message'] != null) {
            message = state.uri.queryParameters['message'];
          }
          return BlocProvider(
            create: (context) =>
                LoginBloc(authRepository: context.read<AuthRepository>()),
            child: LoginPage(infoMessage: message),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            key: const ValueKey('register-flow'),
            create: (context) =>
                RegisterBloc(authRepository: context.read<AuthRepository>()),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.register.path,
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: AppRoutes.verifyOtp.path,
            builder: (context, state) {
              final extra = state.extra;
              String? email = state.uri.queryParameters['email'];
              String? phone = state.uri.queryParameters['phone'];
              if (extra is Map) {
                email ??= extra['email']?.toString();
                phone ??= extra['phone']?.toString();
              }
              final draft = context.read<RegisterBloc>().state.draft;
              email ??= draft.email.trim().isEmpty ? null : draft.email.trim();
              phone ??= draft.phone.trim().isEmpty ? null : draft.phone.trim();
              return BlocProvider(
                create: (context) => OtpBloc(
                  authRepository: context.read<AuthRepository>(),
                  email: email,
                  phone: phone,
                ),
                child: VerifyOtpPage(email: email, phone: phone),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.forgotPassword.path,
        builder: (context, state) {
          final extra = state.extra;
          String? initialEmail = state.uri.queryParameters['email'];
          if (extra is Map) {
            initialEmail ??= extra['email']?.toString();
          }
          return BlocProvider(
            create: (context) => ForgotPasswordBloc(
              authRepository: context.read<AuthRepository>(),
            ),
            child: ForgotPasswordPage(initialEmail: initialEmail),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword.path,
        builder: (context, state) {
          final extra = state.extra;
          String? email = state.uri.queryParameters['email'];
          DateTime? expiresAt;
          String? message;
          if (extra is Map) {
            email ??= extra['email']?.toString();
            final rawExpires = extra['expiresAt']?.toString();
            if (rawExpires != null) {
              expiresAt = DateTime.tryParse(rawExpires);
            }
            message = extra['message']?.toString();
          }
          email ??= '';
          return BlocProvider(
            create: (context) => ResetPasswordBloc(
              authRepository: context.read<AuthRepository>(),
              email: email!,
            ),
            child: ResetPasswordPage(
              email: email,
              expiresAt: expiresAt,
              infoMessage: message,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.selectTenant.path,
        builder: (context, state) => const SelectTenantPage(),
      ),
      GoRoute(
        path: AppRoutes.home.path,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.members.path,
        builder: (context, state) => const TenantPeoplePage(),
      ),
      GoRoute(
        path: AppRoutes.warehousesNew.path,
        builder: (context, state) => BlocProvider(
          create: (context) => WarehouseFormBloc(
            repository: context.read<WarehouseRepository>(),
          ),
          child: const WarehouseFormPage(),
        ),
      ),
      GoRoute(
        path: '/warehouses/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => WarehouseFormBloc(
              repository: context.read<WarehouseRepository>(),
              warehouseId: id,
            )..add(WarehouseFormLoadExisting(id)),
            child: WarehouseFormPage(warehouseId: id),
          );
        },
      ),
      GoRoute(
        path: '/warehouses/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => WarehouseDetailBloc(
              repository: context.read<WarehouseRepository>(),
            )..add(WarehouseDetailStarted(id)),
            child: WarehouseDetailPage(warehouseId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.products.path,
        builder: (context, state) => BlocProvider(
          create: (context) =>
              ProductListBloc(repository: context.read<ProductRepository>())
                ..add(const ProductListStarted()),
          child: const ProductListPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.productsLookup.path,
        builder: (context, state) => BlocProvider(
          create: (context) =>
              ProductLookupBloc(repository: context.read<ProductRepository>()),
          child: const ProductBarcodeLookupPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.productsNew.path,
        builder: (context, state) => BlocProvider(
          create: (context) =>
              ProductFormBloc(repository: context.read<ProductRepository>()),
          child: const ProductFormPage(),
        ),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => ProductFormBloc(
              repository: context.read<ProductRepository>(),
              productId: id,
            )..add(ProductFormLoadExisting(id)),
            child: ProductFormPage(productId: id),
          );
        },
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => ProductDetailBloc(
              repository: context.read<ProductRepository>(),
              productId: id,
            )..add(ProductDetailStarted(id)),
            child: ProductDetailPage(productId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notificationInbox.path,
        builder: (context, state) => BlocProvider(
          create: (context) => NotificationBloc(
            repository: context.read<NotificationRepository>(),
          )..add(const NotificationStarted()),
          child: const NotificationInboxPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.documents.path,
        builder: (context, state) => BlocProvider(
          create: (context) => StockDocumentBloc(
            repository: context.read<StockDocumentRepository>(),
          )..add(const StockDocumentStarted('stock_issue')),
          child: const DocumentPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.stockIssueNew.path,
        builder: (context, state) => BlocProvider(
          create: (context) => StockDocumentBloc(
            repository: context.read<StockDocumentRepository>(),
          )..add(const StockDocumentStarted('stock_issue')),
          child: const _StockIssueCreateRoute(),
        ),
      ),
      GoRoute(
        path: AppRoutes.stockIssueEdit.path,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => StockDocumentBloc(
              repository: context.read<StockDocumentRepository>(),
            )..add(const StockDocumentStarted('stock_issue')),
            child: StockIssueFormPage(issueId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.stockReceiptNew.path,
        builder: (context, state) => BlocProvider(
          create: (context) => StockDocumentBloc(
            repository: context.read<StockDocumentRepository>(),
          )..add(const StockDocumentStarted('stock_receipt')),
          child: const _StockReceiptCreateRoute(),
        ),
      ),
      GoRoute(
        path: AppRoutes.stockReceiptEdit.path,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) => StockDocumentBloc(
              repository: context.read<StockDocumentRepository>(),
            )..add(const StockDocumentStarted('stock_receipt')),
            child: StockReceiptFormPage(receiptId: id),
          );
        },
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == AppRoutes.splash.path;
      final isAuthFlow =
          location == AppRoutes.login.path ||
          location == AppRoutes.register.path ||
          location == AppRoutes.verifyOtp.path ||
          location == AppRoutes.forgotPassword.path ||
          location == AppRoutes.resetPassword.path;

      if (isSplash) return null;

      if (!_isAuthenticated &&
          (_needsTenant(location) || location == AppRoutes.selectTenant.path)) {
        return AppRoutes.login.path;
      }

      if (_isAuthenticated && !_hasTenant && _needsTenant(location)) {
        return AppRoutes.selectTenant.path;
      }

      if (_isAuthenticated && _hasTenant && isAuthFlow) {
        return AppRoutes.home.path;
      }

      return null;
    },
  );

  void goLogin({String? message}) {
    if (message != null && message.isNotEmpty) {
      router.go(AppRoutes.login.path, extra: {'message': message});
    } else {
      router.go(AppRoutes.login.path);
    }
  }

  void goHome() => router.go(AppRoutes.home.path);
  void goSelectTenant() => router.go(AppRoutes.selectTenant.path);
  void goRegister() => router.go(AppRoutes.register.path);

  void goVerifyOtp({String? email, String? phone}) {
    final extra = <String, String>{};
    if (email != null) extra['email'] = email;
    if (phone != null) extra['phone'] = phone;
    router.go(AppRoutes.verifyOtp.path, extra: extra);
  }

  void goForgotPassword({String? email}) {
    router.go(
      AppRoutes.forgotPassword.path,
      extra: email != null ? {'email': email} : null,
    );
  }

  void goResetPassword({
    required String email,
    DateTime? expiresAt,
    String? message,
  }) {
    router.push(
      AppRoutes.resetPassword.path,
      extra: {
        'email': email,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
  }
}

class _StockIssueCreateRoute extends StatelessWidget {
  const _StockIssueCreateRoute();

  @override
  Widget build(BuildContext context) {
    return const StockIssueFormPage();
  }
}

class _StockReceiptCreateRoute extends StatelessWidget {
  const _StockReceiptCreateRoute();

  @override
  Widget build(BuildContext context) {
    return const StockReceiptFormPage();
  }
}
