class DetectionResult {
  final String status;
  final String filename;
  final String redactedFilename;
  final String originalFilename;
  final String docType;
  final String action;
  final int piiCount;
  final List<String> piiDetected;
  final String redactionSummary;
  final String processedAt;

  DetectionResult({
    required this.status,
    required this.filename,
    required this.redactedFilename,
    required this.originalFilename,
    required this.docType,
    required this.action,
    required this.piiCount,
    required this.piiDetected,
    required this.redactionSummary,
    required this.processedAt,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final piiDetectedValue = data['pii_detected'];
    final piiDetected = piiDetectedValue is List
        ? piiDetectedValue.map((item) => item.toString()).toList()
        : <String>[];

    return DetectionResult(
      status: data['status']?.toString() ?? 'success',
      filename: data['filename']?.toString() ?? '',
      redactedFilename: data['redacted_filename']?.toString() ?? '',
      originalFilename: data['original_filename']?.toString() ?? '',
      docType: data['doc_type']?.toString() ?? 'general',
      action: data['action']?.toString() ?? 'redact',
      piiCount: (data['total_pii_found'] as num?)?.toInt() ?? piiDetected.length,
      piiDetected: piiDetected,
      redactionSummary: data['redaction_summary']?.toString() ?? '',
      processedAt: data['processed_at']?.toString() ?? '',
    );
  }
}
