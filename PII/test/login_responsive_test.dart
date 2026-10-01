import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/screens/login_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login content stays within phone and desktop viewports',
      (tester) async {
    final auth = AuthProvider();
    const widths = [320.0, 360.0, 390.0, 430.0, 768.0, 1440.0];

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final username = find.byType(TextFormField).first;
      expect(tester.getRect(username).left, greaterThanOrEqualTo(24),
          reason: 'viewport width $width');
      expect(tester.getRect(username).right, lessThanOrEqualTo(width - 24),
          reason: 'viewport width $width');
      expect(tester.takeException(), isNull,
          reason: 'viewport width $width should not overflow or throw');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
