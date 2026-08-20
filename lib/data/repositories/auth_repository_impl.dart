import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:test_y_app/core/assets/default_tenant_logo.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/data/datasources/api_services/auth_api_service.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/data/models/auth/forgot_password_result.dart';
import 'package:test_y_app/data/models/auth/me_result.dart';
import 'package:test_y_app/data/models/auth/register_result.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/domain/repositories/create_tenant_with_logo_result.dart';
import 'package:test_y_app/features/auth/utils/credentials.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    AuthApiService? apiService,
    StorageManager? storageManager,
  }) : _apiService = apiService ?? AuthApiService(),
       _storageManager = storageManager ?? StorageManager();

  final AuthApiService _apiService;
  final StorageManager _storageManager;

  Future<void> _persistSession(AuthSession session) async {
    await _storageManager.saveUserInfo(session.user.toJson());
    await _persistTenants(session.tenants);
    // Tokens already saved by AuthApiService on login/google/refresh.
  }

  Future<void> _persistTenants(List<TenantMembership> tenants) async {
    await _storageManager.saveTenantMemberships(
      tenants.map((tenant) => tenant.toJson()).toList(),
    );
  }

  Future<List<TenantMembership>> _resolveTenants(
    List<TenantMembership> remote,
  ) async {
    if (remote.isNotEmpty) {
      await _persistTenants(remote);
      return remote;
    }

    final cached = await _storageManager.getTenantMemberships();
    return cached
        .map(TenantMembership.fromJson)
        .where((tenant) => tenant.id.isNotEmpty)
        .toList();
  }

  Future<void> _registerDeviceBestEffort() async {
    try {
      await registerDevice();
    } catch (e, st) {
      debugPrint('registerDevice best-effort failed: $e\n$st');
    }
  }

  @override
  Future<AuthSession> login({
    required String credentials,
    required String password,
  }) async {
    final parts = splitCredentials(credentials);
    final session = await _apiService.login(
      email: parts.email,
      phone: parts.phone,
      password: password,
    );
    await _persistSession(session);
    await _registerDeviceBestEffort();
    return session;
  }

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final session = await _apiService.loginWithGoogle(idToken);
    await _persistSession(session);
    await _registerDeviceBestEffort();
    return session;
  }

  @override
  Future<RegisterResult> register({
    String? email,
    String? phone,
    required String password,
    String? name,
  }) {
    return _apiService.register(
      email: email,
      phone: phone,
      password: password,
      name: name,
    );
  }

  @override
  Future<void> verifyOtp({String? email, String? phone, required String code}) {
    return _apiService.verifyOtp(email: email, phone: phone, code: code);
  }

  @override
  Future<DateTime?> resendOtp({String? email, String? phone}) {
    return _apiService.resendOtp(email: email, phone: phone);
  }

  @override
  Future<ForgotPasswordResult> forgotPassword({required String email}) {
    return _apiService.forgotPassword(email: email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _apiService.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  @override
  Future<MeResult?> getMe() async {
    try {
      final me = await _apiService.getMe();
      final tenants = await _resolveTenants(me.tenants);
      return MeResult(user: me.user, tenants: tenants);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TenantMembership> createTenant({
    required String code,
    required String name,
  }) {
    return _apiService.createTenant(code: code, name: name);
  }

  @override
  Future<List<TenantMembership>> fetchMyTenants() async {
    final me = await _apiService.getMe();
    return me.tenants;
  }

  @override
  Future<CreateTenantWithLogoResult> createTenantWithLogo({
    required String code,
    required String name,
    String? logoFilePath,
  }) async {
    final created = await createTenant(code: code, name: name);
    await selectTenant(created.id);

    final resolvedPath =
        logoFilePath ?? await resolveDefaultTenantLogoPath();

    try {
      final uploaded = await _apiService.uploadTenantLogo(
        filePath: resolvedPath,
      );
      return CreateTenantWithLogoResult(tenant: uploaded);
    } catch (e) {
      debugPrint('Upload tenant logo failed: $e');
      return CreateTenantWithLogoResult(
        tenant: created,
        logoUploadWarning:
            'Tạo tổ chức thành công nhưng chưa upload được logo',
      );
    }
  }

  @override
  Future<void> registerDevice() async {
    final deviceId = await _storageManager.getOrCreateDeviceId();
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceType = 'unknown';
    String? deviceModel;
    String? osVersion;

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        deviceType = 'android';
        final android = await deviceInfo.androidInfo;
        deviceModel = android.model;
        osVersion =
            'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        final ios = await deviceInfo.iosInfo;
        deviceModel = ios.utsname.machine;
        osVersion = 'iOS ${ios.systemVersion}';
      } else if (Platform.isMacOS) {
        deviceType = 'macos';
        final mac = await deviceInfo.macOsInfo;
        deviceModel = mac.model;
        osVersion = 'macOS ${mac.osRelease}';
      } else if (Platform.isWindows) {
        deviceType = 'windows';
        final windows = await deviceInfo.windowsInfo;
        deviceModel = windows.computerName;
        osVersion = 'Windows ${windows.displayVersion}';
      } else if (Platform.isLinux) {
        deviceType = 'linux';
        final linux = await deviceInfo.linuxInfo;
        deviceModel = linux.prettyName;
        osVersion = linux.versionId ?? linux.version;
      }
    } else {
      deviceType = 'web';
      final web = await deviceInfo.webBrowserInfo;
      deviceModel = web.browserName.name;
      osVersion = web.appVersion;
    }

    String? fcmToken;
    try {
      if (!kIsWeb && Platform.isIOS) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null) {
          debugPrint(
            'FCM token skipped: APNS token not ready yet (common on simulator)',
          );
        } else {
          fcmToken = await FirebaseMessaging.instance.getToken();
        }
      } else {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }
    } catch (e, st) {
      debugPrint('FCM token optional failed: $e\n$st');
    }

    await _apiService.registerDevice(
      deviceId: deviceId,
      deviceType: deviceType,
      deviceModel: deviceModel,
      osVersion: osVersion,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      fcmToken: fcmToken,
    );
  }

  @override
  Future<User?> getCurrentUser() async {
    final cached = await _storageManager.getUserInfo();
    if (cached != null) {
      return User.fromJson(cached);
    }
    final me = await getMe();
    return me?.user;
  }

  @override
  Future<bool> isLoggedIn() => _storageManager.isLoggedIn();

  @override
  Future<void> logout({bool forceLocalOnly = false}) async {
    if (!forceLocalOnly) {
      try {
        final refreshToken = await _storageManager.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final deviceId = await _storageManager.getOrCreateDeviceId();
          await _apiService.logout(
            refreshToken: refreshToken,
            deviceId: deviceId,
          );
        }
      } catch (_) {
        // Fallback to local clear below.
      }
    }
    await _storageManager.clearAuthData();
  }

  @override
  Future<void> selectTenant(String tenantId) {
    return _storageManager.saveTenantId(tenantId);
  }

  @override
  Future<String?> getSelectedTenantId() => _storageManager.getTenantId();
}
