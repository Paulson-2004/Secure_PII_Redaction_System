import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/dashboard_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Dashboard keeps the processing studio usable across widths',
      (tester) async {
    final auth = AuthProvider()..continueAsGuest();
    const widths = [
      360.0,
      390.0,
      430.0,
      768.0,
      1024.0,
      1280.0,
      1366.0,
      1440.0,
      1920.0
    ];

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(create: (_) => DocumentProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final studio = find.text('Document Redaction Studio');
      expect(studio, findsOneWidget, reason: 'viewport width $width');
      expect(tester.getTopLeft(studio).dy, lessThan(900),
          reason: 'the primary workflow should appear near the top');
      expect(tester.takeException(), isNull,
          reason: 'viewport width $width should not overflow or throw');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
