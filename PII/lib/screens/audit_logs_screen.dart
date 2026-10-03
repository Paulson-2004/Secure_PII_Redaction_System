import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../models/audit_log.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/backend_waking_hint.dart';
import '../widgets/privlock_badge.dart';
import '../widgets/privlock_metric_card.dart';
import 'login_screen.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  String _selectedDocType = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<DocumentProvider>().loadAuditLogs();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AuditLog> _filterLogs(List<AuditLog> logs) {
    return logs.where((log) {
      final matchesType = _selectedDocType == 'all' ||
          log.documentType.toLowerCase() == _selectedDocType.toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          log.filename.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          '#${log.id}'.contains(_searchQuery) ||
          log.documentType.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isGuest) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: const Text('Compliance Audit Trail'),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.history_toggle_off_outlined,
                    size: 28,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Audit Trail is Available for Registered Accounts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'PrivLock does not store guest documents or logs in the database to protect your privacy. To maintain compliance audit logs and access your redaction history, please create an account or sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('Sign In / Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Compliance Audit Trail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Logs',
            onPressed: () => context.read<DocumentProvider>().loadAuditLogs(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingLogs) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Loading compliance audit logs...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      DelayedBackendWakingHint(
                        isWaiting: provider.isLoadingLogs,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (provider.auditLogsError.isNotEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 36, color: AppTheme.warningColor),
                      const SizedBox(height: 12),
                      const Text('History is temporarily unavailable',
                          style: AppTheme.sectionTitle,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(provider.auditLogsError,
                          style: AppTheme.bodySecondary,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<DocumentProvider>().loadAuditLogs(),
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final allLogs = provider.auditLogs;
          final filteredLogs = _filterLogs(allLogs);
          final totalPii =
              allLogs.fold<int>(0, (sum, item) => sum + item.piiCount);
          final avgTime = allLogs.isEmpty
              ? 0.0
              : allLogs.fold<double>(0.0, (s, i) => s + i.processingTime) /
                  allLogs.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Banner ──────────────────────────────────────────
                    _buildHeaderBanner(allLogs.length),
                    const SizedBox(height: 18),

                    // ── Quick Metrics Row ──────────────────────────────────────
                    _buildMetricsOverview(
                      totalDocs: allLogs.length,
                      totalPii: totalPii,
                      avgTime: avgTime,
                    ),
                    const SizedBox(height: 20),

                    // ── Search & Filter Controls ───────────────────────────────
                    _buildFilterSection(),
                    const SizedBox(height: 18),

                    // ── Audit Log List / Empty State ───────────────────────────
                    if (filteredLogs.isEmpty)
                      _buildEmptyState(allLogs.isEmpty)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _AuditLogItemCard(log: filteredLogs[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeaderBanner(int totalCount) {
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
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
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
                  'Regulatory Audit Trail & Compliance Ledger',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Immutable log of all document sanitizations, policy evaluations, and PII redacting events',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrivLockBadge(
            label: '$totalCount RECORDS',
            variant: BadgeVariant.primary,
            isPill: true,
          ),
        ],
      ),
    );
  }

  // ── Quick Metrics Row ─────────────────────────────────────────────────────
  Widget _buildMetricsOverview({
    required int totalDocs,
    required int totalPii,
    required double avgTime,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrivLockMetricCard(
          label: 'Total Processed',
          value: '$totalDocs',
          icon: Icons.description_outlined,
          accentColor: AppTheme.primaryColor,
        ),
        PrivLockMetricCard(
          label: 'PII Entities Redacted',
          value: '$totalPii',
          icon: Icons.shield_outlined,
          accentColor: AppTheme.dangerColor,
        ),
        PrivLockMetricCard(
          label: 'Avg. Latency',
          value: totalDocs > 0 ? '${avgTime.toStringAsFixed(2)}s' : '< 1.0s',
          icon: Icons.timer_outlined,
          accentColor: AppTheme.accentColor,
        ),
      ],
    );
  }

  // ── Search & Filter Controls ──────────────────────────────────────────────
  Widget _buildFilterSection() {
    final filters = [
      {'key': 'all', 'label': 'All Documents'},
      {'key': 'aadhaar', 'label': 'Aadhaar'},
      {'key': 'pan', 'label': 'PAN Card'},
      {'key': 'driving_license', 'label': 'Driving License'},
      {'key': 'voter_id', 'label': 'Voter ID'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search by filename, document type, or audit ID...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTheme.slate400),
              prefixIcon:
                  const Icon(Icons.search, size: 18, color: AppTheme.slate400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppTheme.slate50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters.map((f) {
              final isSelected = _selectedDocType == f['key'];
              return ChoiceChip(
                label: Text(f['label']!),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedDocType = f['key']!);
                },
                selectedColor: AppTheme.primaryLight,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.slate600,
                ),
                backgroundColor: AppTheme.slate50,
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                      : AppTheme.slate200,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool noLogsAtAll) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.history_outlined,
              size: 28,
              color: AppTheme.slate400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noLogsAtAll
                ? 'No Compliance Audit Logs Yet'
                : 'No Matching Records Found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noLogsAtAll
                ? 'Processed documents will automatically generate verifiable audit trails here.'
                : 'Try adjusting your search terms or selecting a different document category.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.slate500,
            ),
          ),
          if (noLogsAtAll) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Process a Document'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Audit Log Item Card ─────────────────────────────────────────────────────

class _AuditLogItemCard extends StatelessWidget {
  final AuditLog log;

  const _AuditLogItemCard({required this.log});

  String get _docTypeDisplay {
    switch (log.documentType.toLowerCase()) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'pan':
        return 'PAN Card';
      case 'driving_license':
        return 'Driving License';
      case 'voter_id':
        return 'Voter ID';
      default:
        return log.documentType.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Document icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.filename,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${log.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_docTypeDisplay • ${log.createdAt.isNotEmpty ? log.createdAt : 'Recent'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PrivLockBadge.decision(log.actionTaken),
                        PrivLockBadge(
                          label: '${log.piiCount} PII DETECTED',
                          variant: log.piiCount > 0
                              ? BadgeVariant.danger
                              : BadgeVariant.success,
                        ),
                        if (log.processingTime > 0)
                          PrivLockBadge(
                            label: '${log.processingTime.toStringAsFixed(2)}s',
                            variant: BadgeVariant.slate,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick download action button if not narrow
              if (!isNarrow) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success =
                        await ApiService.downloadDocument(log.filename);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Downloaded ${log.filename}'
                            : 'Download failed. File may not be available.'),
                        backgroundColor: success
                            ? AppTheme.accentColor
                            : AppTheme.dangerColor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
