import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userInfoKey = 'user_info';
  static const String _tenantIdKey = 'tenant_id';
  static const String _tenantMembershipsKey = 'tenant_memberships';
  static const String _deviceIdKey = 'device_id';
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedCredentialsKey = 'remembered_credentials';

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await _storage.write(key: _userInfoKey, value: jsonEncode(userInfo));
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final jsonString = await _storage.read(key: _userInfoKey);
    if (jsonString == null || jsonString.isEmpty) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Future<void> deleteUserInfo() async {
    await _storage.delete(key: _userInfoKey);
  }

  Future<void> saveString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getString(String key) async {
    return _storage.read(key: key);
  }

  Future<void> saveJson(String key, dynamic jsonData) async {
    await _storage.write(key: key, value: jsonEncode(jsonData));
  }

  Future<dynamic> getJson(String key) async {
    final jsonString = await _storage.read(key: key);
    if (jsonString == null || jsonString.isEmpty) return null;
    return jsonDecode(jsonString);
  }

  Future<void> saveTokenExpiration(int exp) async {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    await saveString('token_expires_at', expiresAt.toIso8601String());
  }

  Future<void> saveTenantId(String id) async {
    await _storage.write(key: _tenantIdKey, value: id);
  }

  Future<String?> getTenantId() async {
    return _storage.read(key: _tenantIdKey);
  }

  Future<void> deleteTenantId() async {
    await _storage.delete(key: _tenantIdKey);
  }

  Future<void> saveTenantMemberships(List<Map<String, dynamic>> tenants) async {
    await saveJson(_tenantMembershipsKey, tenants);
  }

  Future<List<Map<String, dynamic>>> getTenantMemberships() async {
    final raw = await getJson(_tenantMembershipsKey);
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> deleteTenantMemberships() async {
    await _storage.delete(key: _tenantMembershipsKey);
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<void> saveRememberedCredentials({
    required String credentials,
    required String password,
  }) async {
    await _storage.write(key: _rememberMeKey, value: 'true');
    await _storage.write(
      key: _rememberedCredentialsKey,
      value: jsonEncode({
        'credentials': credentials,
        'password': password,
      }),
    );
  }

  Future<({String credentials, String password})?> getRememberedCredentials() async {
    final raw = await _storage.read(key: _rememberedCredentialsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final credentials = data['credentials'] as String?;
      final password = data['password'] as String?;
      if (credentials == null || password == null) return null;
      return (credentials: credentials, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isRememberMeEnabled() async {
    final raw = await _storage.read(key: _rememberMeKey);
    return raw == 'true';
  }

  Future<void> clearRememberedCredentials() async {
    await Future.wait([
      _storage.delete(key: _rememberMeKey),
      _storage.delete(key: _rememberedCredentialsKey),
    ]);
  }

  Future<void> clearAuthData() async {
    await Future.wait([
      deleteAccessToken(),
      deleteRefreshToken(),
      deleteUserInfo(),
      deleteTenantId(),
      deleteTenantMemberships(),
      _storage.delete(key: 'token_expires_at'),
    ]);
  }

  Future<bool> isLoggedIn() async {
    final hasToken = await hasAccessToken();
    final userInfo = await getUserInfo();
    return hasToken && userInfo != null && userInfo.isNotEmpty;
  }
}
