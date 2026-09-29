class PiiEntityDetail {
  final String type;
  final double confidence;
  final String decision;
  final String regulation;
  final int? page;
  final String source;
  final String severity;

  PiiEntityDetail({
    required this.type,
    required this.confidence,
    required this.decision,
    required this.regulation,
    this.page,
    required this.source,
    required this.severity,
  });

  factory PiiEntityDetail.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'PII';
    final conf = (json['confidence'] as num?)?.toDouble() ?? 0.85;
    final dec = json['decision']?.toString() ?? 'FULL_REDACT';
    final reg = json['regulation']?.toString() ?? 'DPDP Act 2023';
    final page = (json['page'] as num?)?.toInt();

    // Source fallback logic based on entity classification if not explicitly present
    String src = json['source']?.toString() ?? '';
    if (src.isEmpty) {
      if (type.contains('AADHAAR') ||
          type.contains('PAN') ||
          type.contains('PHONE') ||
          type.contains('EMAIL') ||
          type.contains('VOTER') ||
          type.contains('DRIVING')) {
        src = 'REGEX';
      } else {
        src = 'NER';
      }
    }

    // Severity calculation
    String sev = json['severity']?.toString() ?? '';
    if (sev.isEmpty) {
      if (type.contains('AADHAAR') ||
          type.contains('PAN') ||
          type.contains('CARD') ||
          type.contains('ACCOUNT')) {
        sev = 'CRITICAL';
      } else if (type.contains('PHONE') ||
          type.contains('EMAIL') ||
          type.contains('PERSON') ||
          type.contains('NAME')) {
        sev = 'HIGH';
      } else if (type.contains('DOB') ||
          type.contains('DATE') ||
          type.contains('ADDRESS')) {
        sev = 'MEDIUM';
      } else {
        sev = 'LOW';
      }
    }

    return PiiEntityDetail(
      type: type,
      confidence: conf,
      decision: dec,
      regulation: reg.isNotEmpty ? reg : 'General Privacy Practice',
      page: page,
      source: src.toUpperCase(),
      severity: sev.toUpperCase(),
    );
  }
}

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

  // Rich metrics from backend /api/process
  final int fullRedacted;
  final int partialMasked;
  final int keptCount;
  final int regexHits;
  final int nerHits;
  final int hybridHits;
  final double averageConfidence;
  final double processingTime;
  final int pageCount;
  final String extractedTextPreview;
  final List<PiiEntityDetail> piiDetails;

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
    this.fullRedacted = 0,
    this.partialMasked = 0,
    this.keptCount = 0,
    this.regexHits = 0,
    this.nerHits = 0,
    this.hybridHits = 0,
    this.averageConfidence = 0.85,
    this.processingTime = 0.0,
    this.pageCount = 1,
    this.extractedTextPreview = '',
    this.piiDetails = const [],
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final piiDetectedValue = data['pii_detected'];
    final piiDetected = piiDetectedValue is List
        ? piiDetectedValue.map((item) => item.toString()).toList()
        : <String>[];

    // Parse PII Details
    final detailsRaw = data['pii_details'];
    List<PiiEntityDetail> piiDetails = [];
    if (detailsRaw is List) {
      piiDetails = detailsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => PiiEntityDetail.fromJson(e))
          .toList();
    } else if (piiDetected.isNotEmpty) {
      // Fallback synthetic details if pii_details was omitted
      piiDetails = piiDetected
          .map((t) => PiiEntityDetail(
                type: t,
                confidence: 0.90,
                decision: 'FULL_REDACT',
                regulation: 'DPDP Act 2023',
                source: t.contains('AADHAAR') || t.contains('PAN') ? 'REGEX' : 'NER',
                severity: t.contains('AADHAAR') || t.contains('PAN') ? 'CRITICAL' : 'HIGH',
              ))
          .toList();
    }

    // Parse stats
    final stats = data['detection_stats'] is Map<String, dynamic>
        ? data['detection_stats'] as Map<String, dynamic>
        : <String, dynamic>{};

    final redactionSummaryDict = data['redaction_details'] is Map<String, dynamic>
        ? data['redaction_details'] as Map<String, dynamic>
        : <String, dynamic>{};

    final totalFound = (data['total_pii_found'] as num?)?.toInt() ??
        (stats['total_pii_found'] as num?)?.toInt() ??
        (stats['total_detected'] as num?)?.toInt() ??
        piiDetected.length;

    final regHits = (stats['regex_detections'] as num?)?.toInt() ??
        (stats['regex_hits'] as num?)?.toInt() ??
        (stats['regex_only'] as num?)?.toInt() ??
        0;

    final nHits = (stats['ner_detections'] as num?)?.toInt() ??
        (stats['ner_hits'] as num?)?.toInt() ??
        (stats['ner_only'] as num?)?.toInt() ??
        0;

    final hHits = (stats['hybrid_confirmed'] as num?)?.toInt() ??
        (stats['hybrid_hits'] as num?)?.toInt() ??
        0;

    final avgConf = (stats['average_confidence'] as num?)?.toDouble() ??
        (stats['avg_confidence'] as num?)?.toDouble() ??
        0.86;

    final procTime = (data['processing_time'] as num?)?.toDouble() ?? 0.0;
    final pages = (data['page_count'] as num?)?.toInt() ?? 1;

    final fullRedact = (redactionSummaryDict['full_redacted'] as num?)?.toInt() ??
        (data['action'] == 'redact' ? totalFound : 0);
    final partMask = (redactionSummaryDict['partial_masked'] as num?)?.toInt() ??
        (data['action'] == 'mask' ? totalFound : 0);
    final kept = (redactionSummaryDict['kept'] as num?)?.toInt() ?? 0;

    return DetectionResult(
      status: data['status']?.toString() ?? 'success',
      filename: data['filename']?.toString() ?? '',
      redactedFilename: data['redacted_filename']?.toString() ?? '',
      originalFilename: data['original_filename']?.toString() ?? '',
      docType: data['doc_type']?.toString() ?? 'general',
      action: data['action']?.toString() ?? 'redact',
      piiCount: totalFound,
      piiDetected: piiDetected,
      redactionSummary: data['redaction_summary']?.toString() ?? '',
      processedAt: data['processed_at']?.toString() ?? '',
      fullRedacted: fullRedact,
      partialMasked: partMask,
      keptCount: kept,
      regexHits: regHits,
      nerHits: nHits,
      hybridHits: hHits,
      averageConfidence: avgConf,
      processingTime: procTime,
      pageCount: pages,
      extractedTextPreview: data['extracted_text_preview']?.toString() ?? '',
      piiDetails: piiDetails,
    );
  }
}
