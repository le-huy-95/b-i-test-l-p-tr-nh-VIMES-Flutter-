import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';
import 'package:test_y_app/shared/widgets/app_form_field.dart';

class ProductUnitInput {
  const ProductUnitInput({
    required this.unitName,
    required this.conversionRate,
  });

  final String unitName;
  final double conversionRate;
}

class ProductUnitEditor extends StatefulWidget {
  const ProductUnitEditor({
    super.key,
    required this.baseUnitName,
    required this.value,
    required this.onChanged,
  });

  final String baseUnitName;
  final List<ProductUnitInput> value;
  final ValueChanged<List<ProductUnitInput>> onChanged;

  @override
  State<ProductUnitEditor> createState() => _ProductUnitEditorState();
}

class _ProductUnitEditorState extends State<ProductUnitEditor> {
  late List<ProductUnitInput> _units;

  @override
  void initState() {
    super.initState();
    _units = _ensureBaseUnit(widget.value);
  }

  @override
  void didUpdateWidget(covariant ProductUnitEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.baseUnitName != widget.baseUnitName) {
      _units = _ensureBaseUnit(widget.value);
    }
  }

  List<ProductUnitInput> _ensureBaseUnit(List<ProductUnitInput> input) {
    final next = <ProductUnitInput>[
      ProductUnitInput(unitName: widget.baseUnitName, conversionRate: 1),
      ...input.where(
        (item) => item.unitName.trim() != widget.baseUnitName.trim(),
      ),
    ];
    return next;
  }

  void _emit(List<ProductUnitInput> next) {
    setState(() => _units = next);
    widget.onChanged(next);
  }

  void _addUnit() {
    _emit([
      _units.first,
      ..._units.skip(1),
      const ProductUnitInput(unitName: '', conversionRate: 1),
    ]);
  }

  void _removeUnit(int index) {
    if (index <= 0) return;
    final next = [..._units]..removeAt(index);
    _emit(next);
  }

  void _updateUnitName(int index, String value) {
    final next = [..._units];
    next[index] = ProductUnitInput(
      unitName: value,
      conversionRate: next[index].conversionRate,
    );
    _emit(next);
  }

  void _updateUnitRate(int index, String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    final next = [..._units];
    next[index] = ProductUnitInput(
      unitName: next[index].unitName,
      conversionRate: parsed ?? next[index].conversionRate,
    );
    _emit(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _units.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _UnitRow(
            index: i,
            unit: _units[i],
            baseUnitName: widget.baseUnitName,
            onNameChanged: (v) => _updateUnitName(i, v),
            onRateChanged: (v) => _updateUnitRate(i, v),
            onRemove: i == 0 ? null : () => _removeUnit(i),
            isBaseUnit: i == 0,
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Thêm đơn vị',
            onPressed: _addUnit,
            variant: AppButtonVariant.outlined,
            height: 42,
          ),
        ),
      ],
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.index,
    required this.unit,
    required this.baseUnitName,
    required this.onNameChanged,
    required this.onRateChanged,
    required this.onRemove,
    required this.isBaseUnit,
  });

  final int index;
  final ProductUnitInput unit;
  final String baseUnitName;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onRateChanged;
  final VoidCallback? onRemove;
  final bool isBaseUnit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorSkin.tealLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorSkin.border1.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isBaseUnit ? '$baseUnitName (đơn vị gốc)' : 'Đơn vị #$index',
                  style: TypoSkin.bodyText2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColorSkin.title,
                  ),
                ),
              ),
              if (!isBaseUnit)
                IconButton(
                  tooltip: 'Xoá đơn vị',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: ColorSkin.error,
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppFormField(
            label: 'Tên đơn vị',
            initialValue: unit.unitName,
            hintText: 'VD: thùng',
            enabled: !isBaseUnit,
            onChanged: onNameChanged,
            validator: (value) {
              if (isBaseUnit) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập đơn vị';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'Hệ số quy đổi',
            initialValue: unit.conversionRate.toStringAsFixed(6),
            hintText: 'VD: 12',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onRateChanged,
            validator: (value) {
              final raw = value?.trim().replaceAll(',', '.');
              final rate = double.tryParse(raw ?? '');
              if (rate == null) return 'Vui lòng nhập tỷ lệ quy đổi';
              if (rate <= 0) return 'Tỷ lệ quy đổi phải lớn hơn 0';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
