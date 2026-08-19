import 'package:test_y_app/core/constants/env_config.dart';

// Định dạng và nhãn hiển thị cho module Sản phẩm.

/// Định dạng số lượng trả về dạng chuỗi ("90.0000") → bỏ số 0 thừa.
String formatQty(num value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Định dạng số lượng có thể `null` → hiển thị `—`.
String formatNullableQty(num? value) {
  if (value == null) return '—';
  return formatQty(value);
}

/// Định dạng tiền tệ theo kiểu Việt Nam: 1.234.567 (bỏ phần thập phân = 0).
String formatMoney(num value) {
  final fixed = value.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final intPart = fixed.substring(0, dot);
  final decPart = fixed.substring(dot + 1);

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }
  final hasDecimals = decPart != '00';
  return '$buffer${hasDecimals ? ',$decPart' : ''}';
}

String formatMoneyWithCurrency(num value, {String? currency}) {
  final unit = (currency ?? EnvConfig.currency).trim();
  final formatted = formatMoney(value);
  if (unit.isEmpty) return formatted;
  return '$formatted $unit';
}