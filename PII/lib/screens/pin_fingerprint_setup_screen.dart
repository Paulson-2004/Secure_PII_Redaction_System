import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class PINFingerprintSetupScreen extends StatefulWidget {
  final String username;

  const PINFingerprintSetupScreen({super.key, required this.username});

  @override
  State<PINFingerprintSetupScreen> createState() =>
      _PINFingerprintSetupScreenState();
}

class _PINFingerprintSetupScreenState extends State<PINFingerprintSetupScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isBiometricAvailable = false;
  bool _enableFingerprint = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      if (kIsWeb) {
        setState(() {
          _isBiometricAvailable = false;
        });
        return;
      }

      final canCheckBio = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = canCheckBio && biometrics.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  Future<void> _setPIN() async {
    if (_pinCtrl.text.isEmpty || _confirmPinCtrl.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter and confirm your PIN';
      });
      return;
    }

    if (_pinCtrl.text.length < 4 || _pinCtrl.text.length > 6) {
      setState(() {
        _errorMessage = 'PIN must be 4-6 digits';
      });
      return;
    }

    if (_pinCtrl.text != _confirmPinCtrl.text) {
      setState(() {
        _errorMessage = 'PINs do not match';
      });
      return;
    }

    if (!_pinCtrl.text.contains(RegExp(r'^\d+$'))) {
      setState(() {
        _errorMessage = 'PIN must contain only digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await ApiService.setPIN(_pinCtrl.text);
      if (success) {
        if (_enableFingerprint && _isBiometricAvailable) {
          _showFingerprintDialog();
        } else {
          _continueToDashboard();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to set PIN. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollFingerprint() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'Fingerprint enrollment is not available in the browser.';
      });
      return;
    }

    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please provide your fingerprint to register',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!isAuthenticated) {
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final success =
          await ApiService.setFingerprint(ApiService.fingerprintToken);
      if (success) {
        _continueToDashboard();
      } else {
        setState(() {
          _errorMessage = 'Failed to register fingerprint';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fingerprint enrollment failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showFingerprintDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Fingerprint'),
        content: const Text(
          'Would you like to enable fingerprint authentication for faster login?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _continueToDashboard();
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enrollFingerprint();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _continueToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Your Account'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.security,
                  color: Color(0xFF1A73E8),
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Set Up Security',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a PIN and optionally enable fingerprint for secure access',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEA4335)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Color(0xFFEA4335),
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Create a 4-6 digit PIN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              if (_isBiometricAvailable)
                SwitchListTile(
                  value: _enableFingerprint,
                  onChanged: (value) =>
                      setState(() => _enableFingerprint = value),
                  title: const Text('Enable fingerprint login'),
                  subtitle: const Text('Use biometric unlock on this device'),
                ),
              if (!_isBiometricAvailable)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: const Text(
                    'Fingerprint login is not available on this device.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _setPIN,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
