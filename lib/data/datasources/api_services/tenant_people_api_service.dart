import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:test_y_app/core/network/dio_client.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/tenant/tenant_invitation.dart';
import 'package:test_y_app/data/models/tenant/tenant_member.dart';

class TenantPeopleApiService {
  final Dio _dio = DioClient.instance;

  Future<Map<String, String>> _authHeaders({bool includeTenant = true}) async {
    final token = await StorageManager().getAccessToken();
    final tenantId = includeTenant ? await StorageManager().getTenantId() : null;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-Id': tenantId,
    };
  }

  ApiResponse<T> _handleError<T>(DioException e, String fallback) {
    final statusCode = e.response?.statusCode;
    final apiStatus = ApiStatusCode.fromCode(statusCode);
    String? errorMessage;
    String? errorCode;

    if (statusCode == 401) {
      errorMessage = pleaseTryAgainMessage;
    } else {
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        final rawError = body['error'];
        if (rawError is Map) {
          errorMessage = rawError['message']?.toString();
          errorCode = rawError['code']?.toString();
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
        'Không kết nối được máy chủ thành viên.',
      _ => apiStatus?.defaultMessage ?? fallback,
    };

    debugPrint(
      'TenantPeopleApi error ${e.requestOptions.method} ${e.requestOptions.uri} '
      'type=${e.type} status=$statusCode msg=$errorMessage',
    );
    return ApiResponse<T>(
      success: false,
      error: errorMessage,
      errorCode: errorCode,
      statusCode: statusCode,
    );
  }

  ({List<T> items, int total, int totalPages, int page, int limit}) _extractListEnvelope<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
    {required int page,
    required int limit,
  }) {
    final envelope = body is Map<String, dynamic>
        ? body['data']
        : body is Map
            ? Map<String, dynamic>.from(body)['data']
            : body;

    if (envelope is List) {
      final items = envelope
          .whereType<Map>()
          .map((item) => fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return (
        items: items,
        total: items.length,
        totalPages: 1,
        page: page,
        limit: limit,
      );
    }

    final map = envelope is Map<String, dynamic>
        ? envelope
        : envelope is Map
            ? Map<String, dynamic>.from(envelope)
            : <String, dynamic>{};
    final data = map['data'];
    final items = <T>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          items.add(fromJson(item));
        } else if (item is Map) {
          items.add(fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final pagination = map['pagination'];
    final paginationMap = pagination is Map<String, dynamic>
        ? pagination
        : pagination is Map
            ? Map<String, dynamic>.from(pagination)
            : const <String, dynamic>{};
    return (
      items: items,
      page: (paginationMap['page'] as num?)?.toInt() ?? page,
      limit: (paginationMap['limit'] as num?)?.toInt() ?? limit,
      total: (paginationMap['total'] as num?)?.toInt() ?? items.length,
      totalPages: (paginationMap['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<TenantMemberPageResult> fetchMembers({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.get<dynamic>(
        ApiEndpoints.tenantsCurrentMembers,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
        options: Options(headers: headers),
      );
      final extracted = _extractListEnvelope(
        response.data,
        TenantMember.fromJson,
        page: page,
        limit: limit,
      );
      return TenantMemberPageResult(
        items: extracted.items,
        page: extracted.page,
        limit: extracted.limit,
        total: extracted.total,
        totalPages: extracted.totalPages,
      );
    } on DioException catch (e) {
      final res = _handleError<TenantMemberPageResult>(
        e,
        'Không tải được danh sách thành viên',
      );
      throw Exception(res.error ?? 'Không tải được danh sách thành viên');
    }
  }

  Future<TenantInvitationPageResult> fetchInvitations({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.get<dynamic>(
        ApiEndpoints.tenantsCurrentInvitations,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
        options: Options(headers: headers),
      );
      final extracted = _extractListEnvelope(
        response.data,
        TenantInvitation.fromJson,
        page: page,
        limit: limit,
      );
      return TenantInvitationPageResult(
        items: extracted.items,
        page: extracted.page,
        limit: extracted.limit,
        total: extracted.total,
        totalPages: extracted.totalPages,
      );
    } on DioException catch (e) {
      final res = _handleError<TenantInvitationPageResult>(
        e,
        'Không tải được danh sách lời mời',
      );
      throw Exception(res.error ?? 'Không tải được danh sách lời mời');
    }
  }

  Future<CreateInvitationResult> createInvitation({
    required String email,
    String role = 'viewer',
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.post<dynamic>(
        ApiEndpoints.tenantsCurrentInvitations,
        data: {'email': email, 'role': role},
        options: Options(headers: headers),
      );
      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? data['data'] ?? data
          : data is Map
              ? Map<String, dynamic>.from(data)['data'] ?? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
      if (payload is Map<String, dynamic>) {
        return CreateInvitationResult.fromJson(payload);
      }
      return CreateInvitationResult.fromJson(Map<String, dynamic>.from(payload as Map));
    } on DioException catch (e) {
      final res = _handleError<CreateInvitationResult>(
        e,
        'Không tạo được lời mời',
      );
      throw Exception(res.error ?? 'Không tạo được lời mời');
    }
  }

  Future<AcceptInvitationResult> acceptInvitation({required String invitationId}) async {
    try {
      final headers = await _authHeaders(includeTenant: false);
      final response = await _dio.post<dynamic>(
        ApiEndpoints.authInvitationsAccept,
        data: {'invitationId': invitationId},
        options: Options(headers: headers),
      );
      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? data['data'] ?? data
          : data is Map
              ? Map<String, dynamic>.from(data)['data'] ?? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
      if (payload is Map<String, dynamic>) {
        return AcceptInvitationResult.fromJson(payload);
      }
      return AcceptInvitationResult.fromJson(Map<String, dynamic>.from(payload as Map));
    } on DioException catch (e) {
      final res = _handleError<AcceptInvitationResult>(
        e,
        'Không chấp nhận được lời mời',
      );
      throw Exception(res.error ?? 'Không chấp nhận được lời mời');
    }
  }

  Future<DeclineInvitationResult> declineInvitation({required String invitationId}) async {
    try {
      final headers = await _authHeaders(includeTenant: false);
      final response = await _dio.post<dynamic>(
        ApiEndpoints.authInvitationsDecline,
        data: {'invitationId': invitationId},
        options: Options(headers: headers),
      );
      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? data['data'] ?? data
          : data is Map
              ? Map<String, dynamic>.from(data)['data'] ?? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
      if (payload is Map<String, dynamic>) {
        return DeclineInvitationResult.fromJson(payload);
      }
      return DeclineInvitationResult.fromJson(Map<String, dynamic>.from(payload as Map));
    } on DioException catch (e) {
      final res = _handleError<DeclineInvitationResult>(
        e,
        'Không từ chối được lời mời',
      );
      throw Exception(res.error ?? 'Không từ chối được lời mời');
    }
  }

  Future<CreateTenantUserResult> createTenantUser({
    String? email,
    String? phone,
    String? name,
    required String password,
    String role = 'warehouse_keeper',
    List<String>? warehouseIds,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{
        'password': password,
        'role': role,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (warehouseIds != null && warehouseIds.isNotEmpty) 'warehouseIds': warehouseIds,
      };
      final response = await _dio.post<dynamic>(
        ApiEndpoints.tenantsCurrentUsers,
        data: body,
        options: Options(headers: headers),
      );
      final data = response.data;
      final payload = data is Map<String, dynamic>
          ? data['data'] ?? data
          : data is Map
              ? Map<String, dynamic>.from(data)['data'] ?? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
      if (payload is Map<String, dynamic>) {
        return CreateTenantUserResult.fromJson(payload);
      }
      return CreateTenantUserResult.fromJson(Map<String, dynamic>.from(payload as Map));
    } on DioException catch (e) {
      final res = _handleError<CreateTenantUserResult>(
        e,
        'Không tạo được user nội bộ',
      );
      throw Exception(res.error ?? 'Không tạo được user nội bộ');
    }
  }
}
