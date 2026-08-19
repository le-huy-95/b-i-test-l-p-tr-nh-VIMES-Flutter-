import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/error/either.dart';
import 'package:test_y_app/core/error/failure.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: '''
APP_ENV=dev
API_DEV_URL=https://jsonplaceholder.typicode.com
API_PROD_URL=https://api.example.com
''');
  });

  test('EnvConfig reads base URL from dotenv', () {
    expect(EnvConfig.isDev, isTrue);
    expect(EnvConfig.baseUrl, 'https://jsonplaceholder.typicode.com');
  });

  test('Either fold works', () {
    const result = Right<Failure, int>(42);
    expect(result.fold((_) => 0, (value) => value), 42);
  });
}
