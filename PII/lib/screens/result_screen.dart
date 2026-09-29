import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = context.watch<DocumentProvider>().lastResult;
    if (result == null) {
      return const Scaffold(body: Center(child: Text('No result available')));
    }
    final downloadFilename =
        result.redactedFilename.isNotEmpty ? result.redactedFilename : result.filename;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Result'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                  final success =
                      await ApiService.downloadDocument(downloadFilename);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('File downloaded to Downloads folder'),
                      backgroundColor: Color(0xFF34A853),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Download failed. Please try again.'),
                      backgroundColor: Color(0xFFEA4335),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Download error: $e'),
                    backgroundColor: const Color(0xFFEA4335),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary cards ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'PII Found',
                    value: '${result.piiCount}',
                    color: result.piiCount > 0
                        ? const Color(0xFFEA4335)
                        : const Color(0xFF34A853),
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Action',
                    value: result.action.toUpperCase(),
                    color: const Color(0xFF1A73E8),
                    icon: Icons.build_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Redacted Document Preview ─────────────────────────────────
            _RedactedDocumentPreviewCard(
              filename: downloadFilename,
              originalFilename: result.originalFilename,
              docType: result.docType,
            ),

            const SizedBox(height: 24),

            // ── File info ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EAED)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.originalFilename,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${result.docType} • ${result.action}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  _StatusBadge(
                      result.status == 'processed' ? 'Processed' : 'Failed'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Processing summary ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EAED)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Processing Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.redactionSummary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Processed at: ${result.processedAt}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Detected PII list ─────────────────────────────────────────
            if (result.piiDetected.isEmpty) ...[
              const _EmptyState(
                icon: Icons.verified_outlined,
                title: 'No PII detected',
                subtitle: 'This document appears clean.',
              ),
            ] else ...[
              Text(
                'Detected PII Types (${result.piiDetected.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              ...result.piiDetected
                  .map((piiType) => _PiiTypeCard(piiType: piiType)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'processed':
        color = const Color(0xFF34A853);
        break;
      case 'failed':
        color = const Color(0xFFEA4335);
        break;
      default:
        color = const Color(0xFF9CA3AF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _PiiTypeCard extends StatelessWidget {
  final String piiType;

  const _PiiTypeCard({required this.piiType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: Color(0xFFEA4335), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              piiType.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
        ],
      ),
    );
  }
}

// ── Redacted Document Preview Card ──────────────────────────────────────────

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
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('File downloaded to Downloads folder'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Download failed. Please try again.'),
            backgroundColor: Color(0xFFEA4335),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: const Color(0xFFEA4335),
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
                        color: Color(0xFF34A853), size: 20),
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
              // Zoomable Image
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF34A853).withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: Color(0xFF34A853)),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Redacted Output',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF34A853),
              ),
            ),
          ),
        ],
      ),
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
        border: Border.all(color: const Color(0xFFE8EAED)),
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
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        color: Color(0xFF1A73E8),
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
                                color: Color(0xFF1A1A2E),
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
                                      color: Color(0xFF1A1A2E),
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
                              color: Color(0xFF6B7280),
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

          const Divider(height: 1, color: Color(0xFFF1F3F4)),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(context, isPdf, isImage, isText),
          ),

          // ── Actions Footer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(color: Color(0xFFF1F3F4)),
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
                              backgroundColor: const Color(0xFF1A73E8),
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
                                foregroundColor: const Color(0xFF1A73E8),
                                side: const BorderSide(
                                    color: Color(0xFFDADCE0)),
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
                              backgroundColor: Color(0xFF34A853),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 14),
                        label: const Text('Copy Redacted Text'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5F6368),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Loading redacted preview...',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
                size: 40, color: Color(0xFFEA4335)),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Unable to display preview.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can still download the full redacted file using the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadPreview,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry Preview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
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
                color: const Color(0xFFEFF6FF),
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
                      'Page 1 Preview — Full Redacted PDF Available for Download',
                      style: TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                    constraints: const BoxConstraints(maxHeight: 380),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Click to zoom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _previewData!['text'] as String,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
        ),
      );
    }

    // ── Non-visual Placeholder ──────────────────────────────────────────────
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.shield_outlined, size: 48, color: Color(0xFF1A73E8)),
          SizedBox(height: 12),
          Text(
            'Redacted Document Ready',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Visual preview is not supported for this file format, but your redacted document has been generated securely.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
