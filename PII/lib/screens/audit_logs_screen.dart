import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../models/audit_log.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DocumentProvider>().loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => context.read<DocumentProvider>().loadAuditLogs(),
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (_, provider, __) {
          if (provider.isLoadingLogs) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.auditLogs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 56, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 16),
                  Text('No processing history yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                  SizedBox(height: 6),
                  Text('Upload a document to get started',
                      style: TextStyle(color: Color(0xFF9CA3AF))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.auditLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _LogCard(log: provider.auditLogs[i]),
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final AuditLog log;
  const _LogCard({required this.log});

  String get _docTypeLabel {
    switch (log.documentType) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'pan':
        return 'PAN Card';
      case 'driving_license':
        return 'Driving License';
      case 'voter_id':
        return 'Voter ID';
      default:
        return 'Unknown';
    }
  }

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
          // Left icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_outlined,
                color: Color(0xFF1A73E8), size: 22),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.filename.length > 28
                      ? '${log.filename.substring(0, 25)}…'
                      : log.filename,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 2),
                Text(_docTypeLabel,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Chip(
                        label: '${log.piiCount} PII found',
                        color: log.piiCount > 0
                            ? const Color(0xFFEA4335)
                            : const Color(0xFF34A853)),
                    const SizedBox(width: 6),
                    _Chip(
                        label: '${log.processingTime.toStringAsFixed(1)}s',
                        color: const Color(0xFF6B7280)),
                  ],
                ),
              ],
            ),
          ),

          // Log ID
          Text(
            '#${log.id}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
