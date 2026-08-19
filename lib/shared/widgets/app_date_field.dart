import 'package:flutter/material.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText = 'dd/MM/yyyy',
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: label,
      controller: controller,
      readOnly: true,
      onTap: onTap,
      hintText: hintText,
      enabled: enabled,
      suffixIcon: const Icon(Icons.calendar_today_outlined),
      validator: (value) => requiredValidator(value, label: label),
    );
  }
}
