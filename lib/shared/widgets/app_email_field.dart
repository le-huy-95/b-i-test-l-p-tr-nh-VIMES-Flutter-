import 'package:flutter/material.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

/// Field email dùng chung, có sẵn validate định dạng email.
class AppEmailField extends StatelessWidget {
  const AppEmailField({
    super.key,
    this.label = 'Email',
    this.controller,
    this.hintText,
    this.required = false,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: required ? '$label *' : label,
      controller: controller,
      hintText: hintText ?? 'Nhập email',
      keyboardType: TextInputType.emailAddress,
      enabled: enabled,
      onChanged: onChanged,
      validator: (value) =>
          emailValidator(value, required: required, label: label),
    );
  }
}
