import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:test_y_app/core/constants/env_config.dart';

/// Obtains a Firebase ID token via Google Sign-In for backend `/auth/login/google`.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn, FirebaseAuth? firebaseAuth})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
      _firebaseAuthOverride = firebaseAuth;

  final GoogleSignIn _googleSignIn;
  final FirebaseAuth? _firebaseAuthOverride;

  static Future<void>? _initFuture;

  /// Lazily resolves [FirebaseAuth] so constructing this service does not
  /// require Firebase to already be initialized (avoids build-time crashes).
  FirebaseAuth get _firebaseAuth {
    final override = _firebaseAuthOverride;
    if (override != null) return override;
    if (Firebase.apps.isEmpty) {
      throw const GoogleAuthException(
        'Firebase chưa được khởi tạo. Thêm GoogleService-Info.plist / '
        'google-services.json và chạy flutterfire configure.',
      );
    }
    return FirebaseAuth.instance;
  }

  Future<void> _ensureInitialized() {
    final serverClientId = EnvConfig.googleServerClientId;
    if (serverClientId.isEmpty) {
      throw const GoogleAuthException(
        'Thiếu GOOGLE_SERVER_CLIENT_ID trong .env.',
      );
    }
    return _initFuture ??= _googleSignIn.initialize(
      // Web client ID from Firebase Google provider (serverClientId).
      serverClientId: serverClientId,
    );
  }

  /// Signs in with Google, exchanges credentials with Firebase Auth, and
  /// returns the Firebase ID token. Returns `null` if the user cancels.
  Future<String?> signInAndGetIdToken() async {
    try {
      await _ensureInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw const GoogleAuthException(
          'Đăng nhập Google chưa được hỗ trợ trên nền tảng này.',
        );
      }

      final account = await _googleSignIn.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const GoogleAuthException(
          'Không lấy được Google ID token. Kiểm tra cấu hình Firebase/Google Sign-In.',
        );
      }

      String? accessToken;
      try {
        final authorization = await account.authorizationClient
            .authorizationForScopes(const <String>['email', 'profile']);
        accessToken = authorization?.accessToken;
      } catch (e, st) {
        debugPrint('Google accessToken optional failed: $e\n$st');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleIdToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const GoogleAuthException(
          'Không lấy được Firebase ID token. Vui lòng thử lại.',
        );
      }
      return firebaseIdToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw GoogleAuthException(_mapGoogleSignInError(e));
    } on FirebaseAuthException catch (e) {
      throw GoogleAuthException(_mapFirebaseAuthError(e));
    } on PlatformException catch (e) {
      debugPrint('GoogleAuthService PlatformException: $e');
      if ((e.message ?? '').contains('GIDClientID') ||
          (e.message ?? '').contains('No active configuration')) {
        throw const GoogleAuthException(
          'Google Sign-In chưa cấu hình CLIENT_ID. '
          'Thêm GIDClientID + URL scheme vào Info.plist '
          '(lấy từ GoogleService-Info.plist).',
        );
      }
      throw GoogleAuthException(
        e.message ??
            'Đăng nhập Google thất bại. Kiểm tra cấu hình Firebase hoặc thử lại sau.',
      );
    } on GoogleAuthException {
      rethrow;
    } catch (e) {
      debugPrint('GoogleAuthService unexpected error: $e');
      final message = e.toString();
      if (message.contains('GIDClientID') ||
          message.contains('No active configuration')) {
        throw const GoogleAuthException(
          'Google Sign-In chưa cấu hình CLIENT_ID. '
          'Thêm GIDClientID + URL scheme vào Info.plist '
          '(lấy từ GoogleService-Info.plist).',
        );
      }
      throw const GoogleAuthException(
        'Đăng nhập Google thất bại. Kiểm tra cấu hình Firebase hoặc thử lại sau.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      if (Firebase.apps.isEmpty && _firebaseAuthOverride == null) return;
      await Future.wait<void>([
        _googleSignIn.signOut(),
        _firebaseAuth.signOut(),
      ]);
    } catch (e, st) {
      debugPrint('GoogleAuthService.signOut failed: $e\n$st');
    }
  }

  String _mapGoogleSignInError(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Sign-In chưa được cấu hình đúng trên thiết bị này.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Không thể hiển thị đăng nhập Google lúc này. Vui lòng thử lại.',
      _ => 'Đăng nhập Google thất bại. Vui lòng thử lại.',
    };
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'network-request-failed' =>
        'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
      'account-exists-with-different-credential' =>
        'Tài khoản đã tồn tại với phương thức đăng nhập khác.',
      'invalid-credential' || 'user-disabled' =>
        'Thông tin Google không hợp lệ hoặc tài khoản bị vô hiệu.',
      _ =>
        'Đăng nhập Firebase thất bại. Kiểm tra cấu hình Firebase và thử lại.',
    };
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
