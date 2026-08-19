import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';

class OverviewApiService extends BaseApiService {
  String _errorMessage(ApiResponse<dynamic> response, String fallback) {
    final err = response.error;
    if (err != null && err.isNotEmpty && !err.startsWith('{')) {
      return err;
    }
    return response.message?.isNotEmpty == true ? response.message! : fallback;
  }

  Never _throwFailed(ApiResponse<dynamic> response, String fallback) {
    throw Exception(_errorMessage(response, fallback));
  }

  OrganizationOverview _decode(dynamic value) {
    if (value is Map<String, dynamic>) {
      return OrganizationOverview.fromJson(value);
    }
    return OrganizationOverview.fromJson(
      Map<String, dynamic>.from(value as Map),
    );
  }

  Future<OrganizationOverview> getOrganizationOverview({
    required DateTime from,
    required DateTime to,
    int expiryDays = 30,
    int topLimit = 5,
    int recentLimit = 5,
  }) async {
    final response = await getRequest<OrganizationOverview>(
      ApiEndpoints.organizationOverview,
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'expiryDays': expiryDays,
        'topLimit': topLimit,
        'recentLimit': recentLimit,
      },
      decode: _decode,
    );
    if (!response.success || response.data == null) {
      _throwFailed(response, 'Không tải được tổng quan tổ chức');
    }
    return response.data!;
  }
}
