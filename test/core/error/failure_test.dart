import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/error/failure.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

void main() {
  test('ApiResponse parses error.code and details list', () {
    final response = ApiResponse<void>.fromJson({
      'success': false,
      'error': {
        'code': 'STOCK_INSUFFICIENT',
        'message': 'Không đủ tồn kho',
        'details': [
          {'productId': 'p1', 'requested': '10', 'available': '2'},
        ],
      },
    });

    expect(response.success, isFalse);
    expect(response.errorCode, 'STOCK_INSUFFICIENT');
    expect(response.error, 'Không đủ tồn kho');
    expect(response.errorDetails, isA<List>());
  });

  test('Failure keeps list details', () {
    final failure = Failure(
      message: 'Không đủ tồn kho',
      code: 'STOCK_INSUFFICIENT',
      details: [
        {'productId': 'p1', 'requested': 10, 'available': 2},
      ],
    );
    expect(failure.code, 'STOCK_INSUFFICIENT');
    expect(failure.details, isA<List>());
  });
}
