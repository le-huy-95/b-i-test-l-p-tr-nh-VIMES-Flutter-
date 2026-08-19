import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_y_app/data/models/warehouse/warehouse.dart';
import 'package:test_y_app/features/warehouse/bloc/warehouse_form_bloc.dart';
import 'package:test_y_app/features/warehouse/pages/warehouse_form_page.dart';
import 'package:test_y_app/features/warehouse/warehouse_map_pick_result.dart';

class MockWarehouseFormBloc extends MockBloc<WarehouseFormEvent, WarehouseFormState>
    implements WarehouseFormBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const WarehouseFormSubmitted(code: '', name: ''));
  });

  late MockWarehouseFormBloc bloc;

  setUp(() {
    bloc = MockWarehouseFormBloc();
    whenListen(
      bloc,
      const Stream<WarehouseFormState>.empty(),
      initialState: const WarehouseFormInitial(),
    );
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    WarehouseFormPagePickLocation? pickLocation,
    Warehouse? existing,
  }) async {
    if (existing != null) {
      whenListen(
        bloc,
        Stream<WarehouseFormState>.fromIterable([
          WarehouseFormInitial(existing: existing),
        ]),
        initialState: WarehouseFormInitial(existing: existing),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WarehouseFormBloc>.value(
          value: bloc,
          child: WarehouseFormPage(pickLocation: pickLocation),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hides latitude and longitude fields', (tester) async {
    await pumpForm(tester);

    expect(find.text('Latitude'), findsNothing);
    expect(find.text('Longitude'), findsNothing);
    expect(find.text('Địa chỉ'), findsOneWidget);
  });

  testWidgets('picking a map address submits hidden coordinates to api', (
    tester,
  ) async {
    await pumpForm(
      tester,
      pickLocation: (context, {latitude, longitude, address}) async {
        return const WarehouseMapPickResult(
          address: '12 Nguyễn Huệ, Quận 1',
          latitude: 10.7769,
          longitude: 106.7009,
        );
      },
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Mã kho *'), 'WH01');
    await tester.enterText(find.widgetWithText(TextFormField, 'Tên kho *'), 'Kho chính');
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();

    expect(find.text('12 Nguyễn Huệ, Quận 1'), findsOneWidget);
    expect(find.text('10.7769'), findsNothing);
    expect(find.text('106.7009'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo kho'));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured.single;
    expect(captured, isA<WarehouseFormSubmitted>());
    final event = captured as WarehouseFormSubmitted;
    expect(event.code, 'WH01');
    expect(event.name, 'Kho chính');
    expect(event.address, '12 Nguyễn Huệ, Quận 1');
    expect(event.latitude, closeTo(10.7769, 0.0001));
    expect(event.longitude, closeTo(106.7009, 0.0001));
  });
}
