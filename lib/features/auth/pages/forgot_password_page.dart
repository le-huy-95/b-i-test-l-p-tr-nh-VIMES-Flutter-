import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_bloc.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_event.dart';
import 'package:test_y_app/features/auth/bloc/forgot_password_state.dart';
import 'package:test_y_app/features/auth/widgets/auth_primary_button.dart';
import 'package:test_y_app/features/auth/widgets/auth_text_field.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordBloc>().add(
      ForgotPasswordSubmitted(_emailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSkin.white,
      appBar: AppHeader(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.login.path),
        ),
        onTitleTap: () => context.go(AppRoutes.login.path),
        title: Text(
          'Quên mật khẩu',
          style: TypoSkin.title2.copyWith(color: ColorSkin.title),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
          listener: (context, state) {
            if (state is ForgotPasswordFailure) {
              SimpleSnackbarService.showError(state.message);
            } else if (state is ForgotPasswordSuccess) {
              final message = state.result.displayMessage;
              SimpleSnackbarService.showInfo(message);
              AppRouterConfig.instance.goResetPassword(
                email: state.email,
                expiresAt: state.result.expiresAt,
                message: message,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ForgotPasswordLoading;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: () =>
                    FocusScope.of(context, createDependency: false).unfocus(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bước 1 / 2',
                        style: TypoSkin.bodyText2.copyWith(
                          color: ColorSkin.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 0.5,
                          minHeight: 8,
                          backgroundColor: ColorSkin.tealLight,
                          color: ColorSkin.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Nhập email của bạn',
                        style: TypoSkin.title1.copyWith(color: ColorSkin.title),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhập email đã đăng ký. Nếu email tồn tại trong hệ thống, '
                        'bạn sẽ nhận được mã OTP 6 số qua email để đặt lại mật khẩu. '
                        'Hãy kiểm tra cả Hộp thư đến và Spam.',
                        style: TypoSkin.bodyText2.copyWith(
                          color: ColorSkin.subtitle,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'email@vimes.vn',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: ColorSkin.primary,
                        ),
                        enabled: !isLoading,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!email.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: 'Gửi mã OTP',
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Nhớ mật khẩu? ',
                            style: TypoSkin.bodyText2.copyWith(
                              color: ColorSkin.subtitle,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => context.go(AppRoutes.login.path),
                            child: Text(
                              'Đăng nhập',
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
