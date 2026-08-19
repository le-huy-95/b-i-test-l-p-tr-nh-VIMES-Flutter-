import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

String _authPathWithoutQuery(String path) => path.split('?').first;

bool _isPublicAuthPath(String path) {
  final p = _authPathWithoutQuery(path);
  return p == ApiEndpoints.authRegister ||
      p == ApiEndpoints.authVerifyOtp ||
      p == ApiEndpoints.authResendOtp ||
      p == ApiEndpoints.authLogout ||
      p == ApiEndpoints.authRefresh ||
      p.startsWith(ApiEndpoints.authLogin);
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

class _PendingRequest {
  _PendingRequest(this.error, this.handler);

  final DioException error;
  final ErrorInterceptorHandler handler;
}

class AuthInterceptor extends Interceptor {
  final Logger _logger = Logger();
  final StorageManager _storage = StorageManager();
  final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  Future<void> _forceReLogin() async {
    try {
      SimpleSnackbarService.showError('Phiên đăng nhập hết hạn, vui lòng đăng nhập lại');
      AppRouterConfig.instance.goLogin();
    } catch (e, st) {
      _logger.e('AuthInterceptor: lỗi khi chuyển về màn đăng nhập', error: e, stackTrace: st);
    }
  }

  Future<void> _applyAuthHeaders(RequestOptions options) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    final tenantId = await _storage.getTenantId();
    if (tenantId != null && tenantId.isNotEmpty) {
      options.headers['X-Tenant-Id'] = tenantId;
    }
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.path;
    if (_isPublicAuthPath(path)) {
      return handler.next(options);
    }

    await _applyAuthHeaders(options);
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode ?? 0;
    final path = err.requestOptions.path;

    if (status == 401 && !_isPublicAuthPath(path)) {
      if (_isRefreshing) {
        _pendingRequests.add(_PendingRequest(err, handler));
        return;
      }

      var refreshSucceeded = false;
      try {
        _isRefreshing = true;
        final newAccessToken = await _refreshAccessToken();
        if (newAccessToken == null) {
          await _storage.clearAuthData();
          await _forceReLogin();
          return handler.next(err);
        }

        await _retryRequest(err, handler, newAccessToken);
        refreshSucceeded = true;
      } catch (e, st) {
        _logger.e('AuthInterceptor: làm mới token thất bại', error: e, stackTrace: st);
        await _storage.clearAuthData();
        await _forceReLogin();
        return handler.next(err);
      } finally {
        _isRefreshing = false;
        final pending = List.of(_pendingRequests);
        _pendingRequests.clear();
        for (final request in pending) {
          if (refreshSucceeded) {
            await _replayPending(request);
          } else {
            request.handler.next(request.error);
          }
        }
      }
      return;
    }

    return handler.next(err);
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final refreshResponse = await _refreshDio.post<dynamic>(
      ApiEndpoints.authRefresh,
      data: {'refreshToken': refreshToken},
    );

    final envelope = _asStringKeyedMap(refreshResponse.data);
    final data = _asStringKeyedMap(envelope?['data']) ?? envelope;
    final newAccessToken = data?['accessToken']?.toString();
    final newRefreshToken = data?['refreshToken']?.toString();

    if (newAccessToken == null || newAccessToken.isEmpty) {
      return null;
    }

    await _storage.saveAccessToken(newAccessToken);
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(newRefreshToken);
    }
    return newAccessToken;
  }

  Future<void> _retryRequest(
    DioException err,
    ErrorInterceptorHandler handler,
    String accessToken,
  ) async {
    final originalRequest = err.requestOptions;
    originalRequest.headers['Authorization'] = 'Bearer $accessToken';
    final tenantId = await _storage.getTenantId();
    if (tenantId != null && tenantId.isNotEmpty) {
      originalRequest.headers['X-Tenant-Id'] = tenantId;
    } else {
      originalRequest.headers.remove('X-Tenant-Id');
    }

    final retryResponse = await Dio(
      BaseOptions(baseUrl: originalRequest.baseUrl),
    ).fetch<dynamic>(originalRequest);
    return handler.resolve(retryResponse);
  }

  Future<void> _replayPending(_PendingRequest pending) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return pending.handler.next(pending.error);
    }
    try {
      await _retryRequest(pending.error, pending.handler, accessToken);
    } catch (e, st) {
      _logger.e('AuthInterceptor: thử lại yêu cầu đang chờ thất bại', error: e, stackTrace: st);
      return pending.handler.next(pending.error);
    }
  }
}
