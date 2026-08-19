import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_form_bloc.dart';
import 'package:test_y_app/features/warehouse/warehouse_address_picker.dart';
import 'package:test_y_app/features/warehouse/widgets/warehouse_address_field.dart';
import 'package:test_y_app/features/warehouse/widgets/warehouse_form_section.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_phone_field.dart';
import 'package:test_y_app/shared/widgets/app_text_field.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';

typedef WarehouseFormPagePickLocation = WarehouseAddressPicker;

class WarehouseFormPage extends StatefulWidget {
  const WarehouseFormPage({
    super.key,
    this.warehouseId,
    this.pickLocation,
  });

  final String? warehouseId;
  final WarehouseFormPagePickLocation? pickLocation;

  @override
  State<WarehouseFormPage> createState() => _WarehouseFormPageState();
}

class _WarehouseFormPageState extends State<WarehouseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _seeded = false;

  bool get _isEdit => widget.warehouseId != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seedFromState(WarehouseFormInitial state) {
    if (_seeded || state.existing == null) return;
    final w = state.existing!;
    _code.text = w.code;
    _name.text = w.name;
    _address.text = w.address ?? '';
    _phone.text = w.phone ?? '';
    _latitude = w.latitude;
    _longitude = w.longitude;
    _seeded = true;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<WarehouseFormBloc>().add(
      WarehouseFormSubmitted(
        code: _code.text,
        name: _name.text,
        address: _address.text,
        phone: _phone.text,
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WarehouseFormBloc, WarehouseFormState>(
      listener: (context, state) {
        if (state is WarehouseFormInitial) {
          _seedFromState(state);
        }
        if (state is WarehouseFormSuccess) {
          SimpleSnackbarService.showSuccess('Đã lưu kho');
          context.pop(true);
        }
        if (state is WarehouseFormFailure) {
          SimpleSnackbarService.showError(state.message);
        }
      },
      builder: (context, state) {
        final loading = state is WarehouseFormLoading;
        final submitting = state is WarehouseFormSubmitting;
        final busy = loading || submitting;

        return Scaffold(
          appBar: AppHeader(title: Text(_isEdit ? 'Sửa kho' : 'Tạo kho')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () =>
                      FocusScope.of(context, createDependency: false).unfocus(),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      children: [
                        WarehouseFormSection(
                          title: 'Thông tin cơ bản',
                          subtitle: 'Nhập mã kho, tên kho và liên hệ',
                          child: Column(
                            children: [
                              AppTextField(
                                label: 'Mã kho',
                                controller: _code,
                                enabled: !busy && !_isEdit,
                                required: true,
                                hintText: 'WH01',
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Tên kho',
                                controller: _name,
                                required: true,
                                hintText: 'Tên kho',
                                enabled: !busy,
                              ),
                              const SizedBox(height: 12),
                              AppPhoneField(
                                label: 'Số điện thoại kho',
                                controller: _phone,
                                hintText: '0123 456 789',
                                enabled: !busy,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        WarehouseFormSection(
                          title: 'Địa chỉ',
                          subtitle: 'Nhập tay hoặc mở bản đồ để chọn vị trí',
                          child: WarehouseAddressField(
                            controller: _address,
                            latitude: _latitude,
                            longitude: _longitude,
                            enabled: !busy,
                            pickLocation: widget.pickLocation,
                            onPicked: ({required latitude, required longitude}) {
                              setState(() {
                                _latitude = latitude;
                                _longitude = longitude;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: AppButton(
                label: _isEdit ? 'Cập nhật' : 'Tạo kho',
                variant: AppButtonVariant.primary,
                expand: true,
                isLoading: submitting,
                onPressed: busy ? null : _submit,
              ),
            ),
          ),
        );
      },
    );
  }
}
