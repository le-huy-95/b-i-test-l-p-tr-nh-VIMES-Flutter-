import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/data/models/auth/forgot_password_result.dart';
import 'package:test_y_app/data/models/auth/me_result.dart';
import 'package:test_y_app/data/models/auth/register_result.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';
import 'package:test_y_app/domain/repositories/create_tenant_with_logo_result.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String credentials,
    required String password,
  });

  Future<AuthSession> loginWithGoogle({required String idToken});

  Future<RegisterResult> register({
    String? email,
    String? phone,
    required String password,
    String? name,
  });

  Future<void> verifyOtp({
    String? email,
    String? phone,
    required String code,
  });

  Future<DateTime?> resendOtp({String? email, String? phone});

  Future<ForgotPasswordResult> forgotPassword({required String email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<MeResult?> getMe();

  Future<TenantMembership> createTenant({
    required String code,
    required String name,
  });

  Future<List<TenantMembership>> fetchMyTenants();

  Future<CreateTenantWithLogoResult> createTenantWithLogo({
    required String code,
    required String name,
    String? logoFilePath,
  });

  Future<void> registerDevice();

  Future<User?> getCurrentUser();

  Future<bool> isLoggedIn();

  Future<void> logout({bool forceLocalOnly = false});

  Future<void> selectTenant(String tenantId);

  Future<String?> getSelectedTenantId();
}
