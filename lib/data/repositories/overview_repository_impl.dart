import 'package:test_y_app/data/datasources/api_services/overview_api_service.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/domain/repositories/overview_repository.dart';

class OverviewRepositoryImpl implements OverviewRepository {
  OverviewRepositoryImpl({OverviewApiService? apiService})
    : _api = apiService ?? OverviewApiService();

  final OverviewApiService _api;

  @override
  Future<OrganizationOverview> getOrganizationOverview({
    required DateTime from,
    required DateTime to,
    int expiryDays = 30,
    int topLimit = 5,
    int recentLimit = 5,
  }) {
    return _api.getOrganizationOverview(
      from: from,
      to: to,
      expiryDays: expiryDays,
      topLimit: topLimit,
      recentLimit: recentLimit,
    );
  }
}
