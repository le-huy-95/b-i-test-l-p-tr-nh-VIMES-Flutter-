import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/app/router/app_router.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/features/auth/bloc/register_bloc.dart';
import 'package:test_y_app/features/auth/bloc/register_event.dart';
import 'package:test_y_app/features/auth/bloc/register_state.dart';
import 'package:test_y_app/features/auth/widgets/auth_primary_button.dart';
import 'package:test_y_app/features/auth/widgets/auth_text_field.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late bool _agreeTerms;
  bool _obscurePassword = true;
  bool _hydratedFromDraft = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _agreeTerms = false;

    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
    ]) {
      controller.addListener(_syncDraftToBloc);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydratedFromDraft) return;
    _hydratedFromDraft = true;

    final bloc = context.read<RegisterBloc>();
    // Returning from OTP keeps RegisterSuccess; clear status so form is editable.
    if (bloc.state is RegisterSuccess || bloc.state is RegisterLoading) {
      bloc.add(const RegisterStatusCleared());
    }

    final draft = bloc.state.draft;
    _nameController.text = draft.name;
    _emailController.text = draft.email;
    _phoneController.text = draft.phone;
    _passwordController.text = draft.password;
    _agreeTerms = draft.agreeTerms;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
    ]) {
      controller.removeListener(_syncDraftToBloc);
      controller.dispose();
    }
    super.dispose();
  }

  RegisterFormDraft _currentDraft() {
    return RegisterFormDraft(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      agreeTerms: _agreeTerms,
    );
  }

  void _syncDraftToBloc() {
    if (!mounted || !_hydratedFromDraft) return;
    context.read<RegisterBloc>().add(RegisterDraftUpdated(_currentDraft()));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _syncDraftToBloc();
    context.read<RegisterBloc>().add(const RegisterSubmitted());
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
          'Đăng ký',
          style: TypoSkin.title2.copyWith(color: ColorSkin.title),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<RegisterBloc, RegisterState>(
          listenWhen: (previous, current) =>
              current is RegisterFailure ||
              (current is RegisterSuccess && previous is! RegisterSuccess),
          listener: (context, state) {
            if (state is RegisterFailure) {
              SimpleSnackbarService.showError(state.message);
            } else if (state is RegisterSuccess) {
              final email = state.draft.email.trim();
              final phone = state.draft.phone.trim();
              context.push(
                AppRoutes.verifyOtp.path,
                extra: {
                  'phone': phone,
                  if (email.isNotEmpty) 'email': email,
                },
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is RegisterLoading;
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
                      const SizedBox(height: 24),
                      Text(
                        'Tạo tài khoản',
                        style: TypoSkin.title1.copyWith(color: ColorSkin.title),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Điền thông tin để bắt đầu dùng VIMES Inventory',
                        style: TypoSkin.bodyText2.copyWith(
                          color: ColorSkin.subtitle,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthTextField(
                        controller: _nameController,
                        label: 'Họ và tên',
                        hint: 'Nguyễn Văn A',
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập họ tên'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'email@vimes.vn',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return null;
                          if (!email.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _phoneController,
                        label: 'Số điện thoại',
                        hint: '09xxxxxxxx',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập số điện thoại'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hint: 'Tối thiểu 6 ký tự',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (value.length < 6) {
                            return 'Mật khẩu tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreeTerms,
                            activeColor: ColorSkin.primary,
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    setState(
                                      () => _agreeTerms = value ?? false,
                                    );
                                    _syncDraftToBloc();
                                  },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật của VIMES',
                                style: TypoSkin.bodyText2.copyWith(
                                  color: ColorSkin.subtitle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AuthPrimaryButton(
                        label: 'Tiếp tục',
                        isLoading: isLoading,
                        onPressed: (!_agreeTerms || isLoading) ? null : _submit,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Đã có tài khoản? ',
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
