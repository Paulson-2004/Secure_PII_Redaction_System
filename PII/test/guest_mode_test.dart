import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/dashboard_screen.dart';
import 'package:pii_redaction/screens/login_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';
import 'package:pii_redaction/widgets/app_drawer.dart';
import 'package:pii_redaction/widgets/user_profile_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
    required AuthProvider authProvider,
    Size size = const Size(1400, 1000),
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      ),
    );
  }

  group('Guest Mode Unit & Widget Tests', () {
    test('AuthProvider transitions correctly into and out of Guest Mode', () {
      final auth = AuthProvider();
      expect(auth.isGuest, isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.isAuthenticated, isFalse);

      auth.continueAsGuest();
      expect(auth.isGuest, isTrue);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.username, equals('Guest'));

      auth.clearLocalSession();
      expect(auth.isGuest, isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    testWidgets('LoginScreen displays Continue as Guest action and value proposition',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider();
      await tester.pumpWidget(
        buildTestApp(
          authProvider: auth,
          child: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.textContaining('Redact documents instantly without registering'), findsOneWidget);
      expect(find.textContaining('Want to keep your redaction history?'), findsOneWidget);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(auth.isGuest, isTrue);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('UserProfilePanel adapts appropriately for Guest sessions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider();
      auth.continueAsGuest();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: auth,
          child: const Center(child: UserProfilePanel()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest Session'), findsOneWidget);
      expect(find.text('Sign In to Account'), findsOneWidget);
      expect(find.text('Create Free Account'), findsOneWidget);
      expect(find.text('Exit Guest Mode'), findsOneWidget);
      expect(find.text('Why Create an Account?'), findsOneWidget);

      // Verify authenticated-only options are hidden
      expect(find.text('Manage Account'), findsNothing);
      expect(find.text('Change Password'), findsNothing);
    });

    testWidgets('AppDrawer displays Guest User banner and intercepts Redaction History',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider();
      auth.continueAsGuest();

      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1400, 1000)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(create: (_) => DocumentProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                key: scaffoldKey,
                drawer: const AppDrawer(currentRoute: '/dashboard'),
                body: const Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      scaffoldKey.currentState?.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('Ephemeral Session'), findsOneWidget);

      // Tap Redaction History in drawer
      await tester.tap(find.text('Redaction History'));
      await tester.pumpAndSettle();

      // Intercept modal should be displayed
      expect(find.text('Redaction History'), findsWidgets);
      expect(find.textContaining('Sign in to view your redaction history.'), findsOneWidget);
      expect(find.textContaining('Guest documents are ephemeral and not saved to the database'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
