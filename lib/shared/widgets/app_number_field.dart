import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

/// Field số dùng chung cho mọi form.
///
/// Hỗ trợ validate bắt buộc ([required]), không âm ([nonNegative]) và giới hạn
/// khoảng giá trị ([min]/[max]) thông qua [numberValidator].
class AppNumberField extends StatelessWidget {
  const AppNumberField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.onChanged,
    this.required = false,
    this.nonNegative = true,
    this.min,
    this.max,
    this.enabled = true,
    this.focusNode,
    this.suffixText,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool required;
  final bool nonNegative;
  final double? min;
  final double? max;
  final bool enabled;
  final FocusNode? focusNode;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: required ? '$label *' : label,
      controller: controller,
      initialValue: initialValue,
      hintText: hintText,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          nonNegative
              ? RegExp(r'^\d*\.?\d{0,2}$')
              : RegExp(r'^-?\d*\.?\d{0,2}$'),
        ),
      ],
      enabled: enabled,
      focusNode: focusNode,
      suffixText: suffixText,
      validator: (v) => numberValidator(
        v,
        required: required,
        nonNegative: nonNegative,
        min: min,
        max: max,
        label: label,
      ),
    );
  }
}

/// Field số tiền (định dạng VND, không thập phân).
class AppPriceField extends StatelessWidget {
  const AppPriceField({
    super.key,
    required this.label,
    this.initialValue,
    this.hintText,
    this.onChanged,
    this.nonNegative = true,
    this.focusNode,
    this.suffixText,
  });

  final String label;
  final String? initialValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool nonNegative;
  final FocusNode? focusNode;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return AppNumberField(
      label: label,
      initialValue: initialValue,
      hintText: hintText,
      onChanged: onChanged,
      nonNegative: nonNegative,
      focusNode: focusNode,
      suffixText: suffixText ?? EnvConfig.currency,
    );
  }
}
