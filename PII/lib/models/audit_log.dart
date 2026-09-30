class AuditLog {
  final int id;
  final String filename;
  final String documentType;
  final int piiCount;
  final String actionTaken;
  final double processingTime;
  final String createdAt;

  AuditLog({
    required this.id,
    required this.filename,
    required this.documentType,
    required this.piiCount,
    required this.actionTaken,
    required this.processingTime,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final filename = json['filename'] ??
        json['original_filename'] ??
        'Document';
    final docType = json['document_type'] ?? json['doc_type'] ?? 'general';
    final piiCount = (json['pii_count'] as num?)?.toInt() ?? 0;
    final action = json['action_taken'] ?? json['status'] ?? 'PROCESSED';
    final procTime = (json['processing_time'] as num?)?.toDouble() ?? 0.0;
    final createdAt = json['created_at']?.toString() ?? '';

    return AuditLog(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      filename: filename.toString(),
      documentType: docType.toString(),
      piiCount: piiCount,
      actionTaken: action.toString().toUpperCase(),
      processingTime: procTime,
      createdAt: createdAt,
    );
  }
}
