import 'package:test_y_app/core/error/failure.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';

Never throwIfApiFailed(ApiResponse<dynamic> response, String fallback) {
  final message = (response.error != null &&
          response.error!.isNotEmpty &&
          !response.error!.startsWith('{'))
      ? response.error!
      : (response.message?.isNotEmpty == true ? response.message! : fallback);
  throw Failure(
    message: message,
    code: response.errorCode,
    details: response.errorDetails,
  );
}
