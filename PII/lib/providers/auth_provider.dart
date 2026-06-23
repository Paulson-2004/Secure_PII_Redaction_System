import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';
  bool _isLoading = false;
  String _errorMessage = '';
  bool _initialized = false;

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get initialized => _initialized;

  AuthProvider() {
    _loadSession();
  }

  Future<void> initialize() async {
    if (!_initialized) {
      await _loadSession();
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _username = prefs.getString('username') ?? '';
    _email = prefs.getString('email') ?? '';
    final cookie = prefs.getString('session_cookie') ?? '';
    if (cookie.isNotEmpty) {
      ApiService.restoreSessionCookie(cookie);
    }
    final authToken = prefs.getString('auth_token') ?? '';
    if (authToken.isNotEmpty) {
      ApiService.restoreAuthToken(authToken);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.login(
        username: username,
        password: password,
      );

      if (result['success'] == true) {
        _isLoggedIn = true;
        _username = username;
        _email = (result['data'] is Map<String, dynamic>)
            ? (result['data']['email']?.toString() ?? '')
            : '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', _username);
        await prefs.setString('email', _email);
        if (ApiService.sessionCookie != null) {
          await prefs.setString('session_cookie', ApiService.sessionCookie!);
        }
        if (ApiService.authToken != null) {
          await prefs.setString('auth_token', ApiService.authToken!);
        }

        _errorMessage = '';
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = result['message'] ?? 'Invalid username or password';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        final loginSuccess = await login(username, password);
        _isLoading = false;
        return loginSuccess;
      }

      _errorMessage = result['message'] ??
          'Registration failed. Check your input and server.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _isLoading = false;
      if (result['success'] == true) {
        return true;
      }

      _errorMessage = result['message'] ?? 'Failed to change password';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password update failed. ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    _isLoggedIn = false;
    _username = '';
    _email = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.clearSessionCookie();
    ApiService.clearAuthToken();
    notifyListeners();
  }
}
