import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/account_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'change_password_dialog.dart';

class UserProfilePanel extends StatelessWidget {
  const UserProfilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = math.min(280.0, screenWidth - 32);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(top: 56, right: 16, left: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: Container(
          width: panelWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.slate200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────────
              // COMPACT IDENTITY HEADER
              // ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border(
                      bottom: BorderSide(color: AppTheme.slate200, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE), width: 1),
                      ),
                      child: Center(
                        child: auth.isGuest
                            ? const Icon(Icons.person_outline,
                                size: 20, color: AppTheme.primaryColor)
                            : Text(
                                (auth.username.isNotEmpty
                                        ? auth.username[0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            auth.isGuest ? 'Guest Session' : auth.username,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.isGuest
                                ? 'No account linked • Ephemeral'
                                : (auth.email.isNotEmpty
                                    ? auth.email
                                    : 'Active Account'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
                const Divider(
                    height: 1,
                    indent: 0,
                    endIndent: 0,
                    color: AppTheme.slate100),
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
                const Divider(
                    height: 1,
                    indent: 0,
                    endIndent: 0,
                    color: AppTheme.slate100),
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
                const Divider(
                    height: 1,
                    indent: 0,
                    endIndent: 0,
                    color: AppTheme.slate100),
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
        hoverColor: isDestructive ? const Color(0xFFFEF2F2) : AppTheme.slate50,
        splashColor: isDestructive ? const Color(0xFFFEE2E2) : AppTheme.slate100,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive
                    ? AppTheme.dangerColor
                    : AppTheme.slate600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? AppTheme.dangerColor
                        : AppTheme.slate800,
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
