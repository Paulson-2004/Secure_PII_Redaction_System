import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/models/audit_log.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/audit_logs_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';

class _AuthenticatedUser extends AuthProvider {
  @override
  bool get isGuest => false;

  @override
  bool get isAuthenticated => true;
}

class _RetryableHistoryProvider extends DocumentProvider {
  int requestCount = 0;
  bool _isLoading = false;
  String _error = '';
  List<AuditLog> _logs = const [];

  @override
  bool get isLoadingLogs => _isLoading;

  @override
  String get auditLogsError => _error;

  @override
  List<AuditLog> get auditLogs => _logs;

  @override
  Future<void> loadAuditLogs() async {
    requestCount++;
    _isLoading = true;
    _error = '';
    notifyListeners();
    await Future<void>.delayed(Duration.zero);

    _isLoading = false;
    if (requestCount == 1) {
      _error =
          'History could not be loaded. Check your connection and try again.';
    } else {
      _logs = [
        AuditLog(
          id: 17,
          filename: 'redacted_report.pdf',
          documentType: 'general',
          piiCount: 1,
          actionTaken: 'REDACTED',
          processingTime: 0.2,
          createdAt: '2026-10-01T09:00:00Z',
        ),
      ];
    }
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Audit history retry recovers from an error and displays loaded history',
      (tester) async {
    final history = _RetryableHistoryProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _AuthenticatedUser()),
          ChangeNotifierProvider<DocumentProvider>.value(value: history),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuditLogsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(history.requestCount, 1);
    expect(find.text('History is temporarily unavailable'), findsOneWidget);
    expect(find.text('No documents processed yet'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(history.requestCount, 2);
    expect(find.text('History is temporarily unavailable'), findsNothing);
    expect(find.text('No documents processed yet'), findsNothing);
    expect(find.text('redacted_report.pdf'), findsOneWidget);
  });
}
