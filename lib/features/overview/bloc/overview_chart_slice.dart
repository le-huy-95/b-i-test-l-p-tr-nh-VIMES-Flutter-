import 'package:equatable/equatable.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';

enum OverviewChartStatus { loading, loaded, failure }

class OverviewChartSlice extends Equatable {
  const OverviewChartSlice({
    required this.from,
    required this.to,
    required this.status,
    this.data,
    this.errorMessage,
    this.isFiltered = false,
  });

  final DateTime from;
  final DateTime to;
  final OverviewChartStatus status;
  final OrganizationOverview? data;
  final String? errorMessage;
  final bool isFiltered;

  bool get isLoading => status == OverviewChartStatus.loading;
  bool get hasFailure => status == OverviewChartStatus.failure;

  OverviewChartSlice copyWith({
    DateTime? from,
    DateTime? to,
    OverviewChartStatus? status,
    OrganizationOverview? data,
    String? errorMessage,
    bool? isFiltered,
    bool clearData = false,
    bool clearError = false,
  }) {
    return OverviewChartSlice(
      from: from ?? this.from,
      to: to ?? this.to,
      status: status ?? this.status,
      data: clearData ? null : data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isFiltered: isFiltered ?? this.isFiltered,
    );
  }

  @override
  List<Object?> get props => [from, to, status, data, errorMessage, isFiltered];
}
