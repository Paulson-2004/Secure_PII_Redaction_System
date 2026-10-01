import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/audit_logs_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/pin_fingerprint_setup_screen.dart';
import '../screens/register_screen.dart';
import '../theme/app_theme.dart';
import '../utils/external_launcher.dart';
import 'change_email_dialog.dart';
import 'change_password_dialog.dart';

class AppDrawer extends StatefulWidget {
  final Function(String)? onMenuItemSelected;
  final String currentRoute;

  const AppDrawer({
    super.key,
    this.onMenuItemSelected,
    required this.currentRoute,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _showSecuritySettings = false;

  void _navigateToDashboard({bool scrollToUpload = false}) {
    Navigator.pop(context);
    if (widget.currentRoute == 'dashboard') {
      if (scrollToUpload && widget.onMenuItemSelected != null) {
        widget.onMenuItemSelected!('upload');
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(initialAction: scrollToUpload ? 'upload' : null),
        ),
      );
    }
  }

  void _promptSignInForHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_outlined, color: Color(0xFF1A73E8)),
            SizedBox(width: 8),
            Text('Redaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Sign in to view your redaction history.\n\n'
          'Guest documents are ephemeral and not saved to the database. To access permanent audit trails and document history, please sign in or create an account.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _navigateToAuditLogs() {
    Navigator.pop(context);
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) {
      _promptSignInForHistory();
      return;
    }
    if (widget.currentRoute != 'history') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final initial = auth.isGuest
        ? 'G'
        : (auth.username.isNotEmpty ? auth.username[0] : 'U').toUpperCase();

    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ──────────────────────────────────────────
            // USER PROFILE HEADER
            // ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 32, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              initial,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.isGuest
                        ? 'Guest User'
                        : (auth.username.isNotEmpty ? auth.username : 'User'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.isGuest
                        ? 'Ephemeral Session'
                        : (auth.email.isNotEmpty
                            ? auth.email
                            : 'PrivLock Operator'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ──────────────────────────────────────────
            // MAIN FEATURES SECTION
            // ──────────────────────────────────────────
            _buildSectionDivider('CORE WORKFLOWS'),

            _buildDrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              routeName: 'dashboard',
              isSelected: widget.currentRoute == 'dashboard',
              onTap: () => _navigateToDashboard(scrollToUpload: false),
            ),

            _buildDrawerItem(
              icon: Icons.upload_file_outlined,
              label: 'Upload Document',
              routeName: 'upload',
              isSelected: false,
              onTap: () => _navigateToDashboard(scrollToUpload: true),
            ),

            _buildDrawerItem(
              icon: Icons.history_outlined,
              label: 'Redaction History',
              routeName: 'history',
              isSelected: widget.currentRoute == 'history',
              onTap: _navigateToAuditLogs,
            ),

            const SizedBox(height: 12),

            // ──────────────────────────────────────────
            // SETTINGS SECTION
            // ──────────────────────────────────────────
            _buildSectionDivider('SECURITY & ACCOUNT'),

            if (auth.isGuest) ...[
              _buildDrawerItem(
                icon: Icons.login_rounded,
                label: 'Sign In to Account',
                routeName: 'login',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.person_add_outlined,
                label: 'Create Free Account',
                routeName: 'register',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
            ] else ...[
              _buildDrawerItem(
                icon: Icons.lock_reset_outlined,
                label: 'Change Password',
                routeName: 'change_password',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  ChangePasswordDialog.show(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.email_outlined,
                label: 'Change Email',
                routeName: 'change_email',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  ChangeEmailDialog.show(context);
                },
              ),
              // Expandable Security Settings
              _buildExpandableSecurity(auth),
            ],

            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // LOGOUT SECTION
            // ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (auth.isGuest) {
                    await auth.clearLocalSession();
                  } else {
                    await auth.logout();
                  }
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: Icon(auth.isGuest ? Icons.exit_to_app : Icons.logout,
                    size: 16),
                label: Text(auth.isGuest ? 'Exit Guest Mode' : 'Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerLight,
                  foregroundColor: AppTheme.dangerColor,
                  elevation: 0,
                  side: BorderSide(
                      color: AppTheme.dangerColor.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // VIEW SOURCE & APP INFO
            // ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppTheme.slate200),
                ),
                tileColor: AppTheme.slate50,
                dense: true,
                leading: const Icon(Icons.code_rounded,
                    color: AppTheme.slate700, size: 20),
                title: const Text(
                  'View Source',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate800,
                  ),
                ),
                subtitle: const Text(
                  'GitHub Repository',
                  style: TextStyle(fontSize: 10, color: AppTheme.slate500),
                ),
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppTheme.slate400),
                onTap: () {
                  Navigator.pop(context);
                  launchExternalUrl(
                    'https://github.com/Paulson-2004/Secure_PII_Redaction_System',
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Divider(color: AppTheme.slate200),
                  SizedBox(height: 8),
                  Text(
                    'PrivLock v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'AI PII Detection & Policy Decision Engine',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate400,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSecurity(AuthProvider auth) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 2, 16, 2),
          leading: const Icon(Icons.security_outlined,
              size: 20, color: AppTheme.slate700),
          title: const Text(
            'Security Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate800,
            ),
          ),
          trailing: Icon(
            _showSecuritySettings ? Icons.expand_less : Icons.expand_more,
            color: AppTheme.slate500,
            size: 20,
          ),
          onTap: () =>
              setState(() => _showSecuritySettings = !_showSecuritySettings),
        ),
        if (_showSecuritySettings) ...[
          _buildDrawerItem(
            icon: Icons.pin_outlined,
            label: 'PIN Setup',
            routeName: 'pin_setup',
            isSelected: false,
            indented: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PINFingerprintSetupScreen(username: auth.username),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.fingerprint_outlined,
            label: 'Fingerprint Setup',
            routeName: 'fingerprint_setup',
            isSelected: false,
            indented: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PINFingerprintSetupScreen(username: auth.username),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate400,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required String routeName,
    required bool isSelected,
    required VoidCallback onTap,
    bool indented = false,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(indented ? 24 : 12, 2, 12, 2),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: indented ? 12 : 10,
          vertical: 2,
        ),
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppTheme.primaryColor : AppTheme.slate600,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : AppTheme.slate800,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
