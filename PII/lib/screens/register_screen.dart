import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/backend_waking_hint.dart';
import 'pin_fingerprint_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              PINFingerprintSetupScreen(username: _usernameCtrl.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final contentWidth = (viewport.maxWidth - 48).clamp(0.0, 520.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set up your account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start protecting your documents with AI-powered redaction',
                          style: TextStyle(
                              color: AppTheme.slate600,
                              fontSize: 14,
                              height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          autofillHints: const [AutofillHints.newUsername],
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Username is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password (min. 6 characters)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                            ),
                          ),
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            if (auth.errorMessage.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                auth.errorMessage,
                                style: const TextStyle(
                                    color: Color(0xFFB91C1C), fontSize: 13),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => ElevatedButton(
                            onPressed: auth.isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => DelayedBackendWakingHint(
                            isWaiting: auth.isLoading,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? ',
                                style: TextStyle(color: Color(0xFF6B7280))),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
