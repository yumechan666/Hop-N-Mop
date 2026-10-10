// Smoke test for Hop'N Mop.
//
// Verifies that the app boots into the game screen without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleanerroom/main.dart';

void main() {
  testWidgets('App builds the game screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build the app and trigger a frame. Asset loading happens
    // asynchronously, so a single pump is enough to confirm the widget
    // tree is constructed.
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
