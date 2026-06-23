import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pinCtrl = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _loading = true;
  bool _pinEnabled = false;
  bool _fingerprintEnabled = false;
  bool _biometricAvailable = false;
  bool _authenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    try {
      final status = await ApiService.getSecurityStatus();
      if (status['success'] == true) {
        final data = status['data'] as Map<String, dynamic>;
        final canCheckBio = !kIsWeb && await _localAuth.canCheckBiometrics;
        final biometrics = kIsWeb
            ? const <BiometricType>[]
            : await _localAuth.getAvailableBiometrics();

        setState(() {
          _pinEnabled = data['pin_enabled'] == true;
          _fingerprintEnabled = data['fingerprint_enabled'] == true;
          _biometricAvailable = canCheckBio && biometrics.isNotEmpty;
          _loading = false;
        });

        if (!_pinEnabled) {
          _navigateToDashboard();
        }
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'Session expired. Please sign in again.';
        });
        await _logoutAndNavigateToLogin(clearSessionOnly: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load security settings. Please sign in again.';
      });
      await _logoutAndNavigateToLogin(clearSessionOnly: true);
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your PIN to continue.';
      });
      return;
    }

    setState(() {
      _authenticating = true;
      _errorMessage = '';
    });

    try {
      final success = await ApiService.verifyPIN(pin);
      if (success) {
        _navigateToDashboard();
      } else {
        setState(() {
          _errorMessage = 'Invalid PIN. Please try again.';
          _authenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'PIN verification failed. Please try again.';
        _authenticating = false;
      });
    }
  }

  Future<void> _unlockWithFingerprint() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'Fingerprint login is not available in the browser.';
        _authenticating = false;
      });
      return;
    }

    if (!_fingerprintEnabled || !_biometricAvailable) {
      return;
    }

    setState(() {
      _authenticating = true;
      _errorMessage = '';
    });

    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate with fingerprint to unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!isAuthenticated) {
        setState(() {
          _errorMessage = 'Fingerprint authentication failed.';
          _authenticating = false;
        });
        return;
      }

      final verified = await ApiService.verifyFingerprint();
      if (verified) {
        _navigateToDashboard();
      } else {
        setState(() {
          _errorMessage = 'Fingerprint unlock failed. Please use PIN.';
          _authenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fingerprint authentication error.';
        _authenticating = false;
      });
    }
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _logoutAndNavigateToLogin({bool clearSessionOnly = false}) async {
    final auth = context.read<AuthProvider>();
    if (!clearSessionOnly) {
      await auth.logout();
    } else {
      await auth.clearLocalSession();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Secure Unlock'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your PIN to continue',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app is protected by your security settings.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _pinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _authenticating ? null : _verifyPin,
                        child: _authenticating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Unlock with PIN'),
                      ),
                    ),
                    if (_fingerprintEnabled && _biometricAvailable) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use fingerprint instead'),
                        onPressed: _authenticating ? null : _unlockWithFingerprint,
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _logoutAndNavigateToLogin,
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
