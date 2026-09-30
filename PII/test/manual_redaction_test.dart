import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pii_redaction/models/image_display_geometry.dart';
import 'package:pii_redaction/models/manual_region.dart';
import 'package:pii_redaction/models/pdf_page_geometry.dart';
import 'package:pii_redaction/providers/auth_provider.dart';
import 'package:pii_redaction/providers/document_provider.dart';
import 'package:pii_redaction/screens/dashboard_screen.dart';
import 'package:pii_redaction/theme/app_theme.dart';

class _TestRegion {
  final String name;
  final double x;
  final double y;
  final double w;
  final double h;
  const _TestRegion(this.name, this.x, this.y, this.w, this.h);
}

class _TestZone {
  final String name;
  final double pxX;
  final double pxY;
  final double pxW;
  final double pxH;
  const _TestZone(this.name, this.pxX, this.pxY, this.pxW, this.pxH);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
  }) {
    final auth = AuthProvider();
    auth.continueAsGuest();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Manual Redaction Model & Studio Tests', () {
    test('ManualRegion model serializes and deserializes accurately', () {
      final region = ManualRegion(
        id: 1,
        page: 2,
        x: 0.123456,
        y: 0.234567,
        width: 0.345678,
        height: 0.456789,
        action: 'mask',
      );

      final json = region.toJson();
      expect(json['page'], equals(2));
      expect(json['x'], equals(0.1235));
      expect(json['y'], equals(0.2346));
      expect(json['width'], equals(0.3457));
      expect(json['height'], equals(0.4568));
      expect(json['action'], equals('mask'));

      final reconstructed = ManualRegion.fromJson(json, id: 99);
      expect(reconstructed.id, equals(99));
      expect(reconstructed.page, equals(2));
      expect(reconstructed.x, equals(0.1235));
      expect(reconstructed.action, equals('mask'));
    });

    testWidgets('DashboardScreen renders all 3 detection modes and regulatory notice',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const DashboardScreen()));
      await tester.pumpAndSettle();

      // Check detection mode titles
      expect(find.text('Automatic PII Detection'), findsOneWidget);
      expect(find.text('Manual Selection'), findsOneWidget);
      expect(find.text('Automatic + Manual'), findsOneWidget);

      // Check authoritative regulatory footer
      expect(find.textContaining('Authoritative Privacy & Security Policy Corpus'), findsOneWidget);
      expect(find.textContaining('not legal advice'), findsOneWidget);
    });

    testWidgets('Switching to Manual Selection reveals Interactive Manual Selection Studio',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const DashboardScreen()));
      await tester.pumpAndSettle();

      // By default in Automatic mode, manual selection canvas is not shown
      expect(find.text('Interactive Manual Selection Canvas'), findsNothing);

      // Scroll to and tap on Manual Selection
      final manualModeFinder = find.text('Manual Selection');
      await tester.ensureVisible(manualModeFinder);
      await tester.pumpAndSettle();
      await tester.tap(manualModeFinder);
      await tester.pumpAndSettle();

      // Canvas header and page controls now appear
      expect(find.text('Interactive Manual Selection Canvas'), findsOneWidget);
      expect(find.text('Target Page:'), findsOneWidget);
      expect(find.text('Page 1'), findsWidgets);

      // Switch to Automatic + Manual mode
      final autoManualFinder = find.text('Automatic + Manual');
      await tester.ensureVisible(autoManualFinder);
      await tester.pumpAndSettle();
      await tester.tap(autoManualFinder);
      await tester.pumpAndSettle();
      expect(find.text('Interactive Manual Selection Canvas'), findsOneWidget);
    });
  });

  group('ImageDisplayGeometry Unit Tests', () {
    test('Calculates exact horizontal letterboxing for 1600x1008 image in 720x360 container', () {
      final geometry = ImageDisplayGeometry(
        sourceSize: const Size(1600, 1008),
        containerSize: const Size(720, 360),
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );

      // Expected aspect ratio: 1600 / 1008 = 1.5873015873
      // In 720x360 container: height is constrained to 360, width is 360 * 1600 / 1008 = 571.4285714
      expect(geometry.fittedSize.height, closeTo(360.0, 0.001));
      expect(geometry.fittedSize.width, closeTo(571.4285, 0.01));

      // Letterbox horizontal offset: (720 - 571.4285714) / 2 = 74.2857
      expect(geometry.imageRect.left, closeTo(74.2857, 0.01));
      expect(geometry.imageRect.top, equals(0.0));
      expect(geometry.imageRect.width, closeTo(571.4285, 0.01));
      expect(geometry.imageRect.height, equals(360.0));
    });

    test('Calculates exact vertical letterboxing for 800x400 image in 400x600 container', () {
      final geometry = ImageDisplayGeometry(
        sourceSize: const Size(800, 400),
        containerSize: const Size(400, 600),
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );

      // In 400x600 container: width is constrained to 400, height is 400 * 400 / 800 = 200
      expect(geometry.fittedSize.width, equals(400.0));
      expect(geometry.fittedSize.height, equals(200.0));

      // Letterbox vertical offset: (600 - 200) / 2 = 200.0
      expect(geometry.imageRect.left, equals(0.0));
      expect(geometry.imageRect.top, equals(200.0));
      expect(geometry.imageRect.width, equals(400.0));
      expect(geometry.imageRect.height, equals(200.0));
    });

    test('Round-trip geometry invariant holds across Region 1, Region 2, and Region 3', () {
      final geometry = ImageDisplayGeometry(
        sourceSize: const Size(1600, 1008),
        containerSize: const Size(720, 360),
      );

      const regions = [
        _TestRegion('Region 1', 0.10, 0.20, 0.20, 0.30),
        _TestRegion('Region 2', 0.50, 0.40, 0.10, 0.08),
        _TestRegion('Region 3', 0.80, 0.80, 0.15, 0.10),
      ];

      for (final r in regions) {
        // 1. Normalized -> Local container display Rect
        final localRect = geometry.normalizedToLocalRect(r.x, r.y, r.w, r.h);

        // Verify localRect sits entirely within imageRect
        expect(localRect.left, greaterThanOrEqualTo(geometry.imageRect.left - 0.001));
        expect(localRect.right, lessThanOrEqualTo(geometry.imageRect.right + 0.001));
        expect(localRect.top, greaterThanOrEqualTo(geometry.imageRect.top - 0.001));
        expect(localRect.bottom, lessThanOrEqualTo(geometry.imageRect.bottom + 0.001));

        // 2. Drag interaction on those local pixels -> Normalized Rect
        final normResult = geometry.selectionToNormalizedRect(
          Offset(localRect.left, localRect.top),
          Offset(localRect.right, localRect.bottom),
        );

        expect(normResult.left, closeTo(r.x, 0.0001), reason: '${r.name} normX mismatch');
        expect(normResult.top, closeTo(r.y, 0.0001), reason: '${r.name} normY mismatch');
        expect(normResult.width, closeTo(r.w, 0.0001), reason: '${r.name} normW mismatch');
        expect(normResult.height, closeTo(r.h, 0.0001), reason: '${r.name} normH mismatch');
      }
    });

    test('Pointer clamping cleanly ignores letterbox regions and clamps out-of-bounds drags', () {
      final geometry = ImageDisplayGeometry(
        sourceSize: const Size(1600, 1008),
        containerSize: const Size(720, 360),
      );

      // Drag entirely within left letterbox margin (x in [0, 74.28])
      final leftMarginRect = geometry.selectionToNormalizedRect(
        const Offset(10, 50),
        const Offset(60, 150),
      );
      expect(leftMarginRect.width, equals(0.0), reason: 'Selection inside margin should have 0 width');

      // Drag entirely within right letterbox margin (x in [645.71, 720])
      final rightMarginRect = geometry.selectionToNormalizedRect(
        const Offset(660, 50),
        const Offset(710, 150),
      );
      expect(rightMarginRect.width, equals(0.0), reason: 'Selection inside margin should have 0 width');

      // Drag from outside container bounds (-100, -100) to (1000, 500)
      final clampedFull = geometry.selectionToNormalizedRect(
        const Offset(-100, -100),
        const Offset(1000, 500),
      );
      expect(clampedFull.left, equals(0.0));
      expect(clampedFull.top, equals(0.0));
      expect(clampedFull.width, equals(1.0));
      expect(clampedFull.height, equals(1.0));
    });

    test('UI pointer rectangle -> normalized -> backend source pixels for Aadhaar Card zones', () {
      const sourceWidth = 1600.0;
      const sourceHeight = 1008.0;

      final geometry = ImageDisplayGeometry(
        sourceSize: const Size(sourceWidth, sourceHeight),
        containerSize: const Size(720, 360),
      );

      const aadhaarZones = [
        _TestZone('Photo Zone', 80.0, 240.0, 320.0, 420.0),
        _TestZone('Date of Birth (DOB) Zone', 450.0, 480.0, 260.0, 60.0),
        _TestZone('Aadhaar Number Zone', 450.0, 700.0, 580.0, 75.0),
        _TestZone('Small 20x20 Region', 500.0, 300.0, 20.0, 20.0),
      ];

      for (final zone in aadhaarZones) {
        // 1. Calculate true normalized representation
        final normX = zone.pxX / sourceWidth;
        final normY = zone.pxY / sourceHeight;
        final normW = zone.pxW / sourceWidth;
        final normH = zone.pxH / sourceHeight;

        // 2. Render position on user display
        final localRect = geometry.normalizedToLocalRect(normX, normY, normW, normH);

        // 3. User draws selection over that zone on screen
        final userDrawn = geometry.selectionToNormalizedRect(
          localRect.topLeft,
          localRect.bottomRight,
        );

        // 4. Backend converts normalized coordinates back to source pixels
        final backendSourceRect = geometry.normalizedToSourcePixels(
          userDrawn.left,
          userDrawn.top,
          userDrawn.width,
          userDrawn.height,
        );

        expect(
          backendSourceRect.left.round(),
          equals(zone.pxX.round()),
          reason: '${zone.name} pixel X must match source pixels with zero horizontal shift',
        );
        expect(
          backendSourceRect.top.round(),
          equals(zone.pxY.round()),
          reason: '${zone.name} pixel Y must match source pixels with zero vertical shift',
        );
        expect(
          backendSourceRect.width.round(),
          equals(zone.pxW.round()),
          reason: '${zone.name} pixel width must match source width',
        );
        expect(
          backendSourceRect.height.round(),
          equals(zone.pxH.round()),
          reason: '${zone.name} pixel height must match source height',
        );
      }
    });
  });

  group('PDF Page Geometry & Aspect Ratio Tests', () {
    Uint8List makePdfWithMediaBox(String mediaBox, {int? rotate}) {
      final rotStr = rotate != null ? '/Rotate $rotate' : '';
      final s = '''
%PDF-1.4
1 0 obj <</Type /Catalog /Pages 2 0 R>> endobj
2 0 obj <</Type /Pages /Kids [3 0 R] /Count 1>> endobj
3 0 obj <</Type /Page /Parent 2 0 R /MediaBox $mediaBox $rotStr>> endobj
xref
trailer <</Root 1 0 R>>
%%EOF
''';
      return Uint8List.fromList(s.codeUnits);
    }

    Uint8List makeMultiPagePdf() {
      const s = '''
%PDF-1.4
1 0 obj <</Type /Catalog /Pages 2 0 R>> endobj
2 0 obj <</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>> endobj
3 0 obj <</Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89]>> endobj
4 0 obj <</Type /Page /Parent 2 0 R /MediaBox [0 0 841.89 595.28]>> endobj
xref
trailer <</Root 1 0 R>>
%%EOF
''';
      return Uint8List.fromList(s.codeUnits);
    }

    test('PdfPagePreset defines standard dimensional constants', () {
      expect(PdfPagePreset.a4Portrait.size.width, closeTo(595.28, 0.01));
      expect(PdfPagePreset.a4Portrait.size.height, closeTo(841.89, 0.01));
      expect(PdfPagePreset.a4Landscape.size.width, closeTo(841.89, 0.01));
      expect(PdfPagePreset.a4Landscape.size.height, closeTo(595.28, 0.01));
      expect(PdfPagePreset.letterPortrait.size.width, equals(612.0));
      expect(PdfPagePreset.letterPortrait.size.height, equals(792.0));
      expect(PdfPagePreset.letterLandscape.size.width, equals(792.0));
      expect(PdfPagePreset.letterLandscape.size.height, equals(612.0));

      expect(PdfPagePreset.fromKey('a4_landscape'), equals(PdfPagePreset.a4Landscape));
      expect(PdfPagePreset.fromKey('letter_portrait'), equals(PdfPagePreset.letterPortrait));

      expect(PdfPagePreset.describeSize(PdfPagePreset.a4Portrait.size), equals('A4 Portrait'));
      expect(PdfPagePreset.describeSize(PdfPagePreset.a4Landscape.size), equals('A4 Landscape'));
      expect(PdfPagePreset.describeSize(PdfPagePreset.letterPortrait.size), equals('Letter Portrait'));
      expect(PdfPagePreset.describeSize(PdfPagePreset.letterLandscape.size), equals('Letter Landscape'));
      expect(PdfPagePreset.describeSize(const Size(300, 200)), equals('300×200 Landscape'));
      expect(PdfPagePreset.describeSize(const Size(200, 300)), equals('200×300 Portrait'));
    });

    test('PdfPageGeometryParser extracts exact dimensions for standard page formats', () {
      // 1. A4 Portrait
      final a4PortraitBytes = makePdfWithMediaBox('[0 0 595.28 841.89]');
      final a4PortraitMap = PdfPageGeometryParser.parsePageSizes(a4PortraitBytes);
      expect(a4PortraitMap.length, equals(1));
      expect(a4PortraitMap[1]!.width, closeTo(595.28, 0.01));
      expect(a4PortraitMap[1]!.height, closeTo(841.89, 0.01));
      expect(a4PortraitMap[1]!.width, lessThan(a4PortraitMap[1]!.height));

      // 2. A4 Landscape
      final a4LandscapeBytes = makePdfWithMediaBox('[0 0 841.89 595.28]');
      final a4LandscapeMap = PdfPageGeometryParser.parsePageSizes(a4LandscapeBytes);
      expect(a4LandscapeMap[1]!.width, closeTo(841.89, 0.01));
      expect(a4LandscapeMap[1]!.height, closeTo(595.28, 0.01));
      expect(a4LandscapeMap[1]!.width, greaterThan(a4LandscapeMap[1]!.height));

      // 3. Letter Portrait
      final letterPortraitBytes = makePdfWithMediaBox('[0 0 612 792]');
      final letterPortraitMap = PdfPageGeometryParser.parsePageSizes(letterPortraitBytes);
      expect(letterPortraitMap[1]!.width, equals(612.0));
      expect(letterPortraitMap[1]!.height, equals(792.0));

      // 4. Letter Landscape
      final letterLandscapeBytes = makePdfWithMediaBox('[0 0 792 612]');
      final letterLandscapeMap = PdfPageGeometryParser.parsePageSizes(letterLandscapeBytes);
      expect(letterLandscapeMap[1]!.width, equals(792.0));
      expect(letterLandscapeMap[1]!.height, equals(612.0));

      // 5. Non-A4 Custom (300 x 200)
      final customBytes = makePdfWithMediaBox('[0 0 300 200]');
      final customMap = PdfPageGeometryParser.parsePageSizes(customBytes);
      expect(customMap[1]!.width, equals(300.0));
      expect(customMap[1]!.height, equals(200.0));

      // 6. Rotated Page (/Rotate 90)
      final rotBytes = makePdfWithMediaBox('[0 0 595.28 841.89]', rotate: 90);
      final rotMap = PdfPageGeometryParser.parsePageSizes(rotBytes);
      expect(rotMap[1]!.width, closeTo(841.89, 0.01), reason: '90-degree rotation must invert width/height');
      expect(rotMap[1]!.height, closeTo(595.28, 0.01));
    });

    test('PdfPageGeometryParser parses multi-page mixed portrait/landscape document', () {
      final multiPageBytes = makeMultiPagePdf();
      final pageMap = PdfPageGeometryParser.parsePageSizes(multiPageBytes);

      expect(pageMap.length, equals(2));
      // Page 1 is A4 Portrait
      expect(pageMap[1]!.width, closeTo(595.28, 0.01));
      expect(pageMap[1]!.height, closeTo(841.89, 0.01));
      expect(pageMap[1]!.width, lessThan(pageMap[1]!.height));

      // Page 2 is A4 Landscape
      expect(pageMap[2]!.width, closeTo(841.89, 0.01));
      expect(pageMap[2]!.height, closeTo(595.28, 0.01));
      expect(pageMap[2]!.width, greaterThan(pageMap[2]!.height));
    });

    test('ImageDisplayGeometry correctly adapts to A4 Portrait vs A4 Landscape vs Non-A4', () {
      const containerSize = Size(720, 360);

      // 1. A4 Portrait: height constrained to 360, width = 360 * 595.28 / 841.89 = 254.57
      final a4PGeometry = ImageDisplayGeometry(
        sourceSize: const Size(595.28, 841.89),
        containerSize: containerSize,
      );
      expect(a4PGeometry.fittedSize.height, equals(360.0));
      expect(a4PGeometry.fittedSize.width, closeTo(254.55, 0.05));
      expect(a4PGeometry.imageRect.left, closeTo(232.73, 0.05));

      // Verify drag round-trip on A4 Portrait
      final a4PLocal = a4PGeometry.normalizedToLocalRect(0.1, 0.2, 0.3, 0.4);
      final a4PNorm = a4PGeometry.selectionToNormalizedRect(a4PLocal.topLeft, a4PLocal.bottomRight);
      expect(a4PNorm.left, closeTo(0.1, 0.001));
      expect(a4PNorm.top, closeTo(0.2, 0.001));
      expect(a4PNorm.width, closeTo(0.3, 0.001));
      expect(a4PNorm.height, closeTo(0.4, 0.001));

      // 2. A4 Landscape: height constrained to 360, width = 360 * 841.89 / 595.28 = 509.10
      final a4LGeometry = ImageDisplayGeometry(
        sourceSize: const Size(841.89, 595.28),
        containerSize: containerSize,
      );
      expect(a4LGeometry.fittedSize.height, equals(360.0));
      expect(a4LGeometry.fittedSize.width, closeTo(509.10, 0.05));
      expect(a4LGeometry.imageRect.left, closeTo(105.45, 0.05));

      // Verify drag round-trip on A4 Landscape
      final a4LLocal = a4LGeometry.normalizedToLocalRect(0.1, 0.2, 0.3, 0.4);
      final a4LNorm = a4LGeometry.selectionToNormalizedRect(a4LLocal.topLeft, a4LLocal.bottomRight);
      expect(a4LNorm.left, closeTo(0.1, 0.001));
      expect(a4LNorm.top, closeTo(0.2, 0.001));
      expect(a4LNorm.width, closeTo(0.3, 0.001));
      expect(a4LNorm.height, closeTo(0.4, 0.001));

      // 3. Non-A4 Custom (300 x 200, aspect ratio 1.5): height 360, width 540, left margin 90.0
      final customGeometry = ImageDisplayGeometry(
        sourceSize: const Size(300, 200),
        containerSize: containerSize,
      );
      expect(customGeometry.fittedSize.height, equals(360.0));
      expect(customGeometry.fittedSize.width, equals(540.0));
      expect(customGeometry.imageRect.left, equals(90.0));

      final customLocal = customGeometry.normalizedToLocalRect(0.10, 0.20, 0.40, 0.30);
      final customNorm = customGeometry.selectionToNormalizedRect(customLocal.topLeft, customLocal.bottomRight);
      final backendSource = customGeometry.normalizedToSourcePixels(
        customNorm.left,
        customNorm.top,
        customNorm.width,
        customNorm.height,
      );

      // Backend conversion int(round(norm * 300)) = 30, int(round(norm * 200)) = 40
      expect(backendSource.left.round(), equals(30));
      expect(backendSource.top.round(), equals(40));
      expect(backendSource.width.round(), equals(120));
      expect(backendSource.height.round(), equals(60));
    });
  });
}
