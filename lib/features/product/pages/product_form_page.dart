import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/features/product/bloc/product_form_bloc.dart';
import 'package:test_y_app/features/product/widgets/product_unit_editor.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';
import 'package:test_y_app/shared/utils/media_url.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_header.dart';
import 'package:test_y_app/shared/widgets/app_number_field.dart';
import 'package:test_y_app/shared/widgets/app_text_field.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.productId});

  final String? productId;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'cái');
  final _minStock = TextEditingController(text: '0');
  final _maxStock = TextEditingController();
  final _reorderPoint = TextEditingController();
  final _averageCost = TextEditingController(text: '0');
  bool _seeded = false;
  bool _imageUploading = false;
  String? _imageUrl;
  String? _imageFileId;
  bool _imageRemoved = false;
  String? _localImagePath;
  List<ProductUnitInput> _units = const [];

  bool get _isEdit => widget.productId != null;

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _barcode.dispose();
    _unit.dispose();
    _minStock.dispose();
    _maxStock.dispose();
    _reorderPoint.dispose();
    _averageCost.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _seed(ProductFormInitial state) {
    if (_seeded || state.existing == null) return;
    final p = state.existing!;
    _sku.text = p.sku;
    _name.text = p.name;
    _barcode.text = p.barcode ?? '';
    _imageUrl = p.imageUrl;
    _imageFileId = null;
    _imageRemoved = false;
    _localImagePath = null;
    _unit.text = p.baseUnitName;
    _minStock.text = _formatNum(p.minStockLevel);
    _maxStock.text = p.maxStockLevel == null
        ? ''
        : _formatNum(p.maxStockLevel!);
    _reorderPoint.text = p.reorderPoint == null
        ? ''
        : _formatNum(p.reorderPoint!);
    _averageCost.text = _formatNum(p.averageCost);
    _units = [
      ProductUnitInput(unitName: p.baseUnitName, conversionRate: 1),
      ...p.units
          .skip(1)
          .map(
            (u) => ProductUnitInput(
              unitName: u.unitName,
              conversionRate: u.conversionRate,
            ),
          ),
    ];
    _seeded = true;
    setState(() {});
  }

  double _parseNum(String raw, [double fallback = 0]) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? fallback;
  }

  double? _parseOptional(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _pickImage() async {
    final fileRepository = context.read<FileRepository>();
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final files = result?.files;
    final file = (files == null || files.isEmpty) ? null : files.first;
    if (file == null || file.path == null) return;

    setState(() {
      _localImagePath = file.path;
      _imageUploading = true;
    });
    try {
      final uploaded = await fileRepository.upload(file, kind: 'product');
      final fileId = uploaded.id.trim();
      if (fileId.isEmpty) {
        throw Exception('Máy chủ không trả về định danh file ảnh');
      }
      if (!mounted) return;
      setState(() {
        _imageUrl = uploaded.url.trim();
        _imageFileId = fileId;
        _imageRemoved = false;
      });
    } catch (e) {
      if (mounted) {
        SimpleSnackbarService.showError('Upload ảnh thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  void _removeImage() {
    setState(() {
      _imageUrl = null;
      _imageFileId = null;
      _localImagePath = null;
      _imageRemoved = _isEdit;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProductFormBloc>().add(
      ProductFormSubmitted(
        sku: _sku.text,
        name: _name.text,
        barcode: _barcode.text,
        imageFileId: _imageFileId,
        removeImage: _imageRemoved,
        baseUnitName: _unit.text,
        minStockLevel: _parseNum(_minStock.text),
        maxStockLevel: _parseOptional(_maxStock.text),
        reorderPoint: _parseOptional(_reorderPoint.text),
        averageCost: _parseNum(_averageCost.text),
        units: _units,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductFormBloc, ProductFormState>(
      listener: (context, state) {
        if (state is ProductFormInitial) _seed(state);
        if (state is ProductFormSuccess) {
          SimpleSnackbarService.showSuccess('Đã lưu sản phẩm');
          context.pop(true);
        }
        if (state is ProductFormFailure) {
          SimpleSnackbarService.showError(state.message);
        }
      },
      builder: (context, state) {
        final loading = state is ProductFormLoading;
        final submitting = state is ProductFormSubmitting;
        final busy = loading || submitting;
        final canInteract = !busy && !_imageUploading;

        return Scaffold(
          appBar: AppHeader(
            title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm'),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: ColorSkin.border1.withValues(alpha: 0.45),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: AppButton(
                label: _isEdit ? 'Cập nhật' : 'Tạo sản phẩm',
                onPressed: canInteract ? _submit : null,
                variant: AppButtonVariant.primary,
                isLoading: submitting,
                expand: true,
              ),
            ),
          ),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      children: [
                        _FormSection(
                          title: 'Ảnh sản phẩm',
                          child: _ProductImagePicker(
                            imageUrl: _imageUrl,
                            localImagePath: _localImagePath,
                            uploading: _imageUploading,
                            enabled: canInteract,
                            onPick: _pickImage,
                            onRemove: _removeImage,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FormSection(
                          title: 'Thông tin cơ bản',
                          child: Column(
                            children: [
                              AppTextField(
                                label: 'SKU',
                                controller: _sku,
                                enabled: !busy && !_isEdit,
                                required: true,
                                hintText: 'SP001',
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Tên sản phẩm',
                                controller: _name,
                                enabled: !busy,
                                required: true,
                                hintText: 'Tên sản phẩm',
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Barcode',
                                controller: _barcode,
                                enabled: !busy,
                                hintText: '893...',
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Đơn vị gốc',
                                controller: _unit,
                                enabled: !busy,
                                hintText: 'cái',
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FormSection(
                          title: 'Quản lý tồn kho',
                          child: Column(
                            children: [
                              AppNumberField(
                                label: 'Mức tồn tối thiểu',
                                controller: _minStock,
                                enabled: !busy,
                                nonNegative: true,
                                hintText: '0',
                              ),
                              const SizedBox(height: 12),
                              AppNumberField(
                                label: 'Mức tồn tối đa',
                                controller: _maxStock,
                                enabled: !busy,
                                nonNegative: true,
                                hintText: 'Để trống nếu không giới hạn',
                              ),
                              const SizedBox(height: 12),
                              AppNumberField(
                                label: 'Điểm đặt hàng lại',
                                controller: _reorderPoint,
                                enabled: !busy,
                                nonNegative: true,
                                hintText: 'Để trống nếu không cấu hình',
                              ),
                              const SizedBox(height: 12),
                              AppNumberField(
                                label: 'Giá vốn',
                                controller: _averageCost,
                                enabled: !busy,
                                nonNegative: true,
                                hintText: '0',
                                suffixText: EnvConfig.currency,
                              ),
                            ],
                          ),
                        ),
                        if (!_isEdit) ...[
                          const SizedBox(height: 22),
                          _FormSection(
                            title: 'Đơn vị quy đổi',
                            child: ProductUnitEditor(
                              baseUnitName: _unit.text.trim().isEmpty
                                  ? 'cái'
                                  : _unit.text.trim(),
                              value: _units,
                              onChanged: (units) =>
                                  setState(() => _units = units),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ProductImagePicker extends StatelessWidget {
  const _ProductImagePicker({
    required this.imageUrl,
    required this.localImagePath,
    required this.uploading,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final String? imageUrl;
  final String? localImagePath;
  final bool uploading;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasLocalImage =
        localImagePath != null && localImagePath!.trim().isNotEmpty;
    final resolvedImageUrl = resolveMediaUrl(imageUrl);
    final hasImage = hasLocalImage || resolvedImageUrl != null;

    Widget preview;
    if (hasLocalImage) {
      preview = Image.file(
        File(localImagePath!),
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ImagePlaceholder(),
      );
    } else if (resolvedImageUrl != null) {
      preview = Image.network(
        resolvedImageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ImagePlaceholder(),
      );
    } else {
      preview = const _ImagePlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: preview),
            if (uploading)
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          uploading
              ? 'Đang tải ảnh lên...'
              : 'Ảnh đại diện của sản phẩm (JPG, PNG, WebP...).',
          style: const TextStyle(
            fontSize: 12,
            color: ColorSkin.subtitle,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: hasImage ? 'Thay ảnh' : 'Chọn ảnh',
                onPressed: enabled && !uploading ? onPick : null,
                variant: AppButtonVariant.outlined,
                height: 44,
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Xóa ảnh',
                  onPressed: enabled && !uploading ? onRemove : null,
                  variant: AppButtonVariant.destructive,
                  height: 44,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: ColorSkin.tealLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.5)),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 34,
        color: ColorSkin.subtitle,
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ColorSkin.title,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
