import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/app/app_theme.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/firebase/firebase_service.dart';
import 'package:test_y_app/core/firebase/push_notification_handler.dart';
import 'package:test_y_app/core/firebase/push_notification_listener.dart';
import 'package:test_y_app/data/repositories/auth_repository_impl.dart';
import 'package:test_y_app/data/repositories/demo_repository_impl.dart';
import 'package:test_y_app/data/repositories/file_repository.dart';
import 'package:test_y_app/data/repositories/notification_repository_impl.dart';
import 'package:test_y_app/data/repositories/overview_repository_impl.dart';
import 'package:test_y_app/data/repositories/product_repository_impl.dart';
import 'package:test_y_app/data/repositories/stock_document_repository_impl.dart';
import 'package:test_y_app/data/repositories/stock_issue_repository_impl.dart';
import 'package:test_y_app/data/repositories/stock_receipt_repository_impl.dart';
import 'package:test_y_app/data/repositories/warehouse_repository_impl.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/domain/repositories/demo_repository.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/domain/repositories/notification_repository.dart';
import 'package:test_y_app/domain/repositories/overview_repository.dart';
import 'package:test_y_app/domain/repositories/product_repository.dart';
import 'package:test_y_app/domain/repositories/stock_document_repository.dart';
import 'package:test_y_app/domain/repositories/stock_issue_repository.dart';
import 'package:test_y_app/domain/repositories/stock_receipt_repository.dart';
import 'package:test_y_app/domain/repositories/warehouse_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/notification/bloc/notification_bloc.dart';
import 'package:test_y_app/features/notification/bloc/notification_event.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class BaseApp extends StatefulWidget {
  const BaseApp({super.key});

  @override
  State<BaseApp> createState() => _BaseAppState();
}

class _BaseAppState extends State<BaseApp> {
  final AuthRepository _authRepository = AuthRepositoryImpl();
  final DemoRepository _demoRepository = DemoRepositoryImpl();
  final WarehouseRepository _warehouseRepository = WarehouseRepositoryImpl();
  final ProductRepository _productRepository = ProductRepositoryImpl();
  final StockDocumentRepository _stockDocumentRepository =
      StockDocumentRepositoryImpl();
  final StockIssueRepository _stockIssueRepository = StockIssueRepositoryImpl();
  final StockReceiptRepository _stockReceiptRepository =
      StockReceiptRepositoryImpl();
  final OverviewRepository _overviewRepository = OverviewRepositoryImpl();
  final NotificationRepository _notificationRepository =
      NotificationRepositoryImpl();
  final FileRepository _fileRepository = FileRepositoryImpl();

  PushNotificationHandler? _pushNotificationHandler;

  PushNotificationHandler get _notificationHandler =>
      _pushNotificationHandler ??=
          PushNotificationHandler(authRepository: _authRepository);

  NotificationBloc _createNotificationBloc() {
    final bloc = NotificationBloc(repository: _notificationRepository);
    // Load notifications only when a session already exists. When the user
    // is not logged in yet, the auth listener below triggers the first load
    // right after login/tenant selection completes.
    unawaited(_authRepository.isLoggedIn().then((loggedIn) {
      if (loggedIn && !bloc.isClosed) {
        bloc.add(const NotificationRefreshed());
      }
    }));
    return bloc;
  }

  @override
  void initState() {
    super.initState();

    FirebaseService.instance.setDeviceRegistrationHandler(() async {
      if (await _authRepository.isLoggedIn()) {
        await _authRepository.registerDevice();
      }
    });

    FirebaseService.instance.setNotificationTapHandler((data) {
      unawaited(_notificationHandler.handle(data));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<DemoRepository>.value(value: _demoRepository),
        RepositoryProvider<WarehouseRepository>.value(
          value: _warehouseRepository,
        ),
        RepositoryProvider<ProductRepository>.value(value: _productRepository),
        RepositoryProvider<StockDocumentRepository>.value(
          value: _stockDocumentRepository,
        ),
        RepositoryProvider<OverviewRepository>.value(
          value: _overviewRepository,
        ),
        RepositoryProvider<StockIssueRepository>.value(
          value: _stockIssueRepository,
        ),
        RepositoryProvider<StockReceiptRepository>.value(
          value: _stockReceiptRepository,
        ),
        RepositoryProvider<FileRepository>.value(
          value: _fileRepository,
        ),
        RepositoryProvider<NotificationRepository>.value(
          value: _notificationRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(authRepository: _authRepository),
          ),
          BlocProvider<NotificationBloc>(
            create: (_) => _createNotificationBloc(),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthAuthenticated &&
              (previous is! AuthAuthenticated ||
                  previous.selectedTenantId != current.selectedTenantId),
          listener: (context, state) {
            // After login/tenant selection, always re-fetch all
            // notifications (e.g. organization invitations) and unread count.
            context.read<NotificationBloc>().add(const NotificationRefreshed());
          },
          child: PushNotificationListener(
            handler: _notificationHandler,
            child: MaterialApp.router(
              title: 'Test Y App',
              debugShowCheckedModeBanner: false,
              locale: const Locale('vi', 'VN'),
              supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,
              routerConfig: AppRouterConfig.instance.router,
              scaffoldMessengerKey: SimpleSnackbarService.scaffoldMessengerKey,
              builder: (context, child) {
                final botToastBuilder = BotToastInit();
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
                  child: botToastBuilder(context, child),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
