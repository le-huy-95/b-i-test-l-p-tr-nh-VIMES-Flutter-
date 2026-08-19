import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/domain/repositories/overview_repository.dart';
import 'package:test_y_app/features/overview/bloc/overview_bloc.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_id.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_slice.dart';

class MockOverviewRepository extends Mock implements OverviewRepository {}

OrganizationOverview _sample({String scope = 'organization'}) {
  return OrganizationOverview.fromJson({
    'generatedAt': '2026-08-17T14:00:00.000Z',
    'visibilityScope': scope,
    'role': scope == 'organization' ? 'admin' : 'warehouse_keeper',
    'filters': {
      'from': '2026-07-18T00:00:00.000Z',
      'to': '2026-08-17T14:00:00.000Z',
      'expiryDays': 30,
      'topLimit': 5,
      'recentLimit': 5,
    },
    'organization': {'warehouseCount': 1, 'warehouses': []},
    'documents': {
      'stockReceipts': {
        'byStatus': {},
        'total': 0,
        'pendingApproval': 0,
        'draft': 0,
        'completed': 0,
        'pendingApprovalList': [],
      },
      'stockIssues': {
        'byStatus': {},
        'total': 0,
        'pendingApproval': 0,
        'draft': 0,
        'completed': 0,
        'pendingApprovalList': [],
      },
      'stockOpenings': {
        'byStatus': {},
        'total': 0,
        'pendingApproval': 0,
        'draft': 0,
        'completed': 0,
      },
    },
    'productMovement': {
      'totalImportedQty': '0',
      'totalExportedQty': '0',
      'topImportedProducts': [],
      'topExportedProducts': [],
      'dailyMovement': [],
    },
    'inventory': null,
    'warehousesBreakdown': [],
  });
}

void main() {
  late MockOverviewRepository repository;
  final now = DateTime.utc(2026, 8, 17, 14);

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2020));
  });

  setUp(() {
    repository = MockOverviewRepository();
    when(
      () => repository.getOrganizationOverview(
        from: any(named: 'from'),
        to: any(named: 'to'),
        expiryDays: any(named: 'expiryDays'),
        topLimit: any(named: 'topLimit'),
        recentLimit: any(named: 'recentLimit'),
      ),
    ).thenAnswer((_) async => _sample());
  });

  OverviewBloc buildBloc() {
    return OverviewBloc(repository: repository, clock: () => now);
  }

  blocTest<OverviewBloc, OverviewState>(
    'loads last 30 days overview on start with shared chart data',
    build: buildBloc,
    act: (bloc) => bloc.add(const OverviewStarted()),
    expect: () => [
      isA<OverviewLoading>(),
      isA<OverviewReady>().having(
        (s) => s.slice(OverviewChartId.movement).data?.visibilityScope,
        'scope',
        'organization',
      ),
    ],
    verify: (_) {
      final captured = verify(
        () => repository.getOrganizationOverview(
          from: captureAny(named: 'from'),
          to: captureAny(named: 'to'),
          expiryDays: captureAny(named: 'expiryDays'),
          topLimit: captureAny(named: 'topLimit'),
          recentLimit: captureAny(named: 'recentLimit'),
        ),
      ).captured;
      expect(captured[0], DateTime.utc(2026, 7, 18, 14));
      expect(captured[1], now);
    },
  );

  blocTest<OverviewBloc, OverviewState>(
    'filters one chart and keeps others on previous range',
    build: buildBloc,
    seed: () => OverviewReady(
      charts: {
        for (final id in OverviewChartId.all)
          id: OverviewChartSlice(
            from: DateTime.utc(2026, 7, 18, 14),
            to: now,
            status: OverviewChartStatus.loaded,
            data: _sample(),
          ),
      },
    ),
    act: (bloc) => bloc.add(
      OverviewChartFiltered(
        chartId: OverviewChartId.movement,
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 10, 23, 59, 59, 999),
      ),
    ),
    expect: () => [
      isA<OverviewReady>().having(
        (s) => s.slice(OverviewChartId.movement).isLoading,
        'movement loading',
        true,
      ),
      isA<OverviewReady>().having(
        (s) => s.slice(OverviewChartId.movement).status,
        'movement loaded',
        OverviewChartStatus.loaded,
      ),
    ],
    verify: (bloc) {
      final state = bloc.state as OverviewReady;
      expect(state.slice(OverviewChartId.movement).isFiltered, isTrue);
      expect(state.slice(OverviewChartId.movement).isLoading, isFalse);
      expect(state.slice(OverviewChartId.pending).isFiltered, isFalse);
      verify(
        () => repository.getOrganizationOverview(
          from: any(named: 'from'),
          to: any(named: 'to'),
          expiryDays: any(named: 'expiryDays'),
          topLimit: any(named: 'topLimit'),
          recentLimit: any(named: 'recentLimit'),
        ),
      ).called(1);
    },
  );

  blocTest<OverviewBloc, OverviewState>(
    'refresh resets all charts to default range with one api call',
    build: buildBloc,
    seed: () => OverviewReady(
      charts: {
        for (final id in OverviewChartId.all)
          id: OverviewChartSlice(
            from: DateTime.utc(2026, 8, 1),
            to: DateTime.utc(2026, 8, 10, 23, 59, 59, 999),
            status: OverviewChartStatus.loaded,
            data: _sample(),
            isFiltered: id == OverviewChartId.movement,
          ),
      },
    ),
    act: (bloc) => bloc.add(const OverviewRefreshed()),
    verify: (bloc) {
      final state = bloc.state as OverviewReady;
      expect(state.slice(OverviewChartId.movement).isFiltered, isFalse);
      expect(state.slice(OverviewChartId.movement).from, DateTime.utc(2026, 7, 18, 14));
      verify(
        () => repository.getOrganizationOverview(
          from: any(named: 'from'),
          to: any(named: 'to'),
          expiryDays: any(named: 'expiryDays'),
          topLimit: any(named: 'topLimit'),
          recentLimit: any(named: 'recentLimit'),
        ),
      ).called(1);
    },
  );

  blocTest<OverviewBloc, OverviewState>(
    'emits failure when initial load throws',
    build: () {
      when(
        () => repository.getOrganizationOverview(
          from: any(named: 'from'),
          to: any(named: 'to'),
          expiryDays: any(named: 'expiryDays'),
          topLimit: any(named: 'topLimit'),
          recentLimit: any(named: 'recentLimit'),
        ),
      ).thenThrow(Exception('Mất mạng'));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const OverviewStarted()),
    expect: () => [
      isA<OverviewLoading>(),
      isA<OverviewFailure>().having((s) => s.message, 'message', 'Mất mạng'),
    ],
  );

  blocTest<OverviewBloc, OverviewState>(
    'marks only failed chart when filter throws',
    build: () {
      when(
        () => repository.getOrganizationOverview(
          from: any(named: 'from'),
          to: any(named: 'to'),
          expiryDays: any(named: 'expiryDays'),
          topLimit: any(named: 'topLimit'),
          recentLimit: any(named: 'recentLimit'),
        ),
      ).thenThrow(Exception('Mất mạng'));
      return buildBloc();
    },
    seed: () => OverviewReady(
      charts: {
        for (final id in OverviewChartId.all)
          id: OverviewChartSlice(
            from: DateTime.utc(2026, 7, 18, 14),
            to: now,
            status: OverviewChartStatus.loaded,
            data: _sample(),
          ),
      },
    ),
    act: (bloc) => bloc.add(
      OverviewChartFiltered(
        chartId: OverviewChartId.pending,
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 10, 23, 59, 59, 999),
      ),
    ),
    verify: (bloc) {
      final state = bloc.state as OverviewReady;
      expect(state.slice(OverviewChartId.pending).errorMessage, 'Mất mạng');
      expect(state.slice(OverviewChartId.movement).hasFailure, isFalse);
    },
  );
}
