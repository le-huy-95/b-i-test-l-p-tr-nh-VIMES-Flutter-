import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/features/overview/overview_formatters.dart';

void main() {
  test('formats VND with grouping', () {
    expect(formatVnd('2450000.00'), '2.450.000 ₫');
    expect(formatVnd('0'), '0 ₫');
  });

  test('formats qty and trims trailing zeros', () {
    expect(formatQty('10.0000'), '10');
    expect(formatQty('10.5000'), '10,5');
    expect(formatQty('0.2500'), '0,25');
  });
}
