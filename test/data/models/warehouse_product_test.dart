import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/product/product.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';

void main() {
  test('Warehouse.fromJson parses string lat/long', () {
    final wh = Warehouse.fromJson({
      'id': 'w1',
      'tenantId': 't1',
      'code': 'WH01',
      'name': 'Kho chính',
      'address': '123 ABC',
      'isActive': true,
      'latitude': '10.7769000',
      'longitude': '106.7009000',
    });

    expect(wh.code, 'WH01');
    expect(wh.latitude, closeTo(10.7769, 0.0001));
    expect(wh.longitude, closeTo(106.7009, 0.0001));
    expect(wh.hasCoordinates, isTrue);
  });

  test('Product.fromJson parses units and decimals', () {
    final product = Product.fromJson({
      'id': 'p1',
      'tenantId': 't1',
      'sku': 'SP001',
      'barcode': '893',
      'name': 'Sản phẩm A',
      'baseUnitName': 'cái',
      'minStockLevel': '10.0000',
      'maxStockLevel': '100.0000',
      'reorderPoint': '5.0000',
      'averageCost': '12.5',
      'isActive': true,
      'units': [
        {
          'id': 'u1',
          'productId': 'p1',
          'unitName': 'cái',
          'conversionRate': '1.000000',
        },
      ],
    });

    expect(product.sku, 'SP001');
    expect(product.minStockLevel, 10);
    expect(product.maxStockLevel, 100);
    expect(product.reorderPoint, 5);
    expect(product.averageCost, 12.5);
    expect(product.units, hasLength(1));
    expect(product.units.first.unitName, 'cái');
  });
}
