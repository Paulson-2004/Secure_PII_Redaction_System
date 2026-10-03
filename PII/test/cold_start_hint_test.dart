import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/login_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';
import 'package:pii_redaction/widgets/backend_waking_hint.dart';

/// Test harness exposing a single "backend request in flight" boolean.
///
/// Mirrors how screens use the widget: existing loading state stays visible
/// the whole time, the delayed hint appears only after [delay], and success
/// / failure replace the loading state via the caller's normal flow.
class _RequestHarness extends StatefulWidget {
  final Duration delay;
  const _RequestHarness(
      {super.key, this.delay = ColdStartCopy.wakeDelay});

  @override
  State<_RequestHarness> createState() => _RequestHarnessState();
}

class _RequestHarnessState extends State<_RequestHarness> {
  bool isWaiting = true;
  bool succeeded = false;
  bool failed = false;

  void completeWithSuccess() {
    setState(() {
      isWaiting = false;
      succeeded = true;
    });
  }

  void completeWithFailure() {
    setState(() {
      isWaiting = false;
      failed = true;
    });
  }

  void cancel() {
    setState(() {
      isWaiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (isWaiting) const Text('Loading compliance audit logs...'),
              DelayedBackendWakingHint(
                isWaiting: isWaiting,
                delay: widget.delay,
              ),
              if (succeeded) const Text('Success flow continues'),
              if (failed)
                const Text(
                  'History could not be loaded. Check your connection and try again.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cold-start waiting UX (Render free-tier wake-up)', () {
    test('delay threshold is 5 seconds', () {
      expect(ColdStartCopy.wakeDelay, equals(const Duration(seconds: 5)));
    });

    testWidgets(
        '1. Fast backend response: cold-start message never appears',
        (tester) async {
      final key = GlobalKey<_RequestHarnessState>();
      await tester.pumpWidget(_RequestHarness(key: key));
      await tester.pump();

      // Existing loading state is visible immediately.
      expect(find.text('Loading compliance audit logs...'), findsOneWidget);
      expect(find.text(ColdStartCopy.title), findsNothing);

      // Resolve quickly (before the 5s threshold).
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(ColdStartCopy.title), findsNothing);

      key.currentState!.completeWithSuccess();
      await tester.pump();
      // Let the original delay elapse: hint must still never have appeared.
      await tester.pump(const Duration(seconds: 6));

      expect(find.text(ColdStartCopy.title), findsNothing);
      expect(find.text(ColdStartCopy.body), findsNothing);
      expect(find.text('Success flow continues'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '2. Slow backend: loading first, delayed waking message after threshold',
        (tester) async {
      final key = GlobalKey<_RequestHarnessState>();
      await tester.pumpWidget(_RequestHarness(key: key));
      await tester.pump();

      // 0-5s: normal loading only.
      expect(find.text('Loading compliance audit logs...'), findsOneWidget);
      expect(find.text(ColdStartCopy.title), findsNothing);

      await tester.pump(const Duration(seconds: 4, milliseconds: 900));
      expect(find.text('Loading compliance audit logs...'), findsOneWidget);
      expect(find.text(ColdStartCopy.title), findsNothing);

      // Just past the threshold the hint appears *alongside* loading.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Loading compliance audit logs...'), findsOneWidget);
      expect(find.text(ColdStartCopy.title), findsOneWidget);
      expect(find.text(ColdStartCopy.body), findsOneWidget);
      expect(find.text(ColdStartCopy.footnote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Backend eventually succeeds: message disappears cleanly',
        (tester) async {
      final key = GlobalKey<_RequestHarnessState>();
      await tester.pumpWidget(_RequestHarness(key: key));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(ColdStartCopy.title), findsOneWidget);

      key.currentState!.completeWithSuccess();
      await tester.pump();

      expect(find.text(ColdStartCopy.title), findsNothing);
      expect(find.text(ColdStartCopy.body), findsNothing);
      expect(find.text('Loading compliance audit logs...'), findsNothing);
      expect(find.text('Success flow continues'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '4. Backend fails: existing error shown, no false Render-sleeping claim',
        (tester) async {
      final key = GlobalKey<_RequestHarnessState>();
      await tester.pumpWidget(_RequestHarness(key: key));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(ColdStartCopy.title), findsOneWidget);

      key.currentState!.completeWithFailure();
      await tester.pump();

      // Hint removed; caller error state preserved.
      expect(find.text(ColdStartCopy.title), findsNothing);
      expect(
        find.text(
          'History could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      // Must not falsely claim Render was definitely responsible.
      expect(find.textContaining('Render is sleeping'), findsNothing);
      expect(find.textContaining('Render was'), findsNothing);
      expect(find.textContaining('definitely'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '5. Request cancellation/disposal: timers cleaned up, no setState-after-dispose',
        (tester) async {
      await tester.pumpWidget(const _RequestHarness());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Dispose while the delayed timer is still pending.
      await tester.pumpWidget(const SizedBox.shrink());
      // Let the original deadline pass after disposal.
      await tester.pump(const Duration(seconds: 6));

      expect(tester.takeException(), isNull);
      expect(find.text(ColdStartCopy.title), findsNothing);
    });

    testWidgets('2b. Custom delay is respected when overridden', (tester) async {
      await tester.pumpWidget(
        const _RequestHarness(delay: Duration(seconds: 1)),
      );
      await tester.pump();
      expect(find.text(ColdStartCopy.title), findsNothing);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text(ColdStartCopy.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5b. Toggling waiting off before threshold never shows hint',
        (tester) async {
      final key = GlobalKey<_RequestHarnessState>();
      await tester.pumpWidget(_RequestHarness(key: key));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      key.currentState!.cancel();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text(ColdStartCopy.title), findsNothing);
      expect(tester.takeException(), isNull);
    });

    group('6. Mobile widths (430 / 390 / 360): compact, wraps, no overflow',
        () {
      for (final width in [430.0, 390.0, 360.0]) {
        testWidgets('hint renders cleanly at ${width.toInt()}px',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final key = GlobalKey<_RequestHarnessState>();
          await tester.pumpWidget(_RequestHarness(key: key));
          await tester.pump();
          await tester.pump(const Duration(seconds: 6));
          await tester.pump();

          expect(find.text(ColdStartCopy.title), findsOneWidget,
              reason: 'hint visible at $width');
          expect(find.text(ColdStartCopy.body), findsOneWidget,
              reason: 'body wraps at $width');
          expect(find.text(ColdStartCopy.footnote), findsOneWidget,
              reason: 'footnote visible at $width');
          // Static hint alone must also fit narrow viewports.
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: BackendWakingHint()),
              ),
            ),
          );
          await tester.pump();
          expect(find.text(ColdStartCopy.title), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: 'No overflow at $width');
        });
      }
    });

    testWidgets(
        '7. Auth/guest behavior: no hint when idle, guest entry unaffected',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(create: (_) => DocumentProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Idle login screen: no cold-start message, existing UI unchanged.
      expect(find.text(ColdStartCopy.title), findsNothing);
      expect(find.text('Continue as Guest'), findsOneWidget);

      // Guest mode still works and carries no auth regression.
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(auth.isGuest, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
