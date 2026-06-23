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

  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  DetectionResult? get lastResult => _lastResult;
  List<AuditLog> get auditLogs => _auditLogs;
  bool get isLoadingLogs => _isLoadingLogs;

  Future<bool> processDocument({
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
    required String action,
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
      );
      _lastResult = DetectionResult.fromJson(response);
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAuditLogs() async {
    _isLoadingLogs = true;
    notifyListeners();
    try {
      final data = await ApiService.getAuditLogs();
      _auditLogs = data
          .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _auditLogs = [];
    }
    _isLoadingLogs = false;
    notifyListeners();
  }

  void clearResult() {
    _lastResult = null;
    notifyListeners();
  }
}
