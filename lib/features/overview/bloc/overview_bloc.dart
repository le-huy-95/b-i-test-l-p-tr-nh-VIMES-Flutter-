import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/domain/repositories/overview_repository.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_id.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_slice.dart';
import 'package:test_y_app/features/overview/overview_date_range.dart';

sealed class OverviewEvent extends Equatable {
  const OverviewEvent();
  @override
  List<Object?> get props => [];
}

class OverviewStarted extends OverviewEvent {
  const OverviewStarted();
}

class OverviewRefreshed extends OverviewEvent {
  const OverviewRefreshed();
}

class OverviewChartFiltered extends OverviewEvent {
  const OverviewChartFiltered({
    required this.chartId,
    required this.from,
    required this.to,
  });

  final OverviewChartId chartId;
  final DateTime from;
  final DateTime to;

  @override
  List<Object?> get props => [chartId, from, to];
}

class OverviewChartRetried extends OverviewEvent {
  const OverviewChartRetried(this.chartId);

  final OverviewChartId chartId;

  @override
  List<Object?> get props => [chartId];
}

sealed class OverviewState extends Equatable {
  const OverviewState();
  @override
  List<Object?> get props => [];
}

class OverviewInitial extends OverviewState {
  const OverviewInitial();
}

class OverviewLoading extends OverviewState {
  const OverviewLoading();
}

class OverviewReady extends OverviewState {
  const OverviewReady({required this.charts});

  final Map<OverviewChartId, OverviewChartSlice> charts;

  OverviewChartSlice slice(OverviewChartId id) => charts[id]!;

  bool get isAnyChartLoading =>
      charts.values.any((slice) => slice.isLoading);

  @override
  List<Object?> get props => [charts];
}

class OverviewFailure extends OverviewState {
  const OverviewFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class OverviewBloc extends Bloc<OverviewEvent, OverviewState> {
  OverviewBloc({
    required OverviewRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now,
       super(const OverviewInitial()) {
    on<OverviewStarted>(_onStarted);
    on<OverviewRefreshed>(_onRefreshed);
    on<OverviewChartFiltered>(_onChartFiltered);
    on<OverviewChartRetried>(_onChartRetried);
  }

  final OverviewRepository _repository;
  final DateTime Function() _clock;

  Future<void> _onStarted(
    OverviewStarted event,
    Emitter<OverviewState> emit,
  ) async {
    emit(const OverviewLoading());
    try {
      final (from, to) = overviewDefaultRange(_clock());
      final data = await _fetchOverview(from: from, to: to);
      emit(_readyFromShared(data, from: from, to: to));
    } catch (e) {
      emit(OverviewFailure(_friendly(e)));
    }
  }

  Future<void> _onRefreshed(
    OverviewRefreshed event,
    Emitter<OverviewState> emit,
  ) async {
    final current = state;
    if (current is! OverviewReady) {
      if (current is OverviewInitial || current is OverviewFailure) {
        await _onStarted(const OverviewStarted(), emit);
      }
      return;
    }

    final (from, to) = overviewDefaultRange(_clock());
    emit(_loadingAll(current, from: from, to: to, isFiltered: false));

    try {
      final data = await _fetchOverview(from: from, to: to);
      emit(_readyFromShared(data, from: from, to: to));
    } catch (e) {
      emit(
        current.copyWithCharts(
          _failedAll(current.charts, message: _friendly(e)),
        ),
      );
    }
  }

  Future<void> _onChartFiltered(
    OverviewChartFiltered event,
    Emitter<OverviewState> emit,
  ) async {
    final current = state;
    if (current is! OverviewReady) return;

    emit(
      current.updated(
        event.chartId,
        (slice) => slice.copyWith(
          from: event.from,
          to: event.to,
          status: OverviewChartStatus.loading,
          isFiltered: true,
          clearError: true,
        ),
      ),
    );

    try {
      final data = await _fetchOverview(from: event.from, to: event.to);
      final latest = state;
      if (latest is! OverviewReady) return;
      emit(
        latest.updated(
          event.chartId,
          (slice) => slice.copyWith(
            status: OverviewChartStatus.loaded,
            data: data,
            clearError: true,
          ),
        ),
      );
    } catch (e) {
      final latest = state;
      if (latest is! OverviewReady) return;
      emit(
        latest.updated(
          event.chartId,
          (slice) => slice.copyWith(
            status: OverviewChartStatus.failure,
            errorMessage: _friendly(e),
          ),
        ),
      );
    }
  }

  Future<void> _onChartRetried(
    OverviewChartRetried event,
    Emitter<OverviewState> emit,
  ) async {
    final current = state;
    if (current is! OverviewReady) return;

    final slice = current.slice(event.chartId);
    add(
      OverviewChartFiltered(
        chartId: event.chartId,
        from: slice.from,
        to: slice.to,
      ),
    );
  }

  Future<OrganizationOverview> _fetchOverview({
    required DateTime from,
    required DateTime to,
  }) {
    return _repository.getOrganizationOverview(
      from: from,
      to: to,
      expiryDays: 30,
      topLimit: 5,
      recentLimit: 5,
    );
  }

  OverviewReady _readyFromShared(
    OrganizationOverview data, {
    required DateTime from,
    required DateTime to,
  }) {
    return OverviewReady(
      charts: {
        for (final id in OverviewChartId.all)
          id: OverviewChartSlice(
            from: from,
            to: to,
            status: OverviewChartStatus.loaded,
            data: data,
            isFiltered: false,
          ),
      },
    );
  }

  OverviewReady _loadingAll(
    OverviewReady current, {
    required DateTime from,
    required DateTime to,
    required bool isFiltered,
  }) {
    return OverviewReady(
      charts: {
        for (final entry in current.charts.entries)
          entry.key: entry.value.copyWith(
            from: from,
            to: to,
            status: OverviewChartStatus.loading,
            isFiltered: isFiltered,
            clearError: true,
          ),
      },
    );
  }

  Map<OverviewChartId, OverviewChartSlice> _failedAll(
    Map<OverviewChartId, OverviewChartSlice> charts, {
    required String message,
  }) {
    return {
      for (final entry in charts.entries)
        entry.key: entry.value.copyWith(
          status: OverviewChartStatus.failure,
          errorMessage: message,
        ),
    };
  }

  String _friendly(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }
}

extension on OverviewReady {
  OverviewReady copyWithCharts(Map<OverviewChartId, OverviewChartSlice> charts) {
    return OverviewReady(charts: charts);
  }

  OverviewReady updated(
    OverviewChartId id,
    OverviewChartSlice Function(OverviewChartSlice slice) update,
  ) {
    return OverviewReady(
      charts: {
        for (final entry in charts.entries)
          entry.key: entry.key == id ? update(entry.value) : entry.value,
      },
    );
  }
}
