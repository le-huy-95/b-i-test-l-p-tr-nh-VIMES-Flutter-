import 'package:dio/dio.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/data/models/auth/forgot_password_result.dart';
import 'package:test_y_app/data/models/auth/me_result.dart';
import 'package:test_y_app/data/models/auth/refresh_tokens_result.dart';
import 'package:test_y_app/data/models/auth/register_result.dart';
import 'package:test_y_app/data/models/post/post.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';

class AuthApiService extends BaseApiService {
  AuthApiService({StorageManager? storageManager})
      : _storageManager = storageManager ?? StorageManager();

  final StorageManager _storageManager;

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

  String _mapAuthErrorCode(ApiResponse<dynamic> response, String fallback) {
    switch (response.errorCode) {
      case 'INVALID_OTP':
        return 'Mã OTP không đúng hoặc đã hết hạn';
      case 'USER_INACTIVE':
        return 'Tài khoản đã bị khóa';
      case 'RATE_LIMITED':
        return 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.';
      default:
        return _errorMessage(response, fallback);
    }
  }

  Future<void> _saveSessionTokens(AuthSession session) async {
    if (session.accessToken.isNotEmpty) {
      await _storageManager.saveAccessToken(session.accessToken);
    }
    if (session.refreshToken.isNotEmpty) {
      await _storageManager.saveRefreshToken(session.refreshToken);
    }
  }

  Future<AuthSession> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await postRequest<AuthSession>(
      ApiEndpoints.authLogin,
      body: body,
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return AuthSession.fromJson(value);
        }
        return AuthSession.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Đăng nhập thất bại');
    }

    final session = response.data!;
    await _saveSessionTokens(session);
    return session;
  }

  Future<AuthSession> loginWithGoogle(String idToken) async {
    final response = await postRequest<AuthSession>(
      ApiEndpoints.authLoginGoogle,
      body: {'idToken': idToken},
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return AuthSession.fromJson(value);
        }
        return AuthSession.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Đăng nhập Google thất bại');
    }

    final session = response.data!;
    await _saveSessionTokens(session);
    return session;
  }

  Future<RegisterResult> register({
    String? email,
    String? phone,
    required String password,
    String? name,
  }) async {
    final body = <String, dynamic>{
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (name != null && name.isNotEmpty) 'name': name,
    };

    final response = await postRequest<RegisterResult>(
      ApiEndpoints.authRegister,
      body: body,
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return RegisterResult.fromJson(value);
        }
        return RegisterResult.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Đăng ký thất bại');
    }

    return response.data!;
  }

  Future<void> verifyOtp({
    String? email,
    String? phone,
    required String code,
  }) async {
    final body = <String, dynamic>{
      'code': code,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await postRequest<Map<String, dynamic>>(
      ApiEndpoints.authVerifyOtp,
      body: body,
      decode: (value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      },
    );

    if (!response.success) {
      _throwFailed(response, 'Xác thực OTP thất bại');
    }
  }

  Future<DateTime?> resendOtp({String? email, String? phone}) async {
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await postRequest<Map<String, dynamic>>(
      ApiEndpoints.authResendOtp,
      body: body,
      decode: (value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      },
    );

    if (!response.success) {
      _throwFailed(response, 'Gửi lại OTP thất bại');
    }

    final data = response.data;
    final raw = data?['nextResendAt'] ?? data?['resendAvailableAt'] ?? data?['cooldownUntil'];
    if (raw == null) return null;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return DateTime.tryParse(raw.toString());
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final response = await postRequest<ForgotPasswordResult>(
      ApiEndpoints.authForgotPassword,
      body: {'email': email},
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return ForgotPasswordResult.fromJson(value);
        }
        return ForgotPasswordResult.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      },
    );

    if (!response.success || response.data == null) {
      throw Exception(
        _mapAuthErrorCode(response, 'Gửi mã OTP thất bại'),
      );
    }

    return response.data!;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await postRequest<Map<String, dynamic>>(
      ApiEndpoints.authResetPassword,
      body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
      decode: (value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      },
    );

    if (!response.success) {
      throw Exception(
        _mapAuthErrorCode(response, 'Đặt lại mật khẩu thất bại'),
      );
    }
  }

  Future<MeResult> getMe() async {
    final response = await getRequest<MeResult>(
      ApiEndpoints.authMe,
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return MeResult.fromJson(value);
        }
        return MeResult.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không lấy được thông tin người dùng');
    }

    final me = response.data!;
    await _storageManager.saveUserInfo(me.user.toJson());
    return me;
  }

  Future<TenantMembership> createTenant({
    required String code,
    required String name,
  }) async {
    final response = await postRequest<TenantMembership>(
      ApiEndpoints.authTenants,
      body: {'code': code, 'name': name},
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return TenantMembership.fromJson(value);
        }
        return TenantMembership.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Tạo tổ chức thất bại');
    }

    return response.data!;
  }

  Future<TenantMembership> uploadTenantLogo({required String filePath}) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'logo': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await postMultipartRequest<TenantMembership>(
      ApiEndpoints.tenantsCurrentLogo,
      formData: formData,
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return TenantMembership.fromJson(value);
        }
        return TenantMembership.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Upload logo thất bại');
    }

    return response.data!;
  }

  Future<void> registerDevice({
    required String deviceId,
    required String deviceType,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    String? fcmToken,
  }) async {
    final body = <String, dynamic>{
      'deviceId': deviceId,
      'deviceType': deviceType,
    };

    if (deviceModel != null) body['deviceModel'] = deviceModel;
    if (osVersion != null) body['osVersion'] = osVersion;
    if (appVersion != null) body['appVersion'] = appVersion;
    if (fcmToken != null) body['fcmToken'] = fcmToken;

    final response = await postRequest<void>(
      ApiEndpoints.authRegisterDevice,
      body: body,
    );

    if (!response.success) {
      _throwFailed(response, 'Đăng ký thiết bị thất bại');
    }
  }

  Future<void> logout({required String refreshToken, String? deviceId}) async {
    final body = <String, dynamic>{
      'refreshToken': refreshToken,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    };

    final response = await postRequest<void>(
      ApiEndpoints.authLogout,
      body: body,
    );

    if (!response.success) {
      _throwFailed(response, 'Đăng xuất thất bại');
    }
  }

  Future<RefreshTokensResult> refreshTokens({required String refreshToken}) async {
    final response = await postRequest<RefreshTokensResult>(
      ApiEndpoints.authRefresh,
      body: {'refreshToken': refreshToken},
      decode: (value) {
        if (value is Map<String, dynamic>) {
          return RefreshTokensResult.fromJson(value);
        }
        return RefreshTokensResult.fromJson(Map<String, dynamic>.from(value as Map));
      },
    );

    if (!response.success || response.data == null) {
      _throwFailed(response, 'Làm mới token thất bại');
    }

    final tokens = response.data!;
    if (tokens.accessToken.isNotEmpty) {
      await _storageManager.saveAccessToken(tokens.accessToken);
    }
    if (tokens.refreshToken.isNotEmpty) {
      await _storageManager.saveRefreshToken(tokens.refreshToken);
    }
    return tokens;
  }
}

class DemoApiService extends BaseApiService {
  Future<List<Post>> getPosts({int limit = 10}) async {
    final response = await getRequest<List<Post>>(
      ApiEndpoints.demoPosts,
      queryParameters: {'_limit': limit},
      decode: (value) {
        if (value is! List) return <Post>[];
        return value
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson)
            .toList();
      },
    );

    if (!response.success || response.data == null) {
      throw Exception(response.error ?? 'Không thể tải dữ liệu');
    }

    return response.data!;
  }
}
