import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/core/storage/storage_manager.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/login_bloc.dart';
import 'package:test_y_app/features/auth/bloc/login_event.dart';
import 'package:test_y_app/features/auth/bloc/login_state.dart';
import 'package:test_y_app/features/auth/services/google_auth_service.dart';
import 'package:test_y_app/features/auth/widgets/auth_primary_button.dart';
import 'package:test_y_app/features/auth/widgets/auth_text_field.dart';
import 'package:test_y_app/features/auth/widgets/vimes_logo.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.infoMessage});

  final String? infoMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _credentialsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleAuthService = GoogleAuthService();
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _shownInfo = false;
  bool _googleInProgress = false;
  bool _rememberFromCredentialsSubmit = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    final message = widget.infoMessage;
    if (message != null && message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_shownInfo && mounted) {
          _shownInfo = true;
          SimpleSnackbarService.showSuccess(message);
        }
      });
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final remembered = await StorageManager().isRememberMeEnabled();
    final saved = await StorageManager().getRememberedCredentials();
    if (!mounted) return;
    setState(() {
      _rememberMe = saved != null || remembered;
      if (saved != null) {
        _credentialsController.text = saved.credentials;
        _passwordController.text = saved.password;
      }
    });
  }

  Future<void> _persistRememberedCredentials() async {
    if (_rememberMe) {
      await StorageManager().saveRememberedCredentials(
        credentials: _credentialsController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await StorageManager().clearRememberedCredentials();
    }
  }

  @override
  void dispose() {
    _credentialsController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _rememberFromCredentialsSubmit = true;
    context.read<LoginBloc>().add(
      LoginSubmitted(
        credentials: _credentialsController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_googleInProgress) return;
    _rememberFromCredentialsSubmit = false;
    setState(() => _googleInProgress = true);
    try {
      final idToken = await _googleAuthService.signInAndGetIdToken();
      if (!mounted) return;
      if (idToken == null) {
        setState(() => _googleInProgress = false);
        return;
      }
      context.read<LoginBloc>().add(LoginGoogleRequested(idToken));
    } on GoogleAuthException catch (e) {
      if (mounted) {
        setState(() => _googleInProgress = false);
        SimpleSnackbarService.showError(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _googleInProgress = false);
        SimpleSnackbarService.showError(
          'Đăng nhập Google thất bại. Vui lòng thử lại.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSkin.white,
      body: SafeArea(
        child: BlocConsumer<LoginBloc, LoginState>(
          listener: (context, state) {
            if (state is LoginFailure) {
              if (_googleInProgress) {
                setState(() => _googleInProgress = false);
              }
              SimpleSnackbarService.showError(state.message);
            } else if (state is LoginSuccess) {
              if (_rememberFromCredentialsSubmit) {
                _persistRememberedCredentials();
              }
              // Avoid setState here: navigation disposes TextEditingControllers.
              context.read<AuthBloc>().add(
                AuthSessionEstablished(state.session),
              );
            }
          },
          buildWhen: (previous, current) => current is! LoginSuccess,
          builder: (context, state) {
            final isLoading =
                state is LoginLoading ||
                state is LoginSuccess ||
                _googleInProgress;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: GestureDetector(
                onTap: () =>
                    FocusScope.of(context, createDependency: false).unfocus(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: VimesLogo(width: 260)),
                      const SizedBox(height: 28),
                      Text(
                        'Chào mừng trở lại',
                        textAlign: TextAlign.center,
                        style: TypoSkin.title1.copyWith(color: ColorSkin.title),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng nhập để quản lý kho và tồn vật tư',
                        textAlign: TextAlign.center,
                        style: TypoSkin.bodyText2.copyWith(
                          color: ColorSkin.subtitle,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthTextField(
                        controller: _credentialsController,
                        label: 'Email / SĐT',
                        hint: 'vd: admin@vimes.vn',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: ColorSkin.primary,
                        ),
                        enabled: !isLoading,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập email hoặc SĐT'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hint: 'Nhập mật khẩu',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: ColorSkin.primary,
                        ),
                        enabled: !isLoading,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: ColorSkin.subtitle,
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Vui lòng nhập mật khẩu'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: ColorSkin.primary,
                            onChanged: isLoading
                                ? null
                                : (value) => setState(
                                    () => _rememberMe = value ?? false,
                                  ),
                          ),
                          Text(
                            'Ghi nhớ đăng nhập',
                            style: TypoSkin.bodyText2.copyWith(
                              color: ColorSkin.title,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () =>
                                    context.go(AppRoutes.forgotPassword.path),
                            child: Text(
                              'Quên mật khẩu?',
                              style: TypoSkin.bodyText2.copyWith(
                                color: ColorSkin.secondary1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AuthPrimaryButton(
                        label: 'Đăng nhập',
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: ColorSkin.grey3),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'hoặc',
                              style: TypoSkin.bodyText2.copyWith(
                                color: ColorSkin.subtitle,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: ColorSkin.grey3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : _loginWithGoogle,
                          icon: _googleInProgress && state is! LoginLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : SvgPicture.asset(
                                  'lib/assets/svg/google_logo.svg',
                                  width: 22,
                                  height: 22,
                                ),
                          label: Text(
                            'Đăng nhập với Google',
                            style: TypoSkin.buttonText1.copyWith(
                              color: ColorSkin.title,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ColorSkin.border1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: TypoSkin.bodyText2.copyWith(
                              color: ColorSkin.subtitle,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => context.go(AppRoutes.register.path),
                            child: Text(
                              'Đăng ký',
                              style: TypoSkin.bodyText2.copyWith(
                                color: ColorSkin.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
