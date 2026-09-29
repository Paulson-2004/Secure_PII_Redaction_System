import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/pipeline_stepper.dart';
import '../widgets/privlock_badge.dart';
import '../widgets/user_avatar_button.dart';
import 'audit_logs_screen.dart';
import 'result_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _selectedDocType = 'aadhaar';
  String _selectedAction = 'redact';
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _systemHealth;
  String? _systemHealthError;
  bool _loadingSystemHealth = true;

  @override
  void initState() {
    super.initState();
    _loadSystemHealth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DocumentProvider>().loadAuditLogs();
      }
    });
  }

  Future<void> _loadSystemHealth() async {
    try {
      final health = await ApiService.getSystemHealth();
      if (!mounted) return;
      setState(() {
        _systemHealth = health['data'] is Map<String, dynamic>
            ? health['data'] as Map<String, dynamic>
            : null;
        _systemHealthError = null;
        _loadingSystemHealth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _systemHealth = null;
        _systemHealthError = e.toString();
        _loadingSystemHealth = false;
      });
    }
  }

  final List<Map<String, dynamic>> _docTypes = [
    {'value': 'aadhaar', 'label': 'Aadhaar Card', 'icon': Icons.badge_outlined},
    {'value': 'pan', 'label': 'PAN Card', 'icon': Icons.credit_card_outlined},
    {'value': 'driving_license', 'label': 'Driving License', 'icon': Icons.directions_car_outlined},
    {'value': 'voter_id', 'label': 'Voter ID', 'icon': Icons.how_to_vote_outlined},
    {'value': 'passport', 'label': 'Passport', 'icon': Icons.airplanemode_active_outlined},
    {'value': 'bank_statement', 'label': 'Bank Statement', 'icon': Icons.account_balance_outlined},
    {'value': 'invoice', 'label': 'Invoice', 'icon': Icons.receipt_outlined},
    {'value': 'contract', 'label': 'Contract', 'icon': Icons.description_outlined},
    {'value': 'general', 'label': 'General Document', 'icon': Icons.document_scanner_outlined},
  ];

  final List<Map<String, dynamic>> _actions = [
    {
      'value': 'redact',
      'label': 'Redact',
      'tag': 'Recommended',
      'icon': Icons.block_outlined,
      'description': 'Permanent solid blackout of sensitive PII elements'
    },
    {
      'value': 'mask',
      'label': 'Mask',
      'tag': 'Partial',
      'icon': Icons.visibility_off_outlined,
      'description': 'Conceal sensitive characters with format-preserving hashes'
    },
    {
      'value': 'blur',
      'label': 'Blur',
      'tag': 'Visual',
      'icon': Icons.blur_on_outlined,
      'description': 'Apply Gaussian smoothing over detected document zones'
    },
  ];

  final List<Map<String, dynamic>> _aiModules = [
    {
      'name': 'OCR Engine',
      'detail': 'Tesseract + Preprocessing',
      'icon': Icons.document_scanner_outlined,
      'status': 'ACTIVE',
    },
    {
      'name': 'Regex Engine',
      'detail': '8 Indian ID Patterns',
      'icon': Icons.code_rounded,
      'status': 'ACTIVE',
    },
    {
      'name': 'NER Engine',
      'detail': 'spaCy Transformer NLP',
      'icon': Icons.psychology_outlined,
      'status': 'ACTIVE',
    },
    {
      'name': 'Hybrid Fusion',
      'detail': 'Confidence Calibration',
      'icon': Icons.hub_outlined,
      'status': 'ACTIVE',
    },
    {
      'name': 'Policy Engine',
      'detail': 'FAISS Regulatory RAG',
      'icon': Icons.gavel_outlined,
      'status': 'ACTIVE',
    },
    {
      'name': 'Redactor',
      'detail': 'Dual Image + Text Masking',
      'icon': Icons.lock_outline,
      'status': 'ACTIVE',
    },
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'docx',
        'doc',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp'
      ],
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result != null) {
      final picked = result.files.single;
      setState(() {
        _selectedFileName = picked.name;
        if (kIsWeb) {
          _selectedFile = null;
          _selectedFileBytes = picked.bytes;
        } else {
          _selectedFileBytes = null;
          _selectedFile = File(picked.path!);
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedFile = null;
          _selectedFileBytes = bytes;
          _selectedFileName = image.name;
        });
      } else {
        setState(() {
          _selectedFile = File(image.path);
          _selectedFileBytes = null;
          _selectedFileName = image.name;
        });
      }
    }
  }

  void _showFileSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Document Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_present_outlined,
                      color: AppTheme.primaryColor),
                ),
                title: const Text('Local Files (PDF, Images, DOCX, TXT)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Browse files from your system storage',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.accentColor),
                ),
                title: const Text('Photo Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select an image from gallery',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (!kIsWeb) ...[
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.purpleLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: AppTheme.purpleColor),
                  ),
                  title: const Text('Camera Scanner',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Capture a document photo with your camera',
                      style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processDocument() async {
    if (_selectedFile == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    final docProvider = context.read<DocumentProvider>();
    final success = await docProvider.processDocument(
      file: _selectedFile,
      fileBytes: _selectedFileBytes,
      fileName: _selectedFileName,
      docType: _selectedDocType,
      action: _selectedAction,
    );

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(docProvider.errorMessage),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.slate700),
            tooltip: 'Navigation Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PrivLock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Intelligent PII Detection & Redaction',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (screenWidth >= 768) ...[
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.dashboard_outlined, size: 16),
              label: const Text('Dashboard'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                );
              },
              icon: const Icon(Icons.history_outlined, size: 16),
              label: const Text('Audit Logs'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.slate600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          const UserAvatarButton(),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        currentRoute: 'dashboard',
        onMenuItemSelected: (menuItem) {
          if (menuItem == 'upload') {
            _showFileSourceSheet();
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welcome Banner ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${auth.username.isNotEmpty ? auth.username : 'Analyst'} 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slate900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload government IDs or business documents to automatically detect, mask, and redact sensitive PII.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const PrivLockBadge(
                      label: 'ALL SYSTEMS OPERATIONAL',
                      icon: Icons.check_circle_outline,
                      variant: BadgeVariant.success,
                      isPill: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── AI Modules Status Row ───────────────────────────────────
                _buildAiModulesRow(),

                const SizedBox(height: 24),

                // ── Main Responsive Workspace ───────────────────────────────
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildUploadStudioCard(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildRecentActivityCard(),
                            const SizedBox(height: 20),
                            _buildSystemHealthCard(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildUploadStudioCard(),
                      const SizedBox(height: 20),
                      _buildRecentActivityCard(),
                      const SizedBox(height: 20),
                      _buildSystemHealthCard(),
                    ],
                  ),

                const SizedBox(height: 28),

                // ── Pipeline Architecture Stepper ───────────────────────────
                const PipelineStepper(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AI Modules Bar ────────────────────────────────────────────────────────
  Widget _buildAiModulesRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _aiModules.map((m) {
            final double cardWidth = constraints.maxWidth > 1100
                ? (constraints.maxWidth - (5 * 10)) / 6
                : constraints.maxWidth > 700
                    ? (constraints.maxWidth - (2 * 10)) / 3
                    : (constraints.maxWidth - 10) / 2;

            return Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      m['icon'] as IconData,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m['name'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          m['detail'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Upload & Redaction Studio (Primary Card) ──────────────────────────────
  Widget _buildUploadStudioCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Document Redaction Studio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select document classification, choose privacy policy, and process files through the hybrid engine.',
            style: TextStyle(fontSize: 12, color: AppTheme.slate500),
          ),
          const SizedBox(height: 18),

          // ── Step 1: Document Type ──
          _stepHeader('1', 'Select Document Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _docTypes.map((dt) {
              final isSelected = dt['value'] == _selectedDocType;
              return ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  dt['icon'] as IconData,
                  size: 15,
                  color: isSelected ? Colors.white : AppTheme.slate600,
                ),
                label: Text(dt['label'] as String),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.slate50,
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.slate200,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.slate800,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedDocType = dt['value'] as String);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // ── Step 2: Redaction Action ──
          _stepHeader('2', 'Choose Redaction Policy Action'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _actions.map((act) {
                  final isSelected = act['value'] == _selectedAction;
                  final double width = constraints.maxWidth > 550
                      ? (constraints.maxWidth - (2 * 10)) / 3
                      : constraints.maxWidth;

                  return InkWell(
                    onTap: () => setState(() => _selectedAction = act['value'] as String),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryLight : AppTheme.slate50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.slate200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                act['icon'] as IconData,
                                size: 18,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.slate600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  act['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.slate900,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    size: 16, color: AppTheme.primaryColor),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            act['description'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? const Color(0xFF1D4ED8)
                                  : AppTheme.slate500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 22),

          // ── Step 3: Document Upload Dropzone ──
          _stepHeader('3', 'Select or Drop Document'),
          const SizedBox(height: 10),
          if (_selectedFile != null || _selectedFileBytes != null)
            _FilePreviewCard(
              file: _selectedFile,
              fileBytes: _selectedFileBytes,
              fileName: _selectedFileName,
              onReplace: _showFileSourceSheet,
            )
          else
            _UploadPlaceholder(onTap: _showFileSourceSheet),

          const SizedBox(height: 24),

          // ── Step 4: Process Button ──
          Consumer<DocumentProvider>(
            builder: (_, docProvider, __) {
              final canProcess = !docProvider.isProcessing &&
                  (_selectedFile != null || _selectedFileBytes != null);

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: canProcess ? _processDocument : null,
                      icon: docProvider.isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.shield_outlined, size: 18),
                      label: Text(
                        docProvider.isProcessing
                            ? 'Processing Document with AI Pipeline...'
                            : 'Process & Redact Document',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.slate200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (docProvider.isProcessing) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_mode_outlined,
                              size: 16, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OCR text extraction → Hybrid Regex/NER detection → FAISS policy decision → Redaction generation...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Recent Activity Card ──────────────────────────────────────────────────
  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_outlined,
                      size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Recent Processing Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                  );
                },
                child: const Text('View all →', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<DocumentProvider>(
            builder: (_, docProvider, __) {
              final logs = docProvider.auditLogs;
              if (docProvider.isLoadingLogs && logs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (logs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: const Column(
                    children: [
                      Icon(Icons.history_edu_outlined,
                          size: 36, color: AppTheme.slate300),
                      SizedBox(height: 8),
                      Text(
                        'No documents processed yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Uploaded files will appear here with audit details.',
                        style: TextStyle(fontSize: 11, color: AppTheme.slate400),
                      ),
                    ],
                  ),
                );
              }

              // Show top 5 recent records
              final recentList = logs.take(5).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final log = recentList[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: AppTheme.slate600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.filename,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log.documentType.toUpperCase()} • ${log.processingTime.toStringAsFixed(1)}s',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PrivLockBadge(
                          label: '${log.piiCount} PII',
                          variant: log.piiCount > 0
                              ? BadgeVariant.danger
                              : BadgeVariant.success,
                          fontSize: 10,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.download_outlined, size: 18),
                          tooltip: 'Download file',
                          color: AppTheme.slate600,
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success =
                                await ApiService.downloadDocument(log.filename);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Downloaded ${log.filename}'
                                    : 'Download failed'),
                                backgroundColor: success
                                    ? AppTheme.accentColor
                                    : AppTheme.dangerColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── System Health & Compliance Card ───────────────────────────────────────
  Widget _buildSystemHealthCard() {
    final bool apiOnline = _systemHealth != null &&
        (_systemHealth!['backend'] == 'running' || _systemHealth!['backend'] == 'ok');
    final bool dbOnline = _systemHealth != null &&
        (_systemHealth!['database'] == 'connected' || _systemHealth!['database'] == 'ok');

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      size: 18, color: AppTheme.accentColor),
                  SizedBox(width: 8),
                  Text(
                    'Live System Monitor',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
              if (_loadingSystemHealth)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (_systemHealthError != null)
                const Text('Offline', style: TextStyle(fontSize: 11, color: AppTheme.dangerColor))
              else
                const Text('Synced', style: TextStyle(fontSize: 11, color: AppTheme.accentColor)),
            ],
          ),
          const SizedBox(height: 12),
          _healthRow(
            'API Gateway (Flask)',
            apiOnline ? 'ONLINE' : (_loadingSystemHealth ? 'CHECKING...' : 'DISCONNECTED'),
            apiOnline ? AppTheme.accentColor : AppTheme.dangerColor,
          ),
          const SizedBox(height: 8),
          _healthRow(
            'Database Engine (MySQL)',
            dbOnline ? 'CONNECTED' : (_loadingSystemHealth ? 'CHECKING...' : 'DEGRADED'),
            dbOnline ? AppTheme.accentColor : AppTheme.dangerColor,
          ),
          const SizedBox(height: 8),
          _healthRow(
            'Regulatory Policy Engine',
            'ACTIVE (FAISS)',
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 8),
          _healthRow(
            'Privacy Compliance',
            'DPDP & UIDAI Standards',
            const Color(0xFF6D28D9),
          ),
        ],
      ),
    );
  }

  Widget _healthRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate600)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate800,
          ),
        ),
      ],
    );
  }
}

// ── Dropzone & Preview Subwidgets ───────────────────────────────────────────

class _UploadPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF93C5FD),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Click to upload or drag & drop document',
              style: TextStyle(
                color: AppTheme.slate900,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Supported Formats: PDF, PNG, JPG, WEBP, DOCX, TXT • Max 16 MB',
              style: TextStyle(color: AppTheme.slate500, fontSize: 11),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Browse Files'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                side: const BorderSide(color: AppTheme.primaryColor),
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  final File? file;
  final Uint8List? fileBytes;
  final String? fileName;
  final VoidCallback onReplace;

  const _FilePreviewCard({
    this.file,
    this.fileBytes,
    this.fileName,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedFileName = fileName ??
        (file != null ? file!.path.split(RegExp(r'[\\/]')).last : 'selected_file');
    final fileExt = resolvedFileName.contains('.')
        ? resolvedFileName.split('.').last.toLowerCase()
        : '';
    final isImageType = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        children: [
          if (isImageType && fileBytes != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.memory(fileBytes!,
                  width: double.infinity, height: 180, fit: BoxFit.contain),
            )
          else if (isImageType && file != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.file(file!,
                  width: double.infinity, height: 180, fit: BoxFit.contain),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  fileExt == 'pdf'
                      ? Icons.picture_as_pdf
                      : Icons.insert_drive_file_outlined,
                  color: fileExt == 'pdf'
                      ? AppTheme.dangerColor
                      : AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedFileName,
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
                        'Ready for PII redaction pipeline',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onReplace,
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Change'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
