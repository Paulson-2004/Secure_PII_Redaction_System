import 'dart:convert';
import 'package:flutter/material.dart';

/// Predefined standard document page presets.
class PdfPagePreset {
  final String key;
  final String label;
  final Size size;

  const PdfPagePreset({
    required this.key,
    required this.label,
    required this.size,
  });

  static const a4Portrait = PdfPagePreset(
    key: 'a4_portrait',
    label: 'A4 Portrait',
    size: Size(595.28, 841.89),
  );

  static const a4Landscape = PdfPagePreset(
    key: 'a4_landscape',
    label: 'A4 Landscape',
    size: Size(841.89, 595.28),
  );

  static const letterPortrait = PdfPagePreset(
    key: 'letter_portrait',
    label: 'Letter Portrait',
    size: Size(612.0, 792.0),
  );

  static const letterLandscape = PdfPagePreset(
    key: 'letter_landscape',
    label: 'Letter Landscape',
    size: Size(792.0, 612.0),
  );

  static const List<PdfPagePreset> all = [
    a4Portrait,
    a4Landscape,
    letterPortrait,
    letterLandscape,
  ];

  static PdfPagePreset fromKey(String key) {
    return all.firstWhere(
      (p) => p.key == key,
      orElse: () => a4Portrait,
    );
  }

  /// Returns a concise human-readable description for a given page Size.
  static String describeSize(Size size) {
    final w = size.width;
    final h = size.height;
    if ((w - 595.28).abs() < 10 && (h - 841.89).abs() < 10) return 'A4 Portrait';
    if ((w - 841.89).abs() < 10 && (h - 595.28).abs() < 10) return 'A4 Landscape';
    if ((w - 612.0).abs() < 10 && (h - 792.0).abs() < 10) return 'Letter Portrait';
    if ((w - 792.0).abs() < 10 && (h - 612.0).abs() < 10) return 'Letter Landscape';
    if (w > h) return '${w.round()}×${h.round()} Landscape';
    if (w < h) return '${w.round()}×${h.round()} Portrait';
    return '${w.round()}×${h.round()} Square';
  }
}

/// Lightweight parser for extracting per-page geometry (MediaBox / CropBox and Rotate)
/// directly from raw PDF bytes without third-party native libraries.
class PdfPageGeometryParser {
  /// Extracts page dimensions for each page in the PDF (1-indexed).
  ///
  /// Inspects:
  /// 1. Page dictionary /MediaBox or /CropBox
  /// 2. Parent /Pages catalog default /MediaBox
  /// 3. Page /Rotate (90, 180, 270)
  static Map<int, Size> parsePageSizes(List<int> bytes) {
    final Map<int, Size> result = {};
    if (bytes.isEmpty) return result;

    try {
      // Decode bytes as latin1 to preserve byte-level ASCII offsets
      final String content = latin1.decode(bytes, allowInvalid: true);

      // Check for document-level /Pages MediaBox
      Size? globalMediaBox;
      final globalMatch = RegExp(
        r'/Type\s*/Pages.*?/MediaBox\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]',
        dotAll: true,
      ).firstMatch(content);
      if (globalMatch != null) {
        final x1 = double.tryParse(globalMatch.group(1)!) ?? 0;
        final y1 = double.tryParse(globalMatch.group(2)!) ?? 0;
        final x2 = double.tryParse(globalMatch.group(3)!) ?? 595.28;
        final y2 = double.tryParse(globalMatch.group(4)!) ?? 841.89;
        final w = (x2 - x1).abs();
        final h = (y2 - y1).abs();
        if (w > 0 && h > 0) {
          globalMediaBox = Size(w, h);
        }
      }

      // Regex matching individual page objects
      final pageObjectRegex = RegExp(
        r'\d+\s+\d+\s+obj\s*<<([^>]*(?:(?:/[A-Za-z0-9]+(?:\s*\[[^\]]*\]|\s*<[^>]*>|\s*[^\s/>]+)?)[^>]*)*)>>\s*endobj',
        dotAll: true,
      );

      int pageIndex = 1;
      for (final match in pageObjectRegex.allMatches(content)) {
        final String objText = match.group(1) ?? '';
        final isPage = RegExp(r'/Type\s*/Page\b').hasMatch(objText) &&
            !RegExp(r'/Type\s*/Pages\b').hasMatch(objText);
        if (!isPage) continue;

        // Check for MediaBox or CropBox
        final boxMatch = RegExp(
          r'/(?:MediaBox|CropBox)\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]',
        ).firstMatch(objText);

        final rotMatch = RegExp(r'/Rotate\s*(\d+)').firstMatch(objText);
        final rot = rotMatch != null ? (int.tryParse(rotMatch.group(1)!) ?? 0) : 0;

        double w, h;
        if (boxMatch != null) {
          final x1 = double.tryParse(boxMatch.group(1)!) ?? 0;
          final y1 = double.tryParse(boxMatch.group(2)!) ?? 0;
          final x2 = double.tryParse(boxMatch.group(3)!) ?? 595.28;
          final y2 = double.tryParse(boxMatch.group(4)!) ?? 841.89;
          w = (x2 - x1).abs();
          h = (y2 - y1).abs();
        } else if (globalMediaBox != null) {
          w = globalMediaBox.width;
          h = globalMediaBox.height;
        } else {
          w = 595.28;
          h = 841.89;
        }

        // Apply page rotation (90 or 270 degrees inverts effective aspect ratio)
        if (rot == 90 || rot == 270) {
          final temp = w;
          w = h;
          h = temp;
        }

        if (w > 0 && h > 0) {
          result[pageIndex] = Size(w, h);
          pageIndex++;
        }
      }
    } catch (e) {
      debugPrint('Error parsing PDF page sizes: $e');
    }

    return result;
  }
}
