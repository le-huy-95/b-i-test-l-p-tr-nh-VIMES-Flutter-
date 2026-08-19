import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/app/router/app_router.dart';

void main() {
  test('forgot-password and reset-password routes are registered', () {
    final config = AppRouterConfig.instance.router.configuration;

    expect(
      config.findMatch(Uri.parse('/forgot-password')).isNotEmpty,
      isTrue,
      reason: 'Route /forgot-password must exist',
    );
    expect(
      config.findMatch(Uri.parse('/reset-password')).isNotEmpty,
      isTrue,
      reason: 'Route /reset-password must exist',
    );
  });
}
