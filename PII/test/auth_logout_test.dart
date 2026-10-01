import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/screens/login_screen.dart';
import 'package:pii_redaction/services/api_service.dart';

void main() {
  const sensitiveFailure = 'raw backend detail and private token';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'username': 'test-user',
      'email': 'test@example.com',
      'session_cookie': 'session-secret',
      'auth_token': 'auth-secret',
    });
    ApiService.clearSessionCookie();
    ApiService.clearAuthToken();
  });

  Future<AuthProvider> createAuthenticatedProvider() async {
    final auth = AuthProvider();
    await auth.initialize();
    expect(auth.isAuthenticated, isTrue);
    expect(ApiService.sessionCookie, 'session-secret');
    expect(ApiService.authToken, 'auth-secret');
    return auth;
  }

  test('successful logout clears local authentication and credentials',
      () async {
    final auth = await createAuthenticatedProvider();
    var requestCount = 0;

    await http.runWithClient(
      () => auth.logout(),
      () => MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/logout');
        return http.Response(
          jsonEncode({'message': 'Logged out'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(requestCount, 1);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.username, isEmpty);
    expect(auth.email, isEmpty);
    expect(auth.errorMessage, isEmpty);
    expect(prefs.getBool('isLoggedIn'), isNull);
    expect(prefs.getString('session_cookie'), isNull);
    expect(prefs.getString('auth_token'), isNull);
    expect(ApiService.sessionCookie, isNull);
    expect(ApiService.authToken, isNull);
  });

  testWidgets('network failure still signs out locally with a safe message',
      (tester) async {
    final auth = await createAuthenticatedProvider();
    var requestCount = 0;

    await http.runWithClient(
      () => auth.logout(),
      () => MockClient((_) async {
        requestCount++;
        throw StateError(sensitiveFailure);
      }),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(requestCount, 1);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.username, isEmpty);
    expect(auth.email, isEmpty);
    expect(prefs.getBool('isLoggedIn'), isNull);
    expect(prefs.getString('session_cookie'), isNull);
    expect(prefs.getString('auth_token'), isNull);
    expect(ApiService.sessionCookie, isNull);
    expect(ApiService.authToken, isNull);
    expect(auth.errorMessage, contains('Signed out on this device'));
    expect(auth.errorMessage, isNot(contains(sensitiveFailure)));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text(auth.errorMessage), findsOneWidget);
    expect(find.textContaining(sensitiveFailure), findsNothing);
  });
}
