import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/change_email_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/privlock_badge.dart';
import 'account_screen.dart';
import 'pin_fingerprint_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pinEnabled = false;
  bool _fingerprintEnabled = false;
  bool _isLoadingSecurity = true;
  String _healthStatus = 'Checking...';
  String? _securityStatusError;
  bool _isCheckingHealth = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
    _checkServerHealth();
  }

  Future<void> _loadSecurityStatus() async {
    try {
      final res = await ApiService.getSecurityStatus();
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _pinEnabled = data['pin_enabled'] == true;
          _fingerprintEnabled = data['fingerprint_enabled'] == true;
          _isLoadingSecurity = false;
          _securityStatusError = null;
        });
      } else {
        setState(() {
          _isLoadingSecurity = false;
          _securityStatusError = 'Security options could not be loaded.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSecurity = false;
          _securityStatusError = 'Security options could not be loaded.';
        });
      }
    }
  }

  Future<void> _checkServerHealth() async {
    setState(() => _isCheckingHealth = true);
    try {
      final res = await ApiService.getSystemHealth();
      if (!mounted) return;
      if (res['success'] == true || res['status'] == 200) {
        setState(() {
          _healthStatus = 'Connected & Operational (HTTP 200)';
          _isCheckingHealth = false;
        });
      } else {
        setState(() {
          _healthStatus = 'Service unavailable. Try again.';
          _isCheckingHealth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _healthStatus = 'Service unavailable. Try again.';
          _isCheckingHealth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Status',
            onPressed: () {
              setState(() => _isLoadingSecurity = true);
              _loadSecurityStatus();
              _checkServerHealth();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Banner ──────────────────────────────────────────
                _buildHeaderBanner(),
                const SizedBox(height: 18),
                if (_securityStatusError != null) ...[
                  Material(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTheme.warningColor),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(_securityStatusError!,
                                  style: AppTheme.bodySecondary)),
                          TextButton(
                            onPressed: () {
                              setState(() => _isLoadingSecurity = true);
                              _loadSecurityStatus();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Section 1: Security & Credentials ───────────────────────
                _buildSectionCard(
                  title: 'Security & Access Credentials',
                  icon: Icons.shield_outlined,
                  children: [
                    _buildSettingTile(
                      icon: Icons.lock_reset_outlined,
                      title: 'Account Password',
                      subtitle:
                          'Update your master sign-in password (bcrypt salted hash)',
                      action: OutlinedButton(
                        onPressed: () => ChangePasswordDialog.show(context),
                        child: const Text('Change Password'),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildSettingTile(
                      icon: Icons.pin_outlined,
                      title: 'Quick Unlock PIN',
                      subtitle: _isLoadingSecurity
                          ? 'Checking PIN status...'
                          : (_pinEnabled
                              ? '4-6 digit numeric PIN protection is currently active'
                              : 'Set a 4-6 digit PIN for rapid session unlock'),
                      statusBadge: PrivLockBadge(
                        label: _pinEnabled ? 'ACTIVE' : 'NOT CONFIGURED',
                        variant: _pinEnabled
                            ? BadgeVariant.success
                            : BadgeVariant.warning,
                        isPill: true,
                      ),
                      action: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => PINFingerprintSetupScreen(
                                      username: auth.username),
                                ),
                              )
                              .then((_) => _loadSecurityStatus());
                        },
                        child: Text(_pinEnabled ? 'Update PIN' : 'Set Up PIN'),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildSettingTile(
                      icon: Icons.fingerprint_outlined,
                      title: 'Biometric Authentication',
                      subtitle: _isLoadingSecurity
                          ? 'Checking biometric status...'
                          : (_fingerprintEnabled
                              ? 'Device fingerprint token verification is enabled'
                              : 'Biometric authentication for mobile & compatible hardware'),
                      statusBadge: PrivLockBadge(
                        label: _fingerprintEnabled ? 'ENABLED' : 'DISABLED',
                        variant: _fingerprintEnabled
                            ? BadgeVariant.success
                            : BadgeVariant.slate,
                        isPill: true,
                      ),
                      action: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => PINFingerprintSetupScreen(
                                      username: auth.username),
                                ),
                              )
                              .then((_) => _loadSecurityStatus());
                        },
                        child: const Text('Configure'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Section 2: Account & Identity ───────────────────────────
                _buildSectionCard(
                  title: 'Account & Identity Configuration',
                  icon: Icons.person_outline,
                  children: [
                    _buildSettingTile(
                      icon: Icons.email_outlined,
                      title: 'Registered Email Address',
                      subtitle: auth.email.isNotEmpty
                          ? auth.email
                          : 'No email registered with this account',
                      statusBadge: const PrivLockBadge(
                        label: 'VERIFIED',
                        variant: BadgeVariant.success,
                        isPill: true,
                      ),
                      action: OutlinedButton(
                        onPressed: () => ChangeEmailDialog.show(context),
                        child: const Text('Change Email'),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildSettingTile(
                      icon: Icons.badge_outlined,
                      title: 'Manage Account Profile',
                      subtitle:
                          'Review account identity, role credentials, and active session details',
                      action: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AccountScreen()),
                          );
                        },
                        child: const Text('Manage Account'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Section 3: Engine Connectivity & Server Health ───────────
                _buildSectionCard(
                  title: 'Backend Connectivity & Engine Health',
                  icon: Icons.dns_outlined,
                  children: [
                    _buildSettingTile(
                      icon: Icons.cloud_done_outlined,
                      title: 'API Server Endpoint',
                      subtitle: ApiService.baseUrl,
                      statusBadge: const PrivLockBadge(
                        label: 'LOCAL CORE',
                        variant: BadgeVariant.primary,
                        isPill: true,
                      ),
                      action: OutlinedButton.icon(
                        onPressed:
                            _isCheckingHealth ? null : _checkServerHealth,
                        icon: _isCheckingHealth
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_outlined, size: 14),
                        label: const Text('Test Connection'),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.slate100),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.health_and_safety_outlined,
                              size: 18, color: AppTheme.accentColor),
                          const SizedBox(width: 10),
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _healthStatus,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _healthStatus ==
                                        'Connected & Operational (HTTP 200)'
                                    ? AppTheme.accentColor
                                    : (_isCheckingHealth
                                        ? AppTheme.slate500
                                        : AppTheme.dangerColor),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
  }

  // ── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(
              Icons.tune_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application & Security Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage authentication credentials, PIN security, email identity, and backend connectivity',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Builder Helper ───────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.slate200),
          ...children,
        ],
      ),
    );
  }

  // ── Setting Tile Helper ───────────────────────────────────────────────────
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? statusBadge,
    required Widget action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;

          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppTheme.slate700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                          ),
                        ),
                        if (statusBadge != null) ...[
                          const SizedBox(width: 8),
                          statusBadge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: action,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}
