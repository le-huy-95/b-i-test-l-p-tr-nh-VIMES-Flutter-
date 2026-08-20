import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/datasources/api_services/contact_api_service.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';
import 'package:test_y_app/shared/widgets/app_phone_field.dart';

class ContactCreateSheet extends StatefulWidget {
  const ContactCreateSheet({super.key, required this.onCreated});

  final Future<DeliveryContact> Function({
    required String fullName,
    String? phone,
    String? companyName,
    String? note,
  })
  onCreated;

  static Future<DeliveryContact?> show(
    BuildContext context, {
    required Future<DeliveryContact> Function({
      required String fullName,
      String? phone,
      String? companyName,
      String? note,
    })
    onCreated,
  }) {
    return AppBottomSheetService.show<DeliveryContact>(
      context: context,
      // Self-contained form: hug content, avoid double chrome/padding.
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      content: ContactCreateSheet(onCreated: onCreated),
      actions: const [],
    );
  }

  @override
  State<ContactCreateSheet> createState() => _ContactCreateSheetState();
}

class _ContactCreateSheetState extends State<ContactCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.onCreated(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendly(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            onClose: _saving ? null : () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  AppFormField(
                    label: 'Họ tên *',
                    controller: _fullNameController,
                    hintText: 'Ví dụ: Nguyễn Văn A',
                    enabled: !_saving,
                    validator: (value) =>
                        requiredValidator(value, label: 'Họ tên'),
                  ),
                  const SizedBox(height: 10),
                  AppPhoneField(
                    label: 'Số điện thoại',
                    controller: _phoneController,
                    hintText: '0901234567',
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 10),
                  AppFormField(
                    label: 'Công ty / Đơn vị',
                    controller: _companyController,
                    hintText: 'Tên công ty vận chuyển (tuỳ chọn)',
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 10),
                  AppFormField(
                    label: 'Ghi chú',
                    controller: _noteController,
                    hintText: 'Ghi chú thêm về người giao hàng',
                    enabled: !_saving,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          _SheetActions(
            saving: _saving,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorSkin.border1,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 4, 0),
          child: Row(
            children: [
              const SizedBox(width: 40),
              const Expanded(
                child: Text(
                  'Tạo người giao hàng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorSkin.title,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: ColorSkin.subtitle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorSkin.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorSkin.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: ColorSkin.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ColorSkin.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: ColorSkin.white,
        border: Border(top: BorderSide(color: ColorSkin.border1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Huỷ',
              onPressed: saving ? null : onCancel,
              variant: AppButtonVariant.outlined,
              height: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: 'Lưu',
              onPressed: saving ? null : onSubmit,
              variant: AppButtonVariant.primary,
              isLoading: saving,
              height: 44,
              icon: saving
                  ? null
                  : const Icon(Icons.check, size: 18, color: ColorSkin.white),
            ),
          ),
        ],
      ),
    );
  }
}
