import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/account_screen.dart';
import 'package:pii_redaction/screens/settings_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';
import 'package:pii_redaction/widgets/change_email_dialog.dart';
import 'package:pii_redaction/widgets/user_avatar_button.dart';
import 'package:pii_redaction/widgets/user_profile_panel.dart';

void main() {
  Widget buildTestApp(Widget child, {Size size = const Size(1200, 900)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(
              actions: const [UserAvatarButton()],
            ),
            body: child,
          ),
        ),
      ),
    );
  }

  testWidgets('UserProfilePanel renders Manage Account and Settings options',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(const UserProfilePanel()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage Account'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('Clicking Manage Account navigates to AccountScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(const SizedBox()),
    );
    await tester.pumpAndSettle();

    // Open UserProfilePanel via UserAvatarButton
    await tester.tap(find.byType(UserAvatarButton));
    await tester.pumpAndSettle();

    expect(find.text('Manage Account'), findsOneWidget);

    // Tap Manage Account
    await tester.tap(find.text('Manage Account'));
    await tester.pumpAndSettle();

    // Verify AccountScreen is rendered
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Manage Account'), findsOneWidget); // AppBar title
    expect(find.text('Security Credentials & Authentication'), findsOneWidget);

    // Verify back navigation works
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
    }
  });

  testWidgets('Clicking Settings navigates to SettingsScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(const SizedBox()),
    );
    await tester.pumpAndSettle();

    // Open UserProfilePanel via UserAvatarButton
    await tester.tap(find.byType(UserAvatarButton));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    // Tap Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify SettingsScreen is rendered
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget); // AppBar title
    expect(find.text('Security & Access Credentials'), findsOneWidget);
    expect(find.text('Backend Connectivity & Engine Health'), findsOneWidget);

    // Verify back navigation works
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
    }
  });

  testWidgets('AccountScreen renders across viewport sizes without error',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(
      buildTestApp(const AccountScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);

    // Test mobile width
    await tester.binding.setSurfaceSize(const Size(375, 667));
    await tester.pumpWidget(
      buildTestApp(const AccountScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen renders across viewport sizes without error',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(
      buildTestApp(const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    // Test mobile width
    await tester.binding.setSurfaceSize(const Size(375, 667));
    await tester.pumpWidget(
      buildTestApp(const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('ChangeEmailDialog renders informative policy notice',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(const ChangeEmailDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Change Email Address'), findsOneWidget);
    expect(find.text('Current Registered Email'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Manage Account'), findsOneWidget);
  });
}
