import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/detection_result.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/privlock_badge.dart';
import '../widgets/privlock_metric_card.dart';
import 'register_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {
      auth = null;
    }
    final bool isGuest = auth?.isGuest ?? false;
    final result = context.watch<DocumentProvider>().lastResult;
    if (result == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(title: const Text('Processing Result')),
        body: const Center(
          child: Text('No result available. Please process a document first.'),
        ),
      );
    }

    final downloadFilename = result.redactedFilename.isNotEmpty
        ? result.redactedFilename
        : result.filename;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Processing Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Process Another Document',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Banner Header ────────────────────────────────────
                _buildHeaderBanner(context, result),
                const SizedBox(height: 18),

                // ── Metric Cards Row (6 KPIs from Report Fig 9.3) ────────────
                _buildMetricsRow(result),
                const SizedBox(height: 22),

                // ── Primary Document Preview ────────────────────────────────
                _RedactedDocumentPreviewCard(
                  filename: downloadFilename,
                  originalFilename: result.originalFilename,
                  docType: result.docType,
                ),
                const SizedBox(height: 22),

                // ── Text Comparison (OCR Extracted vs Redacted) ─────────────
                if (result.extractedTextPreview.isNotEmpty) ...[
                  _buildTextComparisonCard(context, result),
                  const SizedBox(height: 22),
                ],


                // ── Detected PII Details Table (From Report Fig 9.4) ─────────
                _buildPiiDetailsTable(result),
                const SizedBox(height: 22),

                // ── AI Detection Statistics Card (From Report Fig 9.5) ───────
                _buildDetectionStatsCard(result),
                const SizedBox(height: 24),

                // ── Optional Guest Mode Account Promotion CTA ───────────────
                if (isGuest) ...[
                  _buildGuestAccountPromotionCard(context),
                  const SizedBox(height: 24),
                ],

                // ── Bottom Navigation & Actions ─────────────────────────────
                _buildBottomActions(context, downloadFilename),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Guest Account Promotion CTA ──────────────────────────────────────────
  Widget _buildGuestAccountPromotionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bookmark_added_outlined,
                color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Want to keep your redaction history?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create a free account to save and access your previous redactions, maintain permanent compliance audit logs, and download past records anytime.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_add_outlined, size: 14),
                  label: const Text('Create Free Account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeaderBanner(BuildContext context, DetectionResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppTheme.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Redaction Complete',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.slate900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.originalFilename,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const PrivLockBadge(
                    label: 'PII PROTECTED',
                    icon: Icons.shield_outlined,
                    variant: BadgeVariant.success,
                    isPill: true,
                  ),
                  PrivLockBadge(
                    label: result.docType.toUpperCase(),
                    variant: BadgeVariant.primary,
                  ),
                  PrivLockBadge(
                    label: result.action.toUpperCase(),
                    variant: BadgeVariant.purple,
                  ),
                  if (result.pageCount > 1)
                    PrivLockBadge(
                      label: '${result.pageCount} PAGES',
                      variant: BadgeVariant.slate,
                    ),
                  Text(
                    '•  Processed at ${result.processedAt.isNotEmpty ? result.processedAt : 'Just now'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  // ── Metrics Row (Report Fig 9.3) ──────────────────────────────────────────
  Widget _buildMetricsRow(DetectionResult result) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrivLockMetricCard(
              label: 'Total PII',
              value: '${result.piiCount}',
              icon: Icons.security,
              accentColor: result.piiCount > 0
                  ? AppTheme.dangerColor
                  : AppTheme.accentColor,
            ),
            PrivLockMetricCard(
              label: 'Full Redacted',
              value: '${result.fullRedacted}',
              icon: Icons.block,
              accentColor: AppTheme.purpleColor,
            ),
            PrivLockMetricCard(
              label: 'Partial Mask',
              value: '${result.partialMasked}',
              icon: Icons.visibility_off_outlined,
              accentColor: AppTheme.warningColor,
            ),
            PrivLockMetricCard(
              label: 'Kept',
              value: '${result.keptCount}',
              icon: Icons.check_circle_outline,
              accentColor: AppTheme.accentColor,
            ),
            PrivLockMetricCard(
              label: 'Regex Hits',
              value: '${result.regexHits}',
              icon: Icons.code,
              accentColor: AppTheme.primaryColor,
            ),
            PrivLockMetricCard(
              label: 'NER Hits',
              value: '${result.nerHits}',
              icon: Icons.psychology_outlined,
              accentColor: const Color(0xFF6366F1),
            ),
          ],
        );
      },
    );
  }

  // ── Text Comparison (Report Fig 9.4) ──────────────────────────────────────
  Widget _buildTextComparisonCard(BuildContext context, DetectionResult result) {
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
              Icon(Icons.compare_arrows_outlined,
                  size: 18, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Text Comparison & Extraction Preview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EXTRACTED TEXT (OCR SAMPLE)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      tooltip: 'Copy text sample',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: result.extractedTextPreview),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied OCR sample to clipboard'),
                            backgroundColor: AppTheme.accentColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.extractedTextPreview,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── Detected PII Details Table (Report Fig 9.4) ───────────────────────────
  Widget _buildPiiDetailsTable(DetectionResult result) {
    final details = result.piiDetails;

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
              final isNarrow = constraints.maxWidth < 400;
              const titleWidget = Row(
                children: [
                  Icon(Icons.list_alt_outlined,
                      size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detected PII Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ),
                ],
              );
              final badgeWidget = PrivLockBadge(
                label: '${details.length} ENTITIES',
                variant: BadgeVariant.primary,
                isPill: true,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                children: [
                  const Expanded(child: titleWidget),
                  const SizedBox(width: 8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (details.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(
                child: Text(
                  'No PII entities detected in this document.',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate500),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppTheme.slate50),
                  horizontalMargin: 12,
                  columnSpacing: 18,
                  headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate500,
                    letterSpacing: 0.5,
                  ),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('PII TYPE')),
                    DataColumn(label: Text('SOURCE')),
                    DataColumn(label: Text('CONFIDENCE')),
                    DataColumn(label: Text('DECISION')),
                    DataColumn(label: Text('SEVERITY')),
                    DataColumn(label: Text('REGULATORY MANDATE')),
                  ],
                  rows: List.generate(details.length, (index) {
                    final item = details[index];
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.slate500))),
                        DataCell(
                          Text(
                            item.type,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                          ),
                        ),
                        DataCell(PrivLockBadge.source(item.source)),
                        DataCell(
                          Text(
                            '${(item.confidence * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate700,
                            ),
                          ),
                        ),
                        DataCell(PrivLockBadge.decision(item.decision)),
                        DataCell(PrivLockBadge.severity(item.severity)),
                        DataCell(
                          Text(
                            item.regulation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.slate500),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PrivLock provides technical privacy/security guidance and automated redaction. It is not legal advice and does not certify regulatory compliance.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Detection Statistics Card (Report Fig 9.5) ─────────────────────────
  Widget _buildDetectionStatsCard(DetectionResult result) {
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
              Icon(Icons.query_stats_outlined,
                  size: 18, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Detection Statistics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildDetectionSources(result)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildAvgConfidence(result)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildProcessingTime(result)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDetectionSources(result),
                        const SizedBox(height: 14),
                        _buildAvgConfidence(result),
                        const SizedBox(height: 14),
                        _buildProcessingTime(result),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionSources(DetectionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DETECTION SOURCES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrivLockBadge(label: 'Regex: ${result.regexHits}', variant: BadgeVariant.success),
            PrivLockBadge(label: 'NER: ${result.nerHits}', variant: BadgeVariant.purple),
            PrivLockBadge(label: 'Hybrid: ${result.hybridHits}', variant: BadgeVariant.primary),
          ],
        ),
      ],
    );
  }

  Widget _buildAvgConfidence(DetectionResult result) {
    final confPercent = (result.averageConfidence * 100).clamp(0, 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AVG. CONFIDENCE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate500,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${confPercent.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: confPercent / 100,
            minHeight: 8,
            backgroundColor: AppTheme.slate100,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingTime(DetectionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROCESSING LATENCY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.processingTime > 0
              ? '${result.processingTime.toStringAsFixed(2)}s'
              : '< 1.0s',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Bottom Actions ────────────────────────────────────────────────────────
  Widget _buildBottomActions(BuildContext context, String downloadFilename) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final downloadBtn = ElevatedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final success =
                await ApiService.downloadDocument(downloadFilename);
            messenger.showSnackBar(
              SnackBar(
                content: Text(success
                    ? 'Redacted file saved to Downloads'
                    : 'Download failed. Please try again.'),
                backgroundColor:
                    success ? AppTheme.accentColor : AppTheme.dangerColor,
              ),
            );
          },
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Download Redacted Document'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
          ),
        );

        final processAnotherBtn = OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.refresh_outlined, size: 16),
          label: const Text('Process Another Document'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              downloadBtn,
              const SizedBox(height: 10),
              processAnotherBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: downloadBtn),
            const SizedBox(width: 12),
            processAnotherBtn,
          ],
        );
      },
    );
  }
}

// ── Redacted Document Preview Card (Preserving Full Working Logic) ──────────

class _RedactedDocumentPreviewCard extends StatefulWidget {
  final String filename;
  final String originalFilename;
  final String docType;

  const _RedactedDocumentPreviewCard({
    required this.filename,
    required this.originalFilename,
    required this.docType,
  });

  @override
  State<_RedactedDocumentPreviewCard> createState() =>
      _RedactedDocumentPreviewCardState();
}

class _RedactedDocumentPreviewCardState
    extends State<_RedactedDocumentPreviewCard> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _RedactedDocumentPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filename != widget.filename) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getDocumentPreview(widget.filename);
      if (!mounted) return;
      if (data != null && data['success'] == true) {
        setState(() {
          _previewData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Preview could not be loaded for this document.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading preview: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await ApiService.downloadDocument(widget.filename);
      messenger.showSnackBar(
        SnackBar(
          content: Text(success
              ? 'File downloaded to Downloads folder'
              : 'Download failed. Please try again.'),
          backgroundColor:
              success ? AppTheme.accentColor : AppTheme.dangerColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  void _openLightbox(BuildContext context, Uint8List bytes, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppTheme.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Redacted Preview — $title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: Colors.white70, size: 20),
                      tooltip: 'Download',
                      onPressed: _downloadFile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedactedBadge() {
    return const PrivLockBadge(
      label: 'REDACTED',
      icon: Icons.shield_outlined,
      variant: BadgeVariant.success,
      isPill: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPdf = widget.filename.toLowerCase().endsWith('.pdf') ||
        widget.originalFilename.toLowerCase().endsWith('.pdf');
    final bool isImage = _previewData?['isImage'] == true;
    final bool isText = _previewData?['isText'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final bool isNarrow = headerConstraints.maxWidth < 450;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow) ...[
                            const Text(
                              'Redacted Document Preview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.slate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildRedactedBadge(),
                          ] else ...[
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Redacted Document Preview',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.slate900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildRedactedBadge(),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          const Text(
                            'Visual preview of sanitized output. Sensitive PII has been redacted.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, color: AppTheme.slate200),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(context, isPdf, isImage, isText),
          ),

          // ── Actions Footer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(color: AppTheme.slate200),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _downloadFile,
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: const Text('Download Redacted File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (isImage && _previewData?['bytes'] != null)
                            OutlinedButton.icon(
                              onPressed: () => _openLightbox(
                                context,
                                _previewData!['bytes'] as Uint8List,
                                widget.originalFilename,
                              ),
                              icon: const Icon(Icons.fullscreen_outlined,
                                  size: 16),
                              label: const Text('Enlarge Preview'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(
                                    color: AppTheme.slate200),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isText && _previewData?['text'] != null)
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                                text: _previewData!['text'] as String),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Redacted text copied to clipboard'),
                              backgroundColor: AppTheme.accentColor,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 14),
                        label: const Text('Copy Redacted Text'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.slate600,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, bool isPdf, bool isImage, bool isText) {
    if (_isLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Loading redacted preview...',
              style: TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
          ],
        ),
      );
    }

    if (_error != null || _previewData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: AppTheme.dangerColor),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Unable to display preview.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.slate800),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can still download the full redacted file using the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.slate500),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadPreview,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry Preview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                minimumSize: const Size(0, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    // ── Visual Image / PDF Preview ──────────────────────────────────────────
    if (isImage && _previewData?['bytes'] != null) {
      final bytes = _previewData!['bytes'] as Uint8List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPdf)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFF1D4ED8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Page 1 Preview — Complete Redacted PDF Available for Download',
                      style: TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openLightbox(context, bytes, widget.originalFilename),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 450),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Click to Zoom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Text Document Preview ───────────────────────────────────────────────
    if (isText && _previewData?['text'] != null) {
      final text = _previewData!['text'] as String;
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppTheme.slate800,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
