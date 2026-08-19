import 'package:test_y_app/data/models/overview/organization_overview.dart';

abstract class OverviewRepository {
  Future<OrganizationOverview> getOrganizationOverview({
    required DateTime from,
    required DateTime to,
    int expiryDays = 30,
    int topLimit = 5,
    int recentLimit = 5,
  });
}
