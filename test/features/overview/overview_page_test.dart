import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/data/models/overview/organization_overview.dart';
import 'package:test_y_app/data/models/tenant/tenant_membership.dart';
import 'package:test_y_app/data/models/user/user.dart';
import 'package:test_y_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_y_app/features/auth/bloc/auth_event.dart';
import 'package:test_y_app/features/auth/bloc/auth_state.dart';
import 'package:test_y_app/features/overview/bloc/overview_bloc.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_id.dart';
import 'package:test_y_app/features/overview/bloc/overview_chart_slice.dart';
import 'package:test_y_app/features/overview/pages/overview_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockOverviewBloc extends MockBloc<OverviewEvent, OverviewState>
    implements OverviewBloc {}

OrganizationOverview _emptyOverview() {
  return OrganizationOverview.fromJson({
    'generatedAt': '2026-08-17T14:00:00.000Z',
    'visibilityScope': 'organization',
    'role': 'admin',
    'filters': {
      'from': '2026-07-18T00:00:00.000Z',
      'to': '2026-08-17T14:00:00.000Z',
      'expiryDays': 30,
      'topLimit': 5,
      'recentLimit': 5,
    },
    'organization': {'warehouseCount': 0, 'warehouses': []},
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

OverviewReady _emptyReady() {
  final now = DateTime.utc(2026, 8, 17, 14);
  final data = _emptyOverview();
  return OverviewReady(
    charts: {
      for (final id in OverviewChartId.all)
        id: OverviewChartSlice(
          from: DateTime.utc(2026, 7, 18, 14),
          to: now,
          status: OverviewChartStatus.loaded,
          data: data,
        ),
    },
  );
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  required AuthState authState,
  required OverviewState overviewState,
}) async {
  final authBloc = MockAuthBloc();
  final overviewBloc = MockOverviewBloc();
  whenListen(authBloc, const Stream<AuthState>.empty(), initialState: authState);
  whenListen(
    overviewBloc,
    const Stream<OverviewState>.empty(),
    initialState: overviewState,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<OverviewBloc>.value(value: overviewBloc),
          ],
          child: const OverviewPage(),
        ),
      ),
    ),
  );
}

void main() {
  const user = User(id: 'u1', name: 'le việt dung');
  const tenant = TenantMembership(
    id: 't1',
    code: 'VIMES',
    name: 'Phòng khám VIMES',
    role: 'admin',
  );

  final authState = AuthAuthenticated(
    user: user,
    tenants: const [tenant],
    selectedTenantId: 't1',
  );

  testWidgets('greets with selected organization name, not the user name', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      authState: authState,
      overviewState: _emptyReady(),
    );

    expect(find.text('Xin chào, Phòng khám VIMES'), findsOneWidget);
    expect(find.text('Xin chào, le việt dung'), findsNothing);
  });

  testWidgets(
    'centers empty overview copy without a border when there is no data',
    (tester) async {
      await _pumpOverview(
        tester,
        authState: authState,
        overviewState: _emptyReady(),
      );

      const emptyCopy = 'Chưa có dữ liệu tổng quan cho tôi';
      final emptyText = find.text(emptyCopy);
      expect(emptyText, findsOneWidget);
      expect(
        find.text('Chưa có dữ liệu tổng quan trong khoảng thời gian'),
        findsNothing,
      );

      final borderedAncestor = find.ancestor(
        of: emptyText,
        matching: find.byWidgetPredicate((widget) {
          BoxDecoration? decoration;
          if (widget is Container && widget.decoration is BoxDecoration) {
            decoration = widget.decoration! as BoxDecoration;
          } else if (widget is DecoratedBox &&
              widget.decoration is BoxDecoration) {
            decoration = widget.decoration as BoxDecoration;
          }
          return decoration?.border != null;
        }),
      );
      expect(borderedAncestor, findsNothing);

      final textCenter = tester.getCenter(emptyText);
      final pageCenter = tester.getCenter(find.byType(OverviewPage));
      expect((textCenter.dx - pageCenter.dx).abs(), lessThan(2));
      expect((textCenter.dy - pageCenter.dy).abs(), lessThan(80));
    },
  );
}
