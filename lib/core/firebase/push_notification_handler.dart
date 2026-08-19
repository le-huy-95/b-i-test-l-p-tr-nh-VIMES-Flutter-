import 'dart:async';

import 'package:logger/logger.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/firebase/push_notification_payload.dart';
import 'package:test_y_app/core/firebase/push_notification_types.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

typedef TenantSelectedCallback = void Function(String tenantId);

class PushNotificationHandler {
  PushNotificationHandler({
    required AuthRepository authRepository,
    TenantSelectedCallback? onTenantSelected,
    Logger? logger,
  })  : _authRepository = authRepository,
        _onTenantSelected = onTenantSelected,
        _logger = logger ?? Logger();

  final AuthRepository _authRepository;
  TenantSelectedCallback? _onTenantSelected;
  final Logger _logger;

  PushNotificationPayload? _pendingPayload;
  bool _authReady = false;

  void setOnTenantSelected(TenantSelectedCallback callback) {
    _onTenantSelected = callback;
  }

  void markAuthReady() {
    if (_authReady) return;
    _authReady = true;
    unawaited(processPendingIfAny());
  }

  Future<void> handle(Map<String, dynamic> data) async {
    final payload = PushNotificationPayload.fromJsonMap(data);
    if (!_authReady) {
      _pendingPayload = payload;
      _logger.i('Push navigation queued until auth ready: ${payload.type}');
      return;
    }
    await _process(payload);
  }

  Future<void> processPendingIfAny() async {
    if (!_authReady) return;

    final pending = _pendingPayload;
    if (pending == null) return;

    _pendingPayload = null;
    await _process(pending);
  }

  Future<void> _process(PushNotificationPayload payload) async {
    if (!await _authRepository.isLoggedIn()) {
      _pendingPayload = payload;
      _logger.i('Push navigation deferred — user not logged in');
      AppRouterConfig.instance.goLogin(
        message: 'Đăng nhập để xem thông báo',
      );
      return;
    }

    try {
      if (payload.type == PushNotificationTypes.inviteReceived) {
        await _handleInviteReceived(payload);
        return;
      }

      if (_shouldSwitchTenant(payload)) {
        await _switchTenant(payload.tenantId!);
      }

      switch (payload.type) {
        case PushNotificationTypes.stockReceiptPending:
        case PushNotificationTypes.stockReceiptApproved:
        case PushNotificationTypes.stockIssuePending:
        case PushNotificationTypes.stockIssueApproved:
          _navigateToHomeWithStockDocHint(payload);
        case PushNotificationTypes.general:
          _navigateToHomeWithOptionalMessage(payload);
        default:
          _navigateToHomeWithOptionalMessage(payload);
      }
    } catch (e, st) {
      _logger.e('Push navigation failed', error: e, stackTrace: st);
      SimpleSnackbarService.showError('Không mở được thông báo');
    }
  }

  bool _shouldSwitchTenant(PushNotificationPayload payload) {
    final tenantId = payload.tenantId;
    return tenantId != null && tenantId.isNotEmpty;
  }

  Future<void> _switchTenant(String tenantId) async {
    await _authRepository.selectTenant(tenantId);
    AppRouterConfig.instance.setAuthState(true, hasTenant: true);
    _onTenantSelected?.call(tenantId);
  }

  Future<void> _handleInviteReceived(PushNotificationPayload payload) async {
    AppRouterConfig.instance.setAuthState(true, hasTenant: false);
    AppRouterConfig.instance.goSelectTenant();
    SimpleSnackbarService.showInfo(
      payload.body ??
          payload.title ??
          'Bạn có lời mời tham gia tổ chức',
    );
  }

  void _navigateToHomeWithStockDocHint(PushNotificationPayload payload) {
    AppRouterConfig.instance.goHome();
    SimpleSnackbarService.showInfo(stockDocFallbackMessage(payload));
  }

  void _navigateToHomeWithOptionalMessage(PushNotificationPayload payload) {
    AppRouterConfig.instance.goHome();
    final message = payload.body ?? payload.title;
    if (message != null && message.trim().isNotEmpty) {
      SimpleSnackbarService.showInfo(message);
    }
  }

  static String stockDocFallbackMessage(PushNotificationPayload payload) {
    final label = switch (payload.type) {
      PushNotificationTypes.stockReceiptPending ||
      PushNotificationTypes.stockReceiptApproved =>
        'Phiếu nhập',
      PushNotificationTypes.stockIssuePending ||
      PushNotificationTypes.stockIssueApproved =>
        'Phiếu xuất',
      _ => 'Phiếu',
    };

    final targetId = payload.targetId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      return '$label $targetId — chi tiết sẽ có khi module Phiếu ra mắt';
    }
    return '$label — chi tiết sẽ có khi module Phiếu ra mắt';
  }
}
