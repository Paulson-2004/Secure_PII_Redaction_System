// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pii_redaction/main.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';

void main() {
  testWidgets('PII Redaction App loads splash screen',
      (WidgetTester tester) async {
    // Build our app with required providers and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ],
        child: const PIIRedactionApp(),
      ),
    );

    // Pump a short frame without waiting for all animations to settle.
    // The splash screen has a progress indicator and delayed navigation.
    await tester.pump(const Duration(milliseconds: 200));

    // Verify that the app loaded successfully
    // The splash screen should be displayed
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PII Redaction'), findsOneWidget);
  });
}
