import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/datasources/api_services/customer_api_service.dart';
import 'package:test_y_app/data/datasources/api_services/supplier_api_service.dart';
import 'package:test_y_app/data/datasources/api_services/contact_api_service.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';
import 'package:test_y_app/shared/widgets/select_field.dart';

class PartnerSelectDialogItem extends AppSelectItem {
  const PartnerSelectDialogItem({
    required super.id,
    required super.title,
    super.subtitle,
  });
}

Future<List<PartnerSelectDialogItem>> mapCustomersToPartnerItems() async {
  final items = await CustomerApiService().list();
  return items
      .map(
        (c) => PartnerSelectDialogItem(
          id: c.id,
          title: c.name,
          subtitle: [
            if (c.code != null && c.code!.isNotEmpty) c.code,
            if (c.phone != null && c.phone!.isNotEmpty) c.phone,
          ].join(' · '),
        ),
      )
      .toList();
}

List<PartnerSelectDialogItem> mapDeliveryContactsToPartnerItems(
  List<DeliveryContact> contacts,
) {
  return contacts
      .where((contact) => contact.isActive)
      .map(
        (contact) => PartnerSelectDialogItem(
          id: contact.id,
          title: contact.fullName,
          subtitle: [
            if (contact.phone != null && contact.phone!.isNotEmpty) contact.phone,
            if (contact.companyName != null && contact.companyName!.isNotEmpty)
              contact.companyName,
          ].join(' · '),
        ),
      )
      .toList();
}

Future<List<PartnerSelectDialogItem>> mapSuppliersToPartnerItems() async {
  final items = await SupplierApiService().list();
  return items
      .map(
        (c) => PartnerSelectDialogItem(
          id: c.id,
          title: c.name,
          subtitle: [
            if (c.code != null && c.code!.isNotEmpty) c.code,
            if (c.phone != null && c.phone!.isNotEmpty) c.phone,
          ].join(' · '),
        ),
      )
      .toList();
}

/// Generic bottom sheet to create a partner (Customer or Supplier)
class PartnerCreateSheet extends StatefulWidget {
  const PartnerCreateSheet({
    super.key,
    required this.title,
    required this.onCreated,
    this.codeLabel = 'Mã',
    this.nameLabel = 'Tên',
    this.extraFields = const [],
  });

  final String title;
  final Future<dynamic> Function(Map<String, String> values) onCreated;
  final String codeLabel;
  final String nameLabel;
  final List<PartnerCreateField> extraFields;

  @override
  State<PartnerCreateSheet> createState() => _PartnerCreateSheetState();
}

class PartnerCreateField {
  const PartnerCreateField({
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.fieldKey,
  });

  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final String? fieldKey;
}

class _PartnerCreateSheetState extends State<PartnerCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _extraControllers = <String, TextEditingController>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.extraFields) {
      if (field.fieldKey != null) {
        _extraControllers[field.fieldKey!] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    for (final controller in _extraControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _extraValues() {
    final result = <String, String>{};
    for (final field in widget.extraFields) {
      if (field.fieldKey != null &&
          _extraControllers.containsKey(field.fieldKey)) {
        final value = _extraControllers[field.fieldKey]!.text.trim();
        if (value.isNotEmpty) {
          result[field.fieldKey!] = value;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ColorSkin.grey3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ColorSkin.title,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppFormField(
                    label: '${widget.codeLabel} *',
                    controller: _codeController,
                    hintText: 'Nhập ${widget.codeLabel.toLowerCase()}',
                    enabled: !_saving,
                    validator: (v) => requiredValidator(
                      v,
                      label: widget.codeLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppFormField(
                    label: '${widget.nameLabel} *',
                    controller: _nameController,
                    hintText: 'Nhập ${widget.nameLabel.toLowerCase()}',
                    enabled: !_saving,
                    validator: (v) => requiredValidator(
                      v,
                      label: widget.nameLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final field in widget.extraFields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppFormField(
                        label: field.label,
                        controller: field.fieldKey != null
                            ? _extraControllers[field.fieldKey!]
                            : null,
                        hintText: field.hintText,
                        enabled: !_saving,
                        keyboardType: field.keyboardType,
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: ColorSkin.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: const BoxDecoration(
              color: ColorSkin.white,
              border: Border(
                top: BorderSide(color: ColorSkin.border1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Hủy',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    variant: AppButtonVariant.outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Tạo',
                    onPressed: _saving ? null : _submit,
                    variant: AppButtonVariant.primary,
                    isLoading: _saving,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.onCreated({
        'code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        ..._extraValues(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
