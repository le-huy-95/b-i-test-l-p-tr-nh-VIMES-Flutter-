import 'package:flutter/material.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

/// Field text dùng chung cho mọi form, có sẵn validate bắt buộc qua [required].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.required = false,
    this.maxLines = 1,
    this.enabled = true,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final bool required;
  final int maxLines;
  final bool enabled;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: required ? '$label *' : label,
      controller: controller,
      initialValue: initialValue,
      hintText: hintText,
      keyboardType: keyboardType,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      validator:
          validator ??
          (required ? (v) => requiredValidator(v, label: label) : null),
    );
  }
}
