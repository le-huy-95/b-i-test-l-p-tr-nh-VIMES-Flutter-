import 'dart:io';

import 'package:flutter/material.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:test_y_app/core/assets/default_tenant_logo.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_bloc.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_event.dart';
import 'package:test_y_app/features/auth/bloc/tenant_select_state.dart';
import 'package:test_y_app/features/auth/widgets/auth_primary_button.dart';
import 'package:test_y_app/features/auth/widgets/auth_text_field.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

const _maxLogoBytes = 2 * 1024 * 1024;

List<TenantMembership> _tenantsFromAuthState(AuthState state) {
  return switch (state) {
    AuthNeedsTenant(:final tenants) => tenants,
    AuthAuthenticated(:final tenants) => tenants,
    _ => const <TenantMembership>[],
  };
}

class SelectTenantPage extends StatelessWidget {
  const SelectTenantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final seedTenants = _tenantsFromAuthState(context.read<AuthBloc>().state);

    return BlocProvider(
      create: (context) => TenantSelectBloc(
        authRepository: context.read<AuthRepository>(),
        tenants: seedTenants,
      ),
      child: const _SelectTenantInitializer(child: _SelectTenantView()),
    );
  }
}

class _SelectTenantInitializer extends StatefulWidget {
  const _SelectTenantInitializer({required this.child});

  final Widget child;

  @override
  State<_SelectTenantInitializer> createState() =>
      _SelectTenantInitializerState();
}

class _SelectTenantInitializerState extends State<_SelectTenantInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromAuth());
  }

  void _syncFromAuth() {
    if (!mounted) return;

    final tenants = _tenantsFromAuthState(context.read<AuthBloc>().state);
    if (tenants.isNotEmpty) {
      context.read<TenantSelectBloc>().add(
        TenantSelectLoadRequested(tenants),
      );
    }
    context.read<TenantSelectBloc>().add(const TenantSelectRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthNeedsTenant &&
          (previous is! AuthNeedsTenant ||
              previous.tenants != current.tenants),
      listener: (context, state) {
        if (state is AuthNeedsTenant) {
          context.read<TenantSelectBloc>().add(
            TenantSelectLoadRequested(state.tenants),
          );
        }
      },
      child: widget.child,
    );
  }
}

class _SelectTenantView extends StatelessWidget {
  const _SelectTenantView();

  Future<void> _showCreateSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final fieldsKey = GlobalKey<_CreateTenantFormFieldsState>();
    BuildContext? sheetContext;

    final result = await AppBottomSheetService.show<
        ({String code, String name, String? logoFilePath})>(
      context: context,
      title: 'Tạo tổ chức',
      content: Builder(
        builder: (sc) {
          sheetContext = sc;
          return GestureDetector(
            onTap: () =>
                FocusScope.of(sc, createDependency: false).unfocus(),
            child: _CreateTenantFormFields(key: fieldsKey, formKey: formKey),
          );
        },
      ),
      actions: [
        const AppBottomSheetAction(label: 'Huỷ'),
        AppBottomSheetAction(
          label: 'Tạo',
          style: AppBottomSheetActionStyle.primary,
          dismissOnTap: false,
          onPressed: () {
            final fields = fieldsKey.currentState;
            if (fields == null ||
                !(formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(sheetContext!).pop((
              code: fields.code,
              name: fields.name,
              logoFilePath: fields.logoFilePath,
            ));
          },
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    context.read<TenantSelectBloc>().add(
      TenantSelectCreateRequested(
        code: result.code,
        name: result.name,
        logoFilePath: result.logoFilePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSkin.white,
      appBar: AppHeader(
        titlePadding: const EdgeInsets.only(left: 8),
        title: Text(
          'Chọn tổ chức',
          style: TypoSkin.title2.copyWith(color: ColorSkin.title),
        ),
        showNotificationAction: false,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => AppBottomSheetService.showLogoutConfirm(
              context: context,
              onConfirm: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
            ),
            icon: const Icon(Icons.logout, color: ColorSkin.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthError) {
                  SimpleSnackbarService.showError(state.error);
                }
              },
            ),
            BlocListener<TenantSelectBloc, TenantSelectState>(
              listener: (context, state) {
                if (state is TenantSelectFailure) {
                  SimpleSnackbarService.showError(state.message);
                } else if (state is TenantSelectCreated) {
                  if (state.logoUploadWarning != null) {
                    SimpleSnackbarService.showError(state.logoUploadWarning!);
                  }
                  context.read<AuthBloc>().add(
                    AuthTenantSelected(state.created.id),
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<TenantSelectBloc, TenantSelectState>(
            builder: (context, state) {
              final tenants = switch (state) {
                TenantSelectInitial(:final tenants) => tenants,
                TenantSelectRefreshing(:final tenants) => tenants,
                TenantSelectLoading(:final tenants) => tenants,
                TenantSelectSelected(:final tenants) => tenants,
                TenantSelectCreated(:final tenants) => tenants,
                TenantSelectFailure(:final tenants) => tenants,
              };
              final isCreating = state is TenantSelectLoading;
              final isRefreshing = state is TenantSelectRefreshing;

              if (isRefreshing && tenants.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      'Chọn tổ chức để tiếp tục làm việc',
                      style: TypoSkin.bodyText2.copyWith(
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ),
                  if (isRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  Expanded(
                    child: tenants.isEmpty
                        ? Center(
                            child: Text(
                              'Chưa có tổ chức nào.\nHãy tạo tổ chức mới để bắt đầu.',
                              textAlign: TextAlign.center,
                              style: TypoSkin.bodyText1.copyWith(
                                color: ColorSkin.subtitle,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: tenants.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tenant = tenants[index];
                              return _TenantCard(
                                tenant: tenant,
                                enabled: !isCreating && !isRefreshing,
                                onTap: () => context.read<AuthBloc>().add(
                                  AuthTenantSelected(tenant.id),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: AuthPrimaryButton(
                      label: 'Tạo tổ chức mới',
                      isLoading: isCreating,
                      onPressed: isRefreshing
                          ? null
                          : () => _showCreateSheet(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreateTenantFormFields extends StatefulWidget {
  const _CreateTenantFormFields({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<_CreateTenantFormFields> createState() =>
      _CreateTenantFormFieldsState();
}

class _CreateTenantFormFieldsState extends State<_CreateTenantFormFields> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _logoFilePath;
  String? _logoError;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get code => _codeController.text.trim();

  String get name => _nameController.text.trim();

  String? get logoFilePath => _logoFilePath;

  Future<void> _pickLogo() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final size = await File(picked.path).length();
    if (size > _maxLogoBytes) {
      setState(() {
        _logoError = 'Logo tối đa 2MB';
        _logoFilePath = null;
      });
      return;
    }

    setState(() {
      _logoFilePath = picked.path;
      _logoError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _pickLogo,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                _TenantLogoAvatar(
                  size: 72,
                  logoUrl: null,
                  localFilePath: _logoFilePath,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logo tổ chức',
                        style: TypoSkin.bodyText1.copyWith(
                          color: ColorSkin.title,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn từ thư viện (tuỳ chọn)',
                        style: TypoSkin.bodyText2.copyWith(
                          color: ColorSkin.subtitle,
                        ),
                      ),
                      if (_logoError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _logoError!,
                          style: TypoSkin.bodyText2.copyWith(
                            color: ColorSkin.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.photo_library_outlined,
                    color: ColorSkin.primary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _codeController,
            label: 'Mã tổ chức',
            hint: 'vd: VIMES',
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập mã tổ chức'
                : null,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _nameController,
            label: 'Tên tổ chức',
            hint: 'vd: VIMES Hospital',
            textInputAction: TextInputAction.done,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên tổ chức'
                : null,
          ),
        ],
      ),
    );
  }
}

class _TenantLogoAvatar extends StatelessWidget {
  const _TenantLogoAvatar({
    required this.size,
    this.logoUrl,
    this.localFilePath,
  });

  final double size;
  final String? logoUrl;
  final String? localFilePath;

  String? _resolveLogoUrl(String? rawUrl) {
    final raw = rawUrl?.trim();
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    final base = EnvConfig.mediaBaseUrl.trim();
    final baseUri = base.isEmpty ? null : Uri.tryParse(base);
    final isLoopbackHost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';

    if (uri.hasScheme && !isLoopbackHost) {
      return raw;
    }

    final path = uri.hasScheme
        ? uri.path
        : (raw.startsWith('/') ? raw : '/$raw');
    final relativePath = path.startsWith('/') ? path.substring(1) : path;

    if (baseUri == null) {
      return uri.hasScheme && isLoopbackHost
          ? null
          : (raw.startsWith('/') ? raw : '/$raw');
    }

    return baseUri.resolve(relativePath).toString();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.25);

    Widget image;
    if (localFilePath != null) {
      image = Image.file(
        File(localFilePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      final resolved = _resolveLogoUrl(logoUrl);
      if (resolved != null) {
        image = Image.network(
          resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultAsset(size),
        );
      } else {
        image = _defaultAsset(size);
      }
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _defaultAsset(double size) {
    return Image.asset(
      defaultTenantLogoAssetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onTap,
    this.enabled = true,
  });

  final TenantMembership tenant;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorSkin.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorSkin.border1),
            color: ColorSkin.tealLight.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TenantLogoAvatar(size: 48, logoUrl: tenant.logoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: TypoSkin.bodyText1.copyWith(
                        color: ColorSkin.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.code,
                      style: TypoSkin.bodyText2.copyWith(
                        color: ColorSkin.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColorSkin.orangeLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  () {
                    final role = tenant.role.trim().toLowerCase();
                    return switch (role) {
                      'admin' => 'Admin',
                      'warehouse_keeper' => 'Thủ kho',
                      'accountant' => 'Kế toán',
                      'approver' => 'Duyệt',
                      'viewer' => 'Người xem',
                      _ => tenant.role.trim().isEmpty ? '—' : tenant.role.trim(),
                    };
                  }(),
                  style: TypoSkin.placeholder2.copyWith(
                    color: ColorSkin.secondary1,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
