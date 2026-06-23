import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'web_download_stub.dart'
  if (dart.library.html) 'web_download_web.dart';

class ApiService {
  // Override with --dart-define=API_BASE_URL=http://<host>:5000 when needed.
  // Defaults are chosen per platform so the app works on emulators and local desktop.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }

    if (Platform.isIOS) {
      return 'http://localhost:5000';
    }

    return 'http://127.0.0.1:5000';
  }
  static const String fingerprintToken = 'device_fingerprint_token';
  static String? _sessionCookieValue;
  static String? _authTokenValue;

  static Map<String, String> get _defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (!kIsWeb && _sessionCookieValue != null && _sessionCookieValue!.isNotEmpty) {
      headers['Cookie'] = _sessionCookieValue!;
    }
    if (_authTokenValue != null && _authTokenValue!.isNotEmpty) {
      headers['X-Auth-Token'] = _authTokenValue!;
    }
    return headers;
  }

  static Uri _buildUri(String path) => Uri.parse('$baseUrl$path');

  static String? get sessionCookie => _sessionCookieValue;
  static String? get authToken => _authTokenValue;

  static void restoreSessionCookie(String cookie) {
    _sessionCookieValue = cookie;
  }

  static void restoreAuthToken(String token) {
    _authTokenValue = token;
  }

  static void clearSessionCookie() {
    _sessionCookieValue = null;
  }

  static void clearAuthToken() {
    _authTokenValue = null;
  }

  static void _storeCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _sessionCookieValue = setCookie.split(';').first;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _buildUri('/register'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _buildUri('/login'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _storeCookie(response);
    final result = _handleResponse(response);
    final data = result['data'];
    if (data is Map<String, dynamic>) {
      final token = data['auth_token']?.toString() ?? '';
      if (token.isNotEmpty) {
        _authTokenValue = token;
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await http.get(
      _buildUri('/logout'),
      headers: _defaultHeaders,
    );
    clearSessionCookie();
    clearAuthToken();
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> processDocument({
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
    required String action,
  }) async {
    final normalizedAction = action == 'annotate' ? 'blur' : action;
    final request = http.MultipartRequest(
      'POST',
      _buildUri('/api/process'),
    );
    if (!kIsWeb && _sessionCookieValue != null && _sessionCookieValue!.isNotEmpty) {
      request.headers['Cookie'] = _sessionCookieValue!;
    }
    if (_authTokenValue != null && _authTokenValue!.isNotEmpty) {
      request.headers['X-Auth-Token'] = _authTokenValue!;
    }
    request.fields['doc_type'] = docType;
    request.fields['action'] = normalizedAction;

    if (kIsWeb) {
      if (fileBytes == null || fileName == null || fileName.trim().isEmpty) {
        throw Exception('Please reselect the file before uploading.');
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else {
      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      } else if (fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName ?? 'upload.bin',
          ),
        );
      } else {
        throw Exception('Please select a file before uploading.');
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return decoded;
    } else {
      throw Exception(
          'Processing failed: ${response.statusCode} ${response.body}');
    }
  }

  static Future<bool> setPIN(String pin) async {
    final response = await http.post(
      _buildUri('/api/security/pin'),
      headers: _defaultHeaders,
      body: jsonEncode({'pin': pin}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> setFingerprint(String fingerprintData) async {
    final response = await http.post(
      _buildUri('/api/security/fingerprint'),
      headers: _defaultHeaders,
      body: jsonEncode({'fingerprint_data': fingerprintData}),
    );
    return response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getSecurityStatus() async {
    final response = await http.get(
      _buildUri('/api/security/status'),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getSystemHealth() async {
    final response = await http.get(
      _buildUri('/api/health'),
      headers: _defaultHeaders,
    );
    return _handleResponse(response);
  }

  static Future<bool> verifyPIN(String pin) async {
    final response = await http.post(
      _buildUri('/api/security/verify-pin'),
      headers: _defaultHeaders,
      body: jsonEncode({'pin': pin}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> verifyFingerprint() async {
    final response = await http.post(
      _buildUri('/api/security/verify-fingerprint'),
      headers: _defaultHeaders,
      body: jsonEncode({'fingerprint_data': fingerprintToken}),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      _buildUri('/api/change-password'),
      headers: _defaultHeaders,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return _handleResponse(response);
  }

  static Future<bool> downloadDocument(String filename) async {
    try {
      final response = await http.get(
        _buildUri('/api/download/$filename'),
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        if (kIsWeb) {
          return saveDownloadedFile(response.bodyBytes, filename);
        }

        List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/sdcard/Download',
          '/data/media/0/Download',
        ];

        for (String pathStr in possiblePaths) {
          try {
            final dir = Directory(pathStr);
            if (await dir.exists()) {
              final File file = File('$pathStr/$filename');
              await file.writeAsBytes(response.bodyBytes);
              return true;
            }
          } catch (e) {
            continue;
          }
        }

        final appDir = Directory('/data/data');
        try {
          final File file = File('${appDir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes);
          return true;
        } catch (e) {
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Download error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAuditLogs() async {
    final response = await http.get(
      _buildUri('/audit-logs'),
      headers: _defaultHeaders,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        return decoded['data'] as List<dynamic>;
      }
      return decoded as List<dynamic>;
    }
    throw Exception('Failed to load audit logs: ${response.statusCode}');
  }

  static String getDownloadUrl(String filename) =>
      '$baseUrl/api/download/$filename';

  static Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    return {
      'status': response.statusCode,
      'success': response.statusCode >= 200 && response.statusCode < 400,
      'message': jsonBody is Map<String, dynamic> && jsonBody['message'] != null
          ? jsonBody['message'].toString()
          : response.reasonPhrase ?? 'Unknown error',
      'data': jsonBody is Map<String, dynamic> ? jsonBody['data'] : jsonBody,
      'rawBody': response.body,
    };
  }
}
