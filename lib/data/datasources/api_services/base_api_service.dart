import 'package:test_y_app/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String pleaseTryAgainMessage = 'Vui lòng thử lại';

bool _isAuthenticatedRequest(RequestOptions options) {
  final auth = options.headers['Authorization'];
  return auth != null && auth.toString().trim().isNotEmpty;
}

enum ApiStatusCode {
  ok(200, 'OK'),
  created(201, 'Created'),
  badRequest(400, 'Dữ liệu không hợp lệ'),
  unauthorized(401, 'Chưa đăng nhập hoặc phiên hết hạn'),
  forbidden(403, 'Bạn không có quyền thực hiện thao tác này'),
  notFound(404, 'Không tìm thấy'),
  conflict(409, 'Dữ liệu đã tồn tại'),
  internalServerError(500, 'Lỗi máy chủ');

  const ApiStatusCode(this.code, this.defaultMessage);
  final int code;
  final String defaultMessage;

  static ApiStatusCode? fromCode(int? code) {
    if (code == null) return null;
    for (final e in ApiStatusCode.values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final String? errorCode;
  final Object? errorDetails;
  final Map<String, List<String>>? errors;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.errorCode,
    this.errorDetails,
    this.errors,
    this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, {T Function(dynamic value)? decode}) {
    final rawErrors = json['errors'];
    Map<String, List<String>>? parsedErrors;
    if (rawErrors is Map<String, dynamic>) {
      parsedErrors = rawErrors.map(
        (key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e.toString()).toList()),
      );
    }

    dynamic rawData = json['data'] ?? json['doc'];
    if (rawData == null && json['docs'] is List) {
      rawData = json;
    }
    final decodedData = decode != null ? decode(rawData) : rawData as T?;

    final parts = _extractErrorParts(json['error']);
    return ApiResponse<T>(
      success: json['success'] is bool ? json['success'] as bool : true,
      data: decodedData,
      message: json['message']?.toString(),
      error: parts.message,
      errorCode: parts.code,
      errorDetails: parts.details,
      errors: parsedErrors,
    );
  }
}

class _ApiErrorParts {
  const _ApiErrorParts({this.message, this.code, this.details});
  final String? message;
  final String? code;
  final Object? details;
}

_ApiErrorParts _extractErrorParts(dynamic error) {
  if (error == null) return const _ApiErrorParts();
  if (error is Map) {
    return _ApiErrorParts(
      message: error['message']?.toString(),
      code: error['code']?.toString(),
      details: error['details'],
    );
  }
  final text = error.toString();
  return _ApiErrorParts(message: text.isEmpty ? null : text);
}

abstract class BaseApiService {
  final Dio dio = DioClient.instance;

  ApiResponse<T> _handleDioException<T>(DioException e, {required String fallbackMessage}) {
    final statusCode = e.response?.statusCode;
    final apiStatus = ApiStatusCode.fromCode(statusCode);
    final body = e.response?.data;

    String? errorMessage;
    String? errorCode;
    Object? errorDetails;
    if (body is Map<String, dynamic>) {
      final parts = _extractErrorParts(body['error']);
      errorMessage = body['message']?.toString() ?? parts.message;
      errorCode = parts.code;
      errorDetails = parts.details;
    }

    if (statusCode == 401 && _isAuthenticatedRequest(e.requestOptions)) {
      errorMessage = pleaseTryAgainMessage;
      errorCode = null;
      errorDetails = null;
    }

    if (errorMessage == null || errorMessage.isEmpty) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage =
              'Không kết nối được máy chủ (timeout). Kiểm tra backend đang chạy.';
        case DioExceptionType.connectionError:
          errorMessage =
              'Không kết nối được máy chủ. Hãy chạy backend tại ${e.requestOptions.uri.host}:${e.requestOptions.uri.port}.';
        case DioExceptionType.badCertificate:
          errorMessage = 'Chứng chỉ SSL không hợp lệ.';
        case DioExceptionType.cancel:
          errorMessage = 'Yêu cầu đã bị hủy.';
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
        default:
          break;
      }
    }

    final displayMessage = errorMessage?.isNotEmpty == true
        ? errorMessage!
        : (apiStatus?.defaultMessage ?? fallbackMessage);

    debugPrint(
      'API error ${e.requestOptions.method} ${e.requestOptions.uri} '
      'type=${e.type} status=$statusCode msg=$displayMessage',
    );

    return ApiResponse<T>(
      success: false,
      error: displayMessage,
      errorCode: errorCode,
      errorDetails: errorDetails,
      statusCode: statusCode,
    );
  }

  Future<ApiResponse<T>> getRequest<T>(
    String path, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (GET)');
    } catch (e, stack) {
      debugPrint('BaseApiService GET error: $e\n$stack');
      return ApiResponse<T>(success: false, error: 'Lỗi hệ thống: $e');
    }
  }

  Future<ApiResponse<T>> postRequest<T>(
    String path, {
    Map<String, dynamic>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (POST)');
    }
  }

  Future<ApiResponse<T>> postMultipartRequest<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? headers,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        path,
        data: formData,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(
        e,
        fallbackMessage: 'Lỗi khi gọi API (POST multipart)',
      );
    }
  }

  Future<ApiResponse<T>> putRequest<T>(
    String path, {
    Map<String, dynamic>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (PUT)');
    }
  }

  Future<ApiResponse<T>> putMultipartRequest<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? headers,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        path,
        data: formData,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (PUT multipart)');
    }
  }

  Future<ApiResponse<T>> patchRequest<T>(
    String path, {
    Map<String, dynamic>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.patch<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (PATCH)');
    }
  }

  Future<ApiResponse<T>> deleteRequest<T>(
    String path, {
    Map<String, dynamic>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic value)? decode,
  }) async {
    try {
      final response = await dio.delete<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: headers == null ? null : Options(headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiResponse<T>.fromJson(data, decode: decode);
      }
      if (decode != null) {
        return ApiResponse<T>(success: true, data: decode(data));
      }
      return ApiResponse<T>(success: true, data: data as T?);
    } on DioException catch (e) {
      return _handleDioException<T>(e, fallbackMessage: 'Lỗi khi gọi API (DELETE)');
    }
  }
}
