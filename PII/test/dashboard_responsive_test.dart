import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/dashboard_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';
import 'package:pii_redaction/widgets/pipeline_stepper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Dashboard adapts between two-column desktop and stacked mobile layouts',
      (tester) async {
    final auth = AuthProvider()..continueAsGuest();

    // Required breakpoints from Phase 11
    const desktopWidths = [1440.0, 1366.0, 1280.0, 1024.0];
    const stackedWidths = [768.0, 430.0, 390.0, 360.0];

    // ── Desktop Two-Column Validation ───────────────────────────────────────
    for (final width in desktopWidths) {
      tester.view.physicalSize = Size(width, 1000);
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

      final studioFinder = find.text('Document Redaction Studio');
      final recentFinder = find.text('Recent Processing Activity');
      final healthFinder = find.text('Live System Monitor');
      final stepperFinder = find.byType(PipelineStepper);

      expect(studioFinder, findsOneWidget, reason: 'Studio on width $width');
      expect(recentFinder, findsOneWidget, reason: 'Recent on width $width');
      expect(healthFinder, findsOneWidget, reason: 'Health on width $width');
      expect(stepperFinder, findsOneWidget, reason: 'Stepper on width $width');

      final studioRect = tester.getRect(find.ancestor(
        of: studioFinder,
        matching: find.byType(Container),
      ).first);

      final recentRect = tester.getRect(find.ancestor(
        of: recentFinder,
        matching: find.byType(Container),
      ).first);

      final healthRect = tester.getRect(find.ancestor(
        of: healthFinder,
        matching: find.byType(Container),
      ).first);

      final stepperRect = tester.getRect(stepperFinder);

      // In desktop mode:
      // 1. Studio is in the left column.
      // 2. Recent Activity is in the right column (to the right of Studio).
      expect(recentRect.left, greaterThanOrEqualTo(studioRect.right - 5),
          reason: 'Recent Activity must be to the right of Studio at $width');

      // 3. System Monitor is in the right column (to the right of Studio).
      expect(healthRect.left, greaterThanOrEqualTo(studioRect.right - 5),
          reason: 'System Monitor must be to the right of Studio at $width');

      // 4. System Monitor is vertically below Recent Activity.
      expect(healthRect.top, greaterThanOrEqualTo(recentRect.bottom - 5),
          reason: 'System Monitor must be below Recent Activity at $width');

      // 5. Pipeline Architecture Stepper is below the primary workspace.
      expect(stepperRect.top, greaterThanOrEqualTo(studioRect.bottom - 5),
          reason: 'Pipeline stepper must be below Studio at $width');

      // Verify the 6 engine status cards exist at the top
      expect(find.text('OCR Engine'), findsOneWidget);
      expect(find.text('Regex Engine'), findsOneWidget);
      expect(find.text('NER Engine'), findsOneWidget);
      expect(find.text('Hybrid Fusion'), findsAtLeastNWidgets(1));
      expect(find.text('Policy Engine'), findsOneWidget);
      expect(find.text('Redactor'), findsOneWidget);

      expect(tester.takeException(), isNull,
          reason: 'Desktop width $width should not throw or overflow');
    }

    // ── Narrow / Mobile Stacked Validation ──────────────────────────────────
    for (final width in stackedWidths) {
      tester.view.physicalSize = Size(width, 1000);
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

      final studioFinder = find.text('Document Redaction Studio');
      final recentFinder = find.text('Recent Processing Activity');
      final healthFinder = find.text('Live System Monitor');

      final studioRect = tester.getRect(find.ancestor(
        of: studioFinder,
        matching: find.byType(Container),
      ).first);

      final recentRect = tester.getRect(find.ancestor(
        of: recentFinder,
        matching: find.byType(Container),
      ).first);

      final healthRect = tester.getRect(find.ancestor(
        of: healthFinder,
        matching: find.byType(Container),
      ).first);

      // In stacked mode:
      // Recent Activity is stacked below Studio
      expect(recentRect.top, greaterThanOrEqualTo(studioRect.bottom - 5),
          reason: 'Recent Activity must stack below Studio at $width');

      // System Monitor is stacked below Recent Activity
      expect(healthRect.top, greaterThanOrEqualTo(recentRect.bottom - 5),
          reason: 'System Monitor must stack below Recent Activity at $width');

      expect(tester.takeException(), isNull,
          reason: 'Stacked width $width should not throw or overflow');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
