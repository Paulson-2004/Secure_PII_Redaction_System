import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/backend_waking_hint.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/privlock_badge.dart';
import '../widgets/privlock_metric_card.dart';
import 'audit_logs_screen.dart';
import 'login_screen.dart';
import 'pin_fingerprint_setup_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _pinEnabled = false;
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DocumentProvider>().loadAuditLogs();
    });
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
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final docProvider = context.watch<DocumentProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Manage Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Security Status',
            onPressed: () {
              _loadSecurityStatus();
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
                // ── Profile Identity Card ──────────────────────────────────
                _buildProfileIdentityCard(auth),
                const SizedBox(height: 18),

                // ── Summary KPI Tiles ───────────────────────────────────────
                _buildQuickOverviewRow(docProvider.auditLogs.length),
                const SizedBox(height: 20),

                // ── Security & Authentication Card ──────────────────────────
                _buildSecurityCard(context, auth),
                const SizedBox(height: 20),

                // ── Compliance & Data Governance Card ───────────────────────
                _buildComplianceInfoCard(
                  context,
                  docProvider.auditLogs.length,
                  isLoadingHistory: docProvider.isLoadingLogs,
                ),
                const SizedBox(height: 20),

                // ── Danger Zone / Sign Out ──────────────────────────────────
                _buildSignOutCard(context, auth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Identity Card ─────────────────────────────────────────────────
  Widget _buildProfileIdentityCard(AuthProvider auth) {
    final initial =
        (auth.username.isNotEmpty ? auth.username[0] : 'U').toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;

          final avatarWidget = Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.primaryLight, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          );

          final detailsWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      auth.username.isNotEmpty ? auth.username : 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slate900,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const PrivLockBadge(
                    label: 'ACTIVE',
                    variant: BadgeVariant.success,
                    isPill: true,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                auth.email.isNotEmpty ? auth.email : 'No email registered',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrivLockBadge(
                    label: 'ROLE: SECURITY OPERATOR',
                    variant: BadgeVariant.primary,
                  ),
                  PrivLockBadge(
                    label: 'DPDP ACCESS: AUTHORIZED',
                    variant: BadgeVariant.purple,
                  ),
                ],
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatarWidget,
                const SizedBox(height: 14),
                detailsWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatarWidget,
              const SizedBox(width: 18),
              Expanded(child: detailsWidget),
            ],
          );
        },
      ),
    );
  }

  // ── Quick Overview Row ────────────────────────────────────────────────────
  Widget _buildQuickOverviewRow(int totalProcessed) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrivLockMetricCard(
          label: 'Processed Documents',
          value: '$totalProcessed',
          icon: Icons.description_outlined,
          accentColor: AppTheme.primaryColor,
        ),
        PrivLockMetricCard(
          label: 'PIN Authentication',
          value: _pinEnabled ? 'Enabled' : 'Disabled',
          icon: Icons.pin_outlined,
          accentColor:
              _pinEnabled ? AppTheme.accentColor : AppTheme.slate400,
        ),
        PrivLockMetricCard(
          label: 'Biometrics',
          value: _fingerprintEnabled ? 'Enabled' : 'Disabled',
          icon: Icons.fingerprint_outlined,
          accentColor: _fingerprintEnabled
              ? AppTheme.accentColor
              : AppTheme.slate400,
        ),
      ],
    );
  }

  // ── Security & Authentication Card ────────────────────────────────────────
  Widget _buildSecurityCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Security Credentials & Authentication',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.slate200),
          const SizedBox(height: 12),

          // 1. Password Item
          _buildSecurityRow(
            icon: Icons.lock_reset_outlined,
            title: 'Account Password',
            subtitle: 'Secure bcrypt password for account access',
            statusBadge: const PrivLockBadge(
              label: 'CONFIGURED',
              variant: BadgeVariant.success,
              isPill: true,
            ),
            actionButton: OutlinedButton(
              onPressed: () => ChangePasswordDialog.show(context),
              child: const Text('Change Password'),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.slate100),
          const SizedBox(height: 12),

          // 2. PIN Item
          _buildSecurityRow(
            icon: Icons.pin_outlined,
            title: 'Quick Unlock PIN',
            subtitle: _pinEnabled
                ? 'PIN protection active for rapid session re-authentication'
                : 'Configure 4-6 digit numeric PIN for fast unlock',
            statusBadge: PrivLockBadge(
              label: _pinEnabled ? 'ACTIVE' : 'NOT SET',
              variant: _pinEnabled
                  ? BadgeVariant.success
                  : BadgeVariant.warning,
              isPill: true,
            ),
            actionButton: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PINFingerprintSetupScreen(username: auth.username),
                  ),
                ).then((_) => _loadSecurityStatus());
              },
              child: Text(_pinEnabled ? 'Update PIN' : 'Set Up PIN'),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.slate100),
          const SizedBox(height: 12),

          // 3. Biometric Item
          _buildSecurityRow(
            icon: Icons.fingerprint_outlined,
            title: 'Biometric / Fingerprint Token',
            subtitle: _fingerprintEnabled
                ? 'Hardware biometric key enabled'
                : 'Fingerprint token authentication for mobile/desktop',
            statusBadge: PrivLockBadge(
              label: _fingerprintEnabled ? 'ACTIVE' : 'DISABLED',
              variant: _fingerprintEnabled
                  ? BadgeVariant.success
                  : BadgeVariant.slate,
              isPill: true,
            ),
            actionButton: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PINFingerprintSetupScreen(username: auth.username),
                  ),
                ).then((_) => _loadSecurityStatus());
              },
              child: const Text('Configure'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget statusBadge,
    required Widget actionButton,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 580;

        final infoWidget = Row(
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                      ),
                      statusBadge,
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
              infoWidget,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: actionButton,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: infoWidget),
            const SizedBox(width: 12),
            actionButton,
          ],
        );
      },
    );
  }

  // ── Compliance & Data Governance Card ─────────────────────────────────────
  Widget _buildComplianceInfoCard(
    BuildContext context,
    int totalLogs, {
    bool isLoadingHistory = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              const titleWidget = Row(
                children: [
                  Icon(Icons.history_edu_outlined,
                      size: 20, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audit Ledger & Redaction History',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ),
                ],
              );
              final buttonWidget = OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AuditLogsScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('View All Logs'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 10),
                    buttonWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: titleWidget),
                  const SizedBox(width: 12),
                  buttonWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'You have $totalLogs document sanitization events logged in your compliance audit trail. Each record contains cryptographic timestamps and UIDAI/DPDP regulatory decisions.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.slate600,
              height: 1.4,
            ),
          ),
          // Delayed cold-start hint while history is still loading
          // (Render wake-up). Existing content stays untouched.
          DelayedBackendWakingHint(isWaiting: isLoadingHistory),
        ],
      ),
    );
  }

  // ── Danger Zone / Sign Out ────────────────────────────────────────────────
  Widget _buildSignOutCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          const infoWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End Active Session',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Sign out and clear session tokens from this device',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          );
          final buttonWidget = ElevatedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerLight,
              foregroundColor: AppTheme.dangerColor,
              elevation: 0,
              side: BorderSide(
                  color: AppTheme.dangerColor.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoWidget,
                const SizedBox(height: 12),
                buttonWidget,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: infoWidget),
              const SizedBox(width: 12),
              buttonWidget,
            ],
          );
        },
      ),
    );
  }
}
