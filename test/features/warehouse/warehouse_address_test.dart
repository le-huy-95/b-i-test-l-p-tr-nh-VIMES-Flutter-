import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/features/warehouse/warehouse_map_pick_result.dart';

void main() {
  test('composeWarehouseAddress joins non-empty parts', () {
    expect(
      composeWarehouseAddress([
        '12 Nguyễn Huệ',
        '  ',
        'Quận 1',
        null,
        'Hồ Chí Minh',
      ]),
      '12 Nguyễn Huệ, Quận 1, Hồ Chí Minh',
    );
  });

  test('composeWarehouseAddress returns empty when nothing usable', () {
    expect(composeWarehouseAddress(['', null, '   ']), '');
  });
}
