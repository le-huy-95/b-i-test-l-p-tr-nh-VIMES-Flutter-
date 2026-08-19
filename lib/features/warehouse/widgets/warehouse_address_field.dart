import 'package:flutter/material.dart';
import 'package:test_y_app/features/warehouse/pages/warehouse_map_picker_page.dart';
import 'package:test_y_app/features/warehouse/warehouse_address_picker.dart';
import 'package:test_y_app/shared/validators/form_validators.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

/// Field địa chỉ kho, mở bản đồ để chọn vị trí và tự điền địa chỉ trả về.
class WarehouseAddressField extends StatelessWidget {
  const WarehouseAddressField({
    super.key,
    required this.controller,
    this.latitude,
    this.longitude,
    this.enabled = true,
    this.required = false,
    this.onPicked,
    this.pickLocation,
  });

  final TextEditingController controller;
  final double? latitude;
  final double? longitude;
  final bool enabled;
  final bool required;
  final void Function({required double latitude, required double longitude})?
  onPicked;
  final WarehouseAddressPicker? pickLocation;

  Future<void> _openMapPicker(BuildContext context) async {
    final picker = pickLocation ?? WarehouseMapPickerPage.open;
    final result = await picker(
      context,
      latitude: latitude,
      longitude: longitude,
      address: controller.text,
    );
    if (result == null) return;
    controller.text = result.address;
    onPicked?.call(latitude: result.latitude, longitude: result.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormField(
      label: required ? 'Địa chỉ *' : 'Địa chỉ',
      controller: controller,
      hintText: 'Nhập hoặc chọn trên bản đồ',
      maxLines: 2,
      enabled: enabled,
      validator: required
          ? (v) => requiredValidator(v, label: 'Địa chỉ')
          : null,
      suffixIcon: IconButton(
        tooltip: 'Chọn trên bản đồ',
        icon: const Icon(Icons.map_outlined),
        onPressed: enabled ? () => _openMapPicker(context) : null,
      ),
    );
  }
}
