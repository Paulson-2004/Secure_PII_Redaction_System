import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/detection_result.dart';
import '../models/audit_log.dart';

class DocumentProvider extends ChangeNotifier {
  bool _isProcessing = false;
  String _errorMessage = '';
  DetectionResult? _lastResult;
  List<AuditLog> _auditLogs = [];
  bool _isLoadingLogs = false;
  String _auditLogsError = '';

  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  DetectionResult? get lastResult => _lastResult;
  List<AuditLog> get auditLogs => _auditLogs;
  bool get isLoadingLogs => _isLoadingLogs;
  String get auditLogsError => _auditLogsError;

  Future<bool> processDocument({
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
    required String action,
    String detectionMode = 'automatic',
    List<Map<String, dynamic>>? manualRegions,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.processDocument(
        file: file,
        fileBytes: fileBytes,
        fileName: fileName,
        docType: docType,
        action: action,
        detectionMode: detectionMode,
        manualRegions: manualRegions,
      );
      _lastResult = DetectionResult.fromJson(response);
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.startsWith('Please select a file') ||
          message.startsWith('Please reselect the file')) {
        _errorMessage = message;
      } else if (message.startsWith('Processing timed out')) {
        _errorMessage = 'Processing took too long. Please try again.';
      } else {
        _errorMessage =
            'We could not process this document. Check your connection and try again.';
      }
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAuditLogs() async {
    _isLoadingLogs = true;
    _auditLogsError = '';
    notifyListeners();
    try {
      final data = await ApiService.getAuditLogs();
      _auditLogs = data
          .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
          .toList();
      _auditLogsError = '';
    } catch (_) {
      _auditLogsError =
          'History could not be loaded. Check your connection and try again.';
    }
    _isLoadingLogs = false;
    notifyListeners();
  }

  void clearResult() {
    _lastResult = null;
    notifyListeners();
  }
}
