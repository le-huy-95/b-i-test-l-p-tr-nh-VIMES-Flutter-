import 'package:intl/intl.dart';
import 'package:test_y_app/core/constants/env_config.dart';

String formatVnd(String raw) {
  final value = double.tryParse(raw) ?? 0;
  final grouped = NumberFormat.decimalPattern('vi_VN').format(value.round());
  final unit = EnvConfig.currency.trim();
  return unit.isEmpty ? grouped : '$grouped $unit';
}

String formatQty(String raw) {
  final value = double.tryParse(raw) ?? 0;
  return NumberFormat('#,##0.####', 'vi_VN').format(value);
}

String withUnit(String value, String unit) {
  if (unit.isEmpty) return value;
  return '$value $unit';
}

String formatQtyWithUnit(String raw, String unit) =>
    withUnit(formatQty(raw), unit);

String formatCountWithUnit(num value, String unit) =>
    withUnit(value.round().toString(), unit);
