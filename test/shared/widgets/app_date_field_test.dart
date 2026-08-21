import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_y_app/shared/widgets/app_date_field.dart';

void main() {
  testWidgets('AppDateField shows initialValue and calendar icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppDateField(
            label: 'HSD',
            initialValue: '20/08/2026',
            required: false,
            onChanged: _noop,
          ),
        ),
      ),
    );

    expect(find.text('20/08/2026'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });
}

void _noop(String _) {}
