import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/account_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import 'change_password_dialog.dart';

class UserProfilePanel extends StatelessWidget {
  const UserProfilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(top: 60, right: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────────
              // PROFILE HEADER
              // ──────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: auth.isGuest
                            ? const Icon(Icons.person_outline,
                                size: 28, color: Colors.white)
                            : Text(
                                (auth.username.isNotEmpty
                                        ? auth.username[0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Welcome message
                    Text(
                      auth.isGuest ? 'Guest Session' : 'Hi, ${auth.username}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Email or guest notice
                    Text(
                      auth.isGuest
                          ? 'No account linked • Ephemeral mode'
                          : auth.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ──────────────────────────────────────────
              // MENU OPTIONS
              // ──────────────────────────────────────────
              if (auth.isGuest) ...[
                _profileMenuItem(
                  icon: Icons.login_rounded,
                  label: 'Sign In to Account',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
                _profileMenuItem(
                  icon: Icons.person_add_outlined,
                  label: 'Create Free Account',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 0, endIndent: 0),
                _profileMenuItem(
                  icon: Icons.info_outline,
                  label: 'Why Create an Account?',
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Color(0xFF1A73E8)),
                            SizedBox(width: 8),
                            Text('Account Benefits',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        content: const Text(
                          'PrivLock accounts include:\n\n'
                          '• Permanent compliance audit trails\n'
                          '• Redaction history & previous document access\n'
                          '• Biometric & PIN lock protection\n'
                          '• Full document retention management\n\n'
                          'Guest documents are ephemeral and not saved to the database.',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 0, endIndent: 0),
                _profileMenuItem(
                  icon: Icons.exit_to_app,
                  label: 'Exit Guest Mode',
                  isDestructive: true,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    await auth.clearLocalSession();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ] else ...[
                _profileMenuItem(
                  icon: Icons.person_outline,
                  label: 'Manage Account',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                  },
                ),
                _profileMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _profileMenuItem(
                  icon: Icons.lock_reset_outlined,
                  label: 'Change Password',
                  onTap: () {
                    Navigator.pop(context);
                    ChangePasswordDialog.show(context);
                  },
                ),
                const Divider(height: 1, indent: 0, endIndent: 0),
                _profileMenuItem(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  isDestructive: true,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    await auth.logout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _profileMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: Colors.grey.shade100,
        splashColor: Colors.grey.shade200,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive 
                    ? Colors.red.shade600 
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? Colors.red.shade600
                        : Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
