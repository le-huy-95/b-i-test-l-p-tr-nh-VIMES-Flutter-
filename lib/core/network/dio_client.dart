import 'package:test_y_app/core/constants/env_config.dart';
import 'package:test_y_app/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';

class DioClient {
  DioClient._() {
    _dio.interceptors.add(AuthInterceptor());
  }

  static final DioClient _instance = DioClient._();

  static Dio get instance {
    _instance._dio.options = BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );
    return _instance._dio;
  }

  final Dio _dio = Dio();
}
