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
    return AuditLog(
      id: json['id'] ?? 0,
      filename: json['filename'] ?? '',
      documentType: json['document_type'] ?? 'unknown',
      piiCount: json['pii_count'] ?? 0,
      actionTaken: json['action_taken'] ?? 'REDACTED',
      processingTime: (json['processing_time'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
