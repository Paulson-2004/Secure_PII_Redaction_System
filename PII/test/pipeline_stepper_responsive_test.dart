import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pii_redaction/theme/app_theme.dart';
import 'package:pii_redaction/widgets/pipeline_stepper.dart';

void main() {
  testWidgets(
      'Pipeline architecture presents five conceptual stages at all widths',
      (tester) async {
    const widths = [
      1440.0,
      1366.0,
      1280.0,
      1024.0,
      768.0,
      430.0,
      390.0,
      360.0,
    ];

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PipelineStepper(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OCR Extraction'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('PII Detection'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('Regex + NER'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('Hybrid Fusion'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('Policy Decision'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('Secure Redaction'), findsOneWidget,
          reason: 'viewport width $width');
      expect(find.text('Regex Detection'), findsNothing,
          reason: 'Regex and NER should be shown as one detection stage');
      expect(find.text('NER Recognition'), findsNothing,
          reason: 'Regex and NER should be shown as one detection stage');
      expect(tester.takeException(), isNull,
          reason: 'viewport width $width should not overflow or throw');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
