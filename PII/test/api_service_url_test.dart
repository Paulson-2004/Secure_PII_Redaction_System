import 'package:flutter_test/flutter_test.dart';
import 'package:pii_redaction/services/api_service.dart';

void main() {
  group('ApiService URL Configuration Tests', () {
    test('production and local API URLs are correctly defined', () {
      expect(
        ApiService.productionApiUrl,
        'https://secure-pii-redaction-system.onrender.com',
      );
      expect(
        ApiService.localApiUrl,
        'http://127.0.0.1:5000',
      );
    });

    test('getDownloadUrl appends /api/download/<filename> to baseUrl', () {
      final downloadUrl = ApiService.getDownloadUrl('sample_redacted.pdf');
      expect(downloadUrl, '${ApiService.baseUrl}/api/download/sample_redacted.pdf');
      expect(downloadUrl.contains('//api/download'), isFalse);
    });
  });
}
