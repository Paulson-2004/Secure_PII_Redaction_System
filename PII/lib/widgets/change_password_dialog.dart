import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'backend_waking_hint.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() {
        _errorMessage = 'New passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(
      _currentPasswordCtrl.text,
      _newPasswordCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: Color(0xFF34A853),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = auth.errorMessage.isNotEmpty
            ? auth.errorMessage
            : 'Failed to update password. Check your current password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: Color(0xFF1A73E8)),
          SizedBox(width: 10),
          Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                    ),
                  ),
                ],
                TextFormField(
                  controller: _currentPasswordCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 chars)',
                    prefixIcon: const Icon(Icons.lock_reset, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Confirm new password' : null,
                ),
                DelayedBackendWakingHint(isWaiting: _isLoading),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

