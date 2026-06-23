import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/audit_logs_screen.dart';

class AppDrawer extends StatefulWidget {
  final Function(String) onMenuItemSelected;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.onMenuItemSelected,
    required this.currentRoute,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _showSecuritySettings = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Drawer(
      child: Container(
        color: const Color(0xFFFAFAFA),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ──────────────────────────────────────────
            // USER PROFILE HEADER
            // ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        (auth.username.isNotEmpty 
                            ? auth.username[0] 
                            : 'U').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User Name
                  Text(
                    auth.username,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // User Email
                  Text(
                    auth.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
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
            _buildSectionDivider('APP FEATURES'),
            _buildDrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              routeName: 'dashboard',
              isSelected: widget.currentRoute == 'dashboard',
              onTap: () {
                widget.onMenuItemSelected('dashboard');
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.upload_file_outlined,
              label: 'Upload Document',
              routeName: 'upload',
              isSelected: widget.currentRoute == 'upload',
              onTap: () {
                widget.onMenuItemSelected('upload');
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.history_outlined,
              label: 'Redaction History',
              routeName: 'history',
              isSelected: widget.currentRoute == 'history',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.lock_outline,
              label: 'Secure Files',
              routeName: 'secure',
              isSelected: widget.currentRoute == 'secure',
              onTap: () {
                widget.onMenuItemSelected('secure');
                Navigator.pop(context);
              },
            ),

            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // SETTINGS SECTION
            // ──────────────────────────────────────────
            _buildSectionDivider('SETTINGS & SECURITY'),

            _buildDrawerItem(
              icon: Icons.lock_reset_outlined,
              label: 'Change Password',
              routeName: 'change_password',
              isSelected: widget.currentRoute == 'change_password',
              onTap: () {
                widget.onMenuItemSelected('change_password');
                Navigator.pop(context);
              },
            ),

            _buildDrawerItem(
              icon: Icons.email_outlined,
              label: 'Change Email',
              routeName: 'change_email',
              isSelected: widget.currentRoute == 'change_email',
              onTap: () {
                widget.onMenuItemSelected('change_email');
                Navigator.pop(context);
              },
            ),

            // Expandable Security Settings
            _buildExpandableSecurity(),

            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // LOGOUT SECTION
            // ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // APP INFO
            // ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'PrivLock v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secure PII Redaction',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSecurity() {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
          leading: const Icon(Icons.security_outlined, size: 22),
          title: const Text(
            'Security Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
          trailing: Icon(
            _showSecuritySettings ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey.shade600,
          ),
          onTap: () => setState(() => _showSecuritySettings = !_showSecuritySettings),
        ),
        if (_showSecuritySettings) ...[
          _buildDrawerItem(
            icon: Icons.pin_outlined,
            label: 'PIN Setup',
            routeName: 'pin_setup',
            isSelected: widget.currentRoute == 'pin_setup',
            indented: true,
            onTap: () {
              widget.onMenuItemSelected('pin_setup');
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.fingerprint_outlined,
            label: 'Fingerprint Setup',
            routeName: 'fingerprint_setup',
            isSelected: widget.currentRoute == 'fingerprint_setup',
            indented: true,
            onTap: () {
              widget.onMenuItemSelected('fingerprint_setup');
              Navigator.pop(context);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
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
      margin: EdgeInsets.fromLTRB(indented ? 24 : 12, 4, 12, 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: indented ? 12 : 8,
          vertical: 4,
        ),
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade700,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF1A1A2E),
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
