import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pii_redaction/models/detection_result.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/result_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';

class TestDocumentProvider extends DocumentProvider {
  final DetectionResult? _testResult;
  TestDocumentProvider(this._testResult);

  @override
  DetectionResult? get lastResult => _testResult;
}

void main() {
  final sampleResult = DetectionResult(
    status: 'success',
    filename: 'redacted_sample_aadhaar.pdf',
    redactedFilename: 'redacted_sample_aadhaar.pdf',
    originalFilename: 'sample_aadhaar.pdf',
    docType: 'aadhaar',
    action: 'redact',
    piiCount: 3,
    piiDetected: ['AADHAAR_NUMBER', 'PERSON', 'DATE_OF_BIRTH'],
    redactionSummary: 'Redacted 3 PII entities under UIDAI policy guidelines.',
    processedAt: '2026-09-29 11:45:00',
    piiDetails: [
      PiiEntityDetail(
        type: 'AADHAAR_NUMBER',
        confidence: 0.94,
        decision: 'FULL_REDACT',
        regulation: 'UIDAI guidance',
        source: 'REGEX',
        severity: 'CRITICAL',
      ),
    ],
  );

  Widget buildTestWidget({required double width, required double height}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<DocumentProvider>(
          create: (_) => TestDocumentProvider(sampleResult),
          child: const ResultScreen(),
        ),
      ),
    );
  }

  testWidgets(
      'ResultScreen renders without BoxConstraints error at Desktop (1200px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(width: 1200, height: 900));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Processing Result'), findsOneWidget);
    expect(find.text('Download Redacted File'), findsOneWidget);
  });

  testWidgets(
      'ResultScreen renders without BoxConstraints error at Tablet (768px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(width: 768, height: 1024));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Processing Result'), findsOneWidget);
    expect(find.text('Download Redacted File'), findsOneWidget);
  });

  testWidgets(
      'ResultScreen renders without BoxConstraints error at Mobile (360px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(width: 360, height: 640));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Processing Result'), findsOneWidget);
    expect(find.text('Download Redacted File'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('AADHAAR_NUMBER'), findsOneWidget);
    expect(find.text('Policy: UIDAI guidance'), findsOneWidget);
  });

  testWidgets(
      'ResultScreen renders without BoxConstraints error at Ultra-Narrow Mobile (320px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(width: 320, height: 568));
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull);
    expect(find.text('Processing Result'), findsOneWidget);
    expect(find.text('Download Redacted File'), findsOneWidget);
  });
}
