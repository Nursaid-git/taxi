// Базовый smoke-тест: приложение запускается и показывает splash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi/main.dart';

void main() {
  testWidgets('App boots and shows splash logo', (WidgetTester tester) async {
    await tester.pumpWidget(const TaxiApp());

    expect(find.text('TAXI'), findsOneWidget);
    expect(find.byIcon(Icons.local_taxi_rounded), findsOneWidget);
  });
}
