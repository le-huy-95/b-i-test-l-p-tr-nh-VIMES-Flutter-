import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/network/dio_client.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/notification/notification_item.dart';

class NotificationApiService {
  final Dio _dio = DioClient.instance;

  String get _base => EnvConfig.notificationApiUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await StorageManager().getAccessToken();
    final tenantId = await StorageManager().getTenantId();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-Id': tenantId,
    };
  }

  List<NotificationItem> _decodeItems(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is Map<String, dynamic>) {
          return NotificationItem.fromJson(item);
        }
        return NotificationItem.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    }
    if (value is Map && value['items'] is List) {
      return _decodeItems(value['items']);
    }
    return const [];
  }

  String _errorMessage(ApiResponse<dynamic> response, String fallback) {
    final err = response.error;
    if (err != null && err.isNotEmpty && !err.startsWith('{')) {
      return err;
    }
    return response.message?.isNotEmpty == true ? response.message! : fallback;
  }

  Never _throwFailed(ApiResponse<dynamic> response, String fallback) {
    throw Exception(_errorMessage(response, fallback));
  }

  ApiResponse<T> _handleError<T>(DioException e, String fallback) {
    final statusCode = e.response?.statusCode;
    final apiStatus = ApiStatusCode.fromCode(statusCode);
    String? errorMessage;

    if (statusCode == 401) {
      errorMessage = pleaseTryAgainMessage;
    } else {
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        final rawError = body['error'];
        if (rawError is Map) {
          errorMessage = rawError['message']?.toString();
        } else {
          errorMessage = body['message']?.toString() ?? rawError?.toString();
        }
      }
    }

    errorMessage ??= switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Không kết nối được máy chủ (timeout).',
      DioExceptionType.connectionError =>
        'Không kết nối được notification server.',
      _ => apiStatus?.defaultMessage ?? fallback,
    };

    debugPrint(
      'NotificationApi error ${e.requestOptions.method} ${e.requestOptions.uri} '
      'type=${e.type} status=$statusCode msg=$errorMessage',
    );
    return ApiResponse<T>(success: false, error: errorMessage, statusCode: statusCode);
  }

  Future<NotificationListResult> list({
    String? cursor,
    int limit = 20,
    bool onlyUnread = false,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.get<dynamic>(
        '$_base/notifications',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          if (onlyUnread) 'onlyUnread': true,
        },
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return NotificationListResult(items: const []);
      }
      final items = _decodeItems(data['data'] ?? data);
      final nextCursor = data['data'] is Map
          ? (data['data']['nextCursor'] as String?)
          : (data['nextCursor'] as String?);
      return NotificationListResult(items: items, nextCursor: nextCursor);
    } on DioException catch (e) {
      final res = _handleError<NotificationListResult>(e, 'Không tải được danh sách thông báo');
      _throwFailed(res, 'Không tải được danh sách thông báo');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.get<dynamic>(
        '$_base/notifications/unread-count',
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final countData = data['data'] ?? data;
        if (countData is Map<String, dynamic>) {
          return (countData['count'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } on DioException catch (e) {
      final res = _handleError<int>(e, 'Không lấy được số thông báo chưa đọc');
      _throwFailed(res, 'Không lấy được số thông báo chưa đọc');
    }
  }

  Future<MarkReadResult> markRead({
    List<String>? notificationIds,
    bool markAll = false,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.post<dynamic>(
        '$_base/notifications/mark-read',
        data: {
          if (!markAll && notificationIds != null)
            'notificationIds': notificationIds,
          'markAll': markAll,
        },
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final resultData = data['data'] ?? data;
        if (resultData is Map<String, dynamic>) {
          return MarkReadResult(
            updated: (resultData['updated'] as num?)?.toInt() ?? 0,
            unreadCount: (resultData['unreadCount'] as num?)?.toInt() ?? 0,
          );
        }
      }
      return const MarkReadResult(updated: 0, unreadCount: 0);
    } on DioException catch (e) {
      final res = _handleError<MarkReadResult>(e, 'Đánh dấu đã đọc thất bại');
      _throwFailed(res, 'Đánh dấu đã đọc thất bại');
    }
  }
}
