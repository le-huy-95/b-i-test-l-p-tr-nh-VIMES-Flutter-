/// Trả lỗi tiếng Việt nếu giá trị rỗng, ngược lại trả null.
String? requiredValidator(
  String? value, {
  String? label,
  String message = 'Vui lòng nhập thông tin bắt buộc',
}) {
  if (value == null || value.trim().isEmpty) {
    final trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return 'Vui lòng nhập ${trimmed.replaceAll(RegExp(r'\s*\*+\s*$'), '')}';
    }
    return message;
  }
  return null;
}

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Validate email. Mặc định cho phép rỗng; bật [required] để bắt buộc nhập.
String? emailValidator(String? value, {bool required = false, String? label}) {
  if (value == null || value.trim().isEmpty) {
    return required ? requiredValidator(value, label: label) : null;
  }
  if (!_emailPattern.hasMatch(value.trim())) return 'Email không hợp lệ';
  return null;
}

/// Validate số điện thoại Việt Nam. Mặc định cho phép rỗng; bật [required]
/// để bắt buộc nhập. Hỗ trợ định dạng 0xx, +84xx và dấu cách/gạch ngang.
String? phoneValidator(String? value, {bool required = false, String? label}) {
  if (value == null || value.trim().isEmpty) {
    return required ? requiredValidator(value, label: label) : null;
  }
  final raw = value.trim();
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (raw.startsWith('+') && digits.startsWith('84')) {
    digits = '0${digits.substring(2)}';
  }
  if (!RegExp(r'^0\d{9,10}$').hasMatch(digits)) {
    return 'Số điện thoại không hợp lệ';
  }
  return null;
}

/// Validate số. Mặc định cho phép rỗng và chấp nhận số âm.
String? numberValidator(
  String? value, {
  bool required = false,
  bool nonNegative = false,
  double? min,
  double? max,
  String? label,
}) {
  if (value == null || value.trim().isEmpty) {
    return required ? requiredValidator(value, label: label) : null;
  }
  final normalized = value.trim().replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null) return 'Số không hợp lệ';
  final name = label?.trim().isNotEmpty == true ? label!.trim() : 'Giá trị';
  if (nonNegative && parsed < 0) return '$name không được âm';
  if (min != null && parsed < min) return '$name không được nhỏ hơn $min';
  if (max != null && parsed > max) return '$name không được lớn hơn $max';
  return null;
}
