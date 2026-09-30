import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/image_display_geometry.dart';
import '../models/manual_region.dart';
import '../models/pdf_page_geometry.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/external_launcher.dart';
import '../widgets/app_drawer.dart';
import '../widgets/pipeline_stepper.dart';
import '../widgets/privlock_badge.dart';
import '../widgets/user_avatar_button.dart';
import 'audit_logs_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'result_screen.dart';

enum HealthCheckStatus {
  checking,
  connected,
  disconnected,
}

class DashboardScreen extends StatefulWidget {
  final String? initialAction;

  const DashboardScreen({super.key, this.initialAction});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _uploadStudioKey = GlobalKey();

  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  Size? _sourceImageSize;
  Map<int, Size> _pdfPageSizes = {};
  String _selectedDocType = 'aadhaar';
  String _selectedAction = 'redact';
  String _selectedDetectionMode = 'automatic';
  final List<ManualRegion> _manualRegions = [];
  int _selectedManualPage = 1;
  int _maxSelectablePages = 5;
  int _nextRegionId = 1;
  Offset? _panStartOffset;
  Offset? _panCurrentOffset;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _systemHealth;
  String? _systemHealthError;
  bool _loadingSystemHealth = true;
  HealthCheckStatus _healthStatus = HealthCheckStatus.checking;
  int _healthCheckGeneration = 0;
  Timer? _healthRetryTimer;

  @override
  void initState() {
    super.initState();
    _loadSystemHealth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated) {
          context.read<DocumentProvider>().loadAuditLogs();
        }
        if (widget.initialAction == 'upload') {
          _scrollToUploadStudio();
        }
      }
    });
  }

  void _openAuditLogs() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.history_outlined, color: Color(0xFF1A73E8)),
              SizedBox(width: 8),
              Text('Audit Logs',
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
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
    );
  }

  Timer? _healthRetryTimer;

  @override
  void dispose() {
    _healthRetryTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToUploadStudio() {
    final ctx = _uploadStudioKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadSystemHealth() async {
    _healthRetryTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _loadingSystemHealth = true;
    });
  Future<void> loadSystemHealth({int retryCount = 0, int? generation}) async {
    if (generation == null) {
      _healthRetryTimer?.cancel();
      _healthCheckGeneration++;
      generation = _healthCheckGeneration;
      if (!mounted) return;
      setState(() {
        if (_systemHealth == null) {
          _healthStatus = HealthCheckStatus.checking;
        }
      });
    }

    try {
      final health = await ApiService.getSystemHealth();
      if (!mounted) return;
      if (!mounted || generation != _healthCheckGeneration) return;
      final data = health['data'] is Map<String, dynamic>
          ? health['data'] as Map<String, dynamic>
          : null;
      if (data != null && data['backend'] == 'running') {
      if ((data['backend'] == 'running' || data['backend'] == 'ok')) {
        setState(() {
          _systemHealth = data;
          _systemHealthError = null;
          _loadingSystemHealth = false;
          _healthStatus = HealthCheckStatus.connected;
        });
        return;
      }
      throw Exception(health['message'] ?? 'Backend response invalid');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _systemHealth = null;
        _systemHealthError = e.toString();
        _loadingSystemHealth = false;
      });
      if (!mounted || generation != _healthCheckGeneration) return;

      // Auto-retry up to 3 times with 5s backoff if initial health check fails (e.g. cloud cold start)
      if (retryCount < 3 && mounted) {
      // Auto-retry up to 3 times with 5s backoff if health check fails (e.g. cloud cold start)
      if (retryCount < 3) {
        setState(() {
          if (_systemHealth == null) {
            _healthStatus = HealthCheckStatus.checking;
          }
        });
        final int nextRetry = retryCount + 1;
        final int targetGen = generation;
        _healthRetryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _systemHealth == null) {
            loadSystemHealth(retryCount: retryCount + 1);
          if (mounted && targetGen == _healthCheckGeneration && _healthStatus != HealthCheckStatus.connected) {
            loadSystemHealth(retryCount: nextRetry, generation: targetGen);
          }
        });
      } else {
        // Genuine failure after all retries exhausted:
        setState(() {
          _systemHealth = null;
          _healthStatus = HealthCheckStatus.disconnected;
        });
      }
    }
  }

  final List<Map<String, dynamic>> docTypes = [
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

  final List<Map<String, dynamic>> actions = [
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

  final List<Map<String, dynamic>> detectionModes = [
    {
      'value': 'automatic',
      'label': 'Automatic PII Detection',
      'tag': 'AI Pipeline',
      'icon': Icons.auto_awesome_outlined,
      'description': 'Full AI pipeline: OCR + Regex + spaCy NER + Regulatory Policy Engine',
    },
    {
      'value': 'manual',
      'label': 'Manual Selection',
      'tag': 'User Regions Only',
      'icon': Icons.highlight_alt_outlined,
      'description': 'Redact ONLY regions you explicitly select on the document. Outside text remains untouched.',
    },
    {
      'value': 'automatic_manual',
      'label': 'Automatic + Manual',
      'tag': 'Hybrid Combined',
      'icon': Icons.layers_outlined,
      'description': 'Combines automated PII detections with your custom manual zones in a single pass.',
    },
  ];

  final List<Map<String, dynamic>> aiModules = [
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

  Future<void> resolveSourceImageDimensions([Uint8List? directBytes]) async {
    try {
      Uint8List? bytes = directBytes ?? _selectedFileBytes;
      if (bytes == null && _selectedFile != null) {
        bytes = await _selectedFile!.readAsBytes();
      }
      if (bytes != null && bytes.isNotEmpty) {
        final image = await decodeImageFromList(bytes);
        if (mounted) {
          setState(() {
            _sourceImageSize = Size(
              image.width.toDouble(),
              image.height.toDouble(),
            );
          });
        }
        image.dispose();
      }
    } catch (e) {
      debugPrint('Could not resolve image dimensions: $e');
    }
  }

  Future<void> resolvePdfPageDimensions([Uint8List? directBytes]) async {
    try {
      Uint8List? bytes = directBytes ?? _selectedFileBytes;
      if (bytes == null && _selectedFile != null) {
        bytes = await _selectedFile!.readAsBytes();
      }
      if (bytes != null && bytes.isNotEmpty) {
        final parsed = PdfPageGeometryParser.parsePageSizes(bytes);
        if (mounted) {
          setState(() {
            _pdfPageSizes = parsed;
            if (parsed.isNotEmpty && parsed.length > _maxSelectablePages) {
              _maxSelectablePages = parsed.length.clamp(1, 20);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Could not parse PDF page dimensions: $e');
    }
  }

  Size getActiveDocumentSize(double canvasWidth, double canvasHeight) {
    if (isImageFile()) {
      return _sourceImageSize ?? Size(canvasWidth, canvasHeight);
    }
    if (isPdfFile()) {
      if (_pdfPageSizes.containsKey(_selectedManualPage)) {
        return _pdfPageSizes[_selectedManualPage]!;
      }
      if (_pdfPageSizes.containsKey(1)) {
        return _pdfPageSizes[1]!;
      }
      return PdfPagePreset.a4Portrait.size;
    }
    return PdfPagePreset.a4Portrait.size;
  }

  Future<void> pickFile() async {
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
        _manualRegions.clear();
        _selectedManualPage = 1;
        _panStartOffset = null;
        _panCurrentOffset = null;
        _sourceImageSize = null;
        _pdfPageSizes = {};
        if (kIsWeb) {
          _selectedFile = null;
          _selectedFileBytes = picked.bytes;
        } else {
          _selectedFileBytes = null;
          _selectedFile = File(picked.path!);
        }
      });
      if (isImageFile()) {
        if (kIsWeb && picked.bytes != null) {
          resolveSourceImageDimensions(picked.bytes);
        } else if (picked.path != null) {
          resolveSourceImageDimensions();
        }
      } else if (isPdfFile()) {
        if (kIsWeb && picked.bytes != null) {
          resolvePdfPageDimensions(picked.bytes);
        } else if (picked.path != null) {
          resolvePdfPageDimensions();
        }
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (kIsWeb) {
        setState(() {
          _selectedFile = null;
          _selectedFileBytes = bytes;
          _selectedFileName = image.name;
          _manualRegions.clear();
          _selectedManualPage = 1;
          _panStartOffset = null;
          _panCurrentOffset = null;
          _sourceImageSize = null;
        });
      } else {
        setState(() {
          _selectedFile = File(image.path);
          _selectedFileBytes = bytes;
          _selectedFileName = image.name;
          _manualRegions.clear();
          _selectedManualPage = 1;
          _panStartOffset = null;
          _panCurrentOffset = null;
          _sourceImageSize = null;
        });
      }
      resolveSourceImageDimensions(bytes);
    }
  }

  bool isImageFile() {
    final name = _selectedFileName ?? (_selectedFile?.path ?? '');
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
  }

  bool isPdfFile() {
    final name = _selectedFileName ?? (_selectedFile?.path ?? '');
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return ext == 'pdf';
  }

  void showFileSourceSheet() {
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
                  pickFile();
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
                  pickImage(ImageSource.gallery);
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
                    pickImage(ImageSource.camera);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> processDocument() async {
    if (_selectedFile == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    if (_selectedDetectionMode != 'automatic' && _manualRegions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one manual region or switch mode to Automatic.'),
          backgroundColor: AppTheme.dangerColor,
        ),
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
      detectionMode: _selectedDetectionMode,
      manualRegions: _manualRegions.isNotEmpty
          ? _manualRegions.map((r) => r.toJson()).toList()
          : null,
    );

    if (success && mounted) {
      if (_systemHealth == null) {
        loadSystemHealth();
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      ).then((_) {
        if (mounted && _systemHealth == null) {
          loadSystemHealth();
        }
      });
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
          mainAxisSize: MainAxisSize.min,
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
            const Flexible(
              child: Column(
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Intelligent PII Detection & Redaction',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (screenWidth >= 768) ...[
            TextButton.icon(
              onPressed: () => launchExternalUrl(
                'https://github.com/Paulson-2004/Secure_PII_Redaction_System',
              ),
              icon: const Icon(Icons.code_rounded, size: 16),
              label: const Text('View Source'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.slate600,
              ),
            ),
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
              onPressed: _openAuditLogs,
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
            _scrollToUploadStudio();
          }
        },
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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
                            auth.isGuest
                                ? 'Welcome to PrivLock 👋'
                                : 'Welcome back, ${auth.username.isNotEmpty ? auth.username : 'Analyst'} 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slate900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.isGuest
                                ? 'Guest Mode: Redact sensitive PII without an account. Upload government IDs or documents to process immediately.'
                                : 'Upload government IDs or business documents to automatically detect, mask, and redact sensitive PII.',
                            style: const TextStyle(
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
                buildAiModulesRow(),

                const SizedBox(height: 24),

                // ── Main Responsive Workspace ───────────────────────────────
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: buildUploadStudioCard(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            buildRecentActivityCard(),
                            const SizedBox(height: 20),
                            buildSystemHealthCard(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      buildUploadStudioCard(),
                      const SizedBox(height: 20),
                      buildRecentActivityCard(),
                      const SizedBox(height: 20),
                      buildSystemHealthCard(),
                    ],
                  ),

                const SizedBox(height: 28),

                // ── Pipeline Architecture Stepper ───────────────────────────
                const PipelineStepper(),

                const SizedBox(height: 32),

                // ── Dashboard Footer ─────────────────────────────────────────
                buildDashboardFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dashboard Footer ───────────────────────────────────────────────────────
  Widget buildDashboardFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PrivLock — Intelligent PII Detection & Redaction System',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Authoritative Privacy & Security Policy Corpus • Hybrid AI & Manual Redaction',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.slate500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'PrivLock provides technical privacy/security guidance and automated redaction. It is not legal advice and does not certify regulatory compliance.',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.slate400,
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => launchExternalUrl(
              'https://github.com/Paulson-2004/Secure_PII_Redaction_System',
            ),
            icon: const Icon(Icons.code_rounded, size: 16),
            label: const Text('View Source'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.slate700,
              side: const BorderSide(color: AppTheme.slate300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Modules Bar ────────────────────────────────────────────────────────
  Widget buildAiModulesRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: aiModules.map((m) {
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
  Widget buildUploadStudioCard() {
    return Container(
      key: _uploadStudioKey,
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
          stepHeader('1', 'Select Document Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: docTypes.map((dt) {
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
          stepHeader('2', 'Choose Redaction Policy Action'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions.map((act) {
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
          stepHeader('3', 'Select or Drop Document'),
          const SizedBox(height: 10),
          if (_selectedFile != null || _selectedFileBytes != null)
            _FilePreviewCard(
              file: _selectedFile,
              fileBytes: _selectedFileBytes,
              fileName: _selectedFileName,
              onReplace: showFileSourceSheet,
            )
          else
            _UploadPlaceholder(onTap: showFileSourceSheet),

          const SizedBox(height: 22),

          // ── Step 4: Redaction & Detection Mode ──
          stepHeader('4', 'Select Detection & Redaction Mode'),
          const SizedBox(height: 10),
          buildDetectionModeSelector(),

          if (_selectedDetectionMode != 'automatic') ...[
            const SizedBox(height: 22),
            stepHeader('5', 'Interactive Manual Selection Studio'),
            const SizedBox(height: 10),
            buildManualSelectionStudio(),
          ],

          const SizedBox(height: 24),

          // ── Process Document Action ──
          buildProcessButtonSection(),
        ],
      ),
    );
  }

  Widget buildDetectionModeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: detectionModes.map((dm) {
            final isSelected = dm['value'] == _selectedDetectionMode;
            final double width = constraints.maxWidth > 550
                ? (constraints.maxWidth - (2 * 10)) / 3
                : constraints.maxWidth;

            return InkWell(
              onTap: () => setState(() => _selectedDetectionMode = dm['value'] as String),
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
                          dm['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.slate600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dm['label'] as String,
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
                      dm['description'] as String,
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
    );
  }

  Widget buildManualSelectionStudio() {
    final bool hasDocument = _selectedFile != null || _selectedFileBytes != null;
    final int pageRegionsCount = _manualRegions.where((r) => r.page == _selectedManualPage).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.crop_free_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Interactive Manual Selection Canvas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_manualRegions.length}/50 zones',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_manualRegions.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _manualRegions.clear();
                      _panStartOffset = null;
                      _panCurrentOffset = null;
                    });
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.dangerColor),
                  label: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Click and drag on the canvas to draw rectangular zones to redact, mask, or blur. In Manual mode, only marked zones will be treated.',
            style: TextStyle(fontSize: 11, color: AppTheme.slate600),
          ),
          const SizedBox(height: 12),

          // ── Page Selector (Support Multi-Page PDF & Documents) ──
          Row(
            children: [
              const Text('Target Page:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate700)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int p = 1; p <= _maxSelectablePages; p++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('Page $p'),
                            selected: _selectedManualPage == p,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedManualPage = p);
                            },
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: _selectedManualPage == p ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedManualPage == p ? Colors.white : AppTheme.slate700,
                            ),
                            selectedColor: AppTheme.primaryColor,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      if (_maxSelectablePages < 20)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                          tooltip: 'Add Page',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _maxSelectablePages++),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                'Page $_selectedManualPage: $pageRegionsCount zone(s)',
                style: const TextStyle(fontSize: 11, color: AppTheme.slate500, fontStyle: FontStyle.italic),
              ),
            ],
          ),

          // ── Detected Page Geometry Badge for PDF & Document Canvas ──
          if (isPdfFile() || !isImageFile()) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final Size activePageSize = getActiveDocumentSize(720, 360);
                final String pageDesc = PdfPagePreset.describeSize(activePageSize);
                final bool isDetected = _pdfPageSizes.containsKey(_selectedManualPage);

                return Row(
                  children: [
                    const Icon(Icons.aspect_ratio_outlined, size: 14, color: AppTheme.slate500),
                    const SizedBox(width: 6),
                    const Text('Page Geometry:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDetected ? Icons.lock_outline : Icons.description_outlined,
                            size: 12,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isDetected
                                ? 'Page $_selectedManualPage · $pageDesc'
                                : 'Page $_selectedManualPage · $pageDesc (Default)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),

          // ── Canvas Container ──
          if (!hasDocument)
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 36, color: AppTheme.slate400),
                    SizedBox(height: 8),
                    Text(
                      'Please select a document first to use the interactive selection canvas.',
                      style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double canvasWidth = constraints.maxWidth;
                const double canvasHeight = 360.0;

                final Size sourceSize = getActiveDocumentSize(canvasWidth, canvasHeight);

                final geometry = ImageDisplayGeometry(
                  sourceSize: sourceSize,
                  containerSize: Size(canvasWidth, canvasHeight),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                );

                return Container(
                  width: canvasWidth,
                  height: canvasHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Document background positioned strictly within geometry.imageRect
                      Positioned.fromRect(
                        rect: geometry.imageRect,
                        child: isImageFile()
                            ? (_selectedFileBytes != null
                                ? Image.memory(_selectedFileBytes!, fit: BoxFit.fill)
                                : (_selectedFile != null
                                    ? Image.file(_selectedFile!, fit: BoxFit.fill)
                                    : const SizedBox.shrink()))
                            : buildDocumentSheetCanvas(
                                geometry.imageRect.width,
                                geometry.imageRect.height,
                              ),
                      ),

                      // Existing regions for current page mapped back to display pixels
                      for (final region in _manualRegions.where((r) => r.page == _selectedManualPage))
                        Positioned.fromRect(
                          rect: geometry.normalizedToLocalRect(
                            region.x,
                            region.y,
                            region.width,
                            region.height,
                          ),
                          child: buildRegionOverlay(region),
                        ),

                      // In-progress drag box clamped to image display rect
                      if (_panStartOffset != null && _panCurrentOffset != null)
                        Builder(
                          builder: (context) {
                            final double clampedStartX = _panStartOffset!.dx.clamp(geometry.imageRect.left, geometry.imageRect.right);
                            final double clampedStartY = _panStartOffset!.dy.clamp(geometry.imageRect.top, geometry.imageRect.bottom);
                            final double clampedCurrX = _panCurrentOffset!.dx.clamp(geometry.imageRect.left, geometry.imageRect.right);
                            final double clampedCurrY = _panCurrentOffset!.dy.clamp(geometry.imageRect.top, geometry.imageRect.bottom);
                            final double left = math.min(clampedStartX, clampedCurrX);
                            final double top = math.min(clampedStartY, clampedCurrY);
                            final double width = (clampedCurrX - clampedStartX).abs();
                            final double height = (clampedCurrY - clampedStartY).abs();

                            if (width < 2 || height < 2) return const SizedBox.shrink();

                            return Positioned(
                              left: left,
                              top: top,
                              width: width,
                              height: height,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Draw Zone',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Drag gesture detector
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (details) {
                          setState(() {
                            _panStartOffset = details.localPosition;
                            _panCurrentOffset = details.localPosition;
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _panCurrentOffset = details.localPosition;
                          });
                        },
                        onPanEnd: (details) {
                          if (_panStartOffset != null && _panCurrentOffset != null) {
                            final Rect normRect = geometry.selectionToNormalizedRect(
                              _panStartOffset!,
                              _panCurrentOffset!,
                            );

                            final double pixelW = normRect.width * geometry.imageRect.width;
                            final double pixelH = normRect.height * geometry.imageRect.height;

                            if (pixelW >= 10 && pixelH >= 10) {
                              if (_manualRegions.length >= 50) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Maximum 50 manual regions reached.')),
                                );
                              } else {
                                setState(() {
                                  _manualRegions.add(
                                    ManualRegion(
                                      id: _nextRegionId++,
                                      x: double.parse(normRect.left.toStringAsFixed(4)),
                                      y: double.parse(normRect.top.toStringAsFixed(4)),
                                      width: double.parse(normRect.width.toStringAsFixed(4)),
                                      height: double.parse(normRect.height.toStringAsFixed(4)),
                                      page: _selectedManualPage,
                                      action: _selectedAction,
                                    ),
                                  );
                                });
                              }
                            }
                          }
                          setState(() {
                            _panStartOffset = null;
                            _panCurrentOffset = null;
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

          if (_manualRegions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _manualRegions.map((r) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.slate300),
                  avatar: Icon(
                    (r.action ?? 'redact') == 'redact'
                        ? Icons.block
                        : (r.action ?? 'redact') == 'blur'
                            ? Icons.blur_on
                            : Icons.visibility_off,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  label: Text(
                    'P${r.page}: ${(r.action ?? 'redact').toUpperCase()} (${(r.x * 100).toStringAsFixed(0)}%, ${(r.y * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  onDeleted: () {
                    setState(() {
                      _manualRegions.remove(r);
                    });
                  },
                  deleteIconColor: AppTheme.dangerColor,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildRegionOverlay(ManualRegion region) {
    Color bg;
    String tag;
    switch ((region.action ?? 'redact').toLowerCase()) {
      case 'mask':
        bg = const Color(0xDD0F172A);
        tag = '****';
        break;
      case 'blur':
        bg = const Color(0xB3475569);
        tag = 'BLUR';
        break;
      case 'redact':
      default:
        bg = const Color(0xE6000000);
        tag = 'REDACT';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _manualRegions.remove(region);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 8, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDocumentSheetCanvas(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isPdfFile()
                          ? Icons.picture_as_pdf
                          : Icons.description_outlined,
                      size: 16,
                      color: isPdfFile()
                          ? AppTheme.dangerColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 'Document Page $_selectedManualPage',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.slate800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PAGE $_selectedManualPage',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.slate600),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          for (int i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 8,
                width: (i % 2 == 0) ? double.infinity : width * 0.55,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          const Spacer(),
          const Center(
            child: Text(
              'Drag rectangle anywhere on this page canvas to set redaction bounds',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.slate400),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProcessButtonSection() {
    return Consumer<DocumentProvider>(
      builder: (_, docProvider, __) {
        final canProcess = !docProvider.isProcessing &&
            (_selectedFile != null || _selectedFileBytes != null) &&
            (_selectedDetectionMode == 'automatic' || _manualRegions.isNotEmpty);

        final String buttonLabel = docProvider.isProcessing
            ? 'Processing Document with AI Pipeline...'
            : _selectedDetectionMode == 'automatic'
                ? 'Process & Redact Document (Automatic AI)'
                : _selectedDetectionMode == 'manual'
                    ? 'Process & Redact Document (${_manualRegions.length} Manual Zones)'
                    : 'Process & Redact Document (Automatic + ${_manualRegions.length} Manual)';

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: canProcess ? processDocument : null,
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
                  buttonLabel,
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
                child: Row(
                  children: [
                    const Icon(Icons.auto_mode_outlined,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDetectionMode == 'manual'
                            ? 'Applying ${_manualRegions.length} manual redaction zones → Preserving unselected content intact → Generating secure output...'
                            : _selectedDetectionMode == 'automatic_manual'
                                ? 'OCR text extraction → Hybrid AI detection → Merging ${_manualRegions.length} manual zones → Generating redacted document...'
                                : 'OCR text extraction → Hybrid Regex/NER detection → FAISS policy decision → Redaction generation...',
                        style: const TextStyle(
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
    );
  }

  // ── Recent Activity Card ──────────────────────────────────────────────────
  Widget buildRecentActivityCard() {
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.history_outlined,
                        size: 18, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Processing Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openAuditLogs,
                child: const Text('View all →', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<DocumentProvider>(
            builder: (_, docProvider, __) {
              final auth = context.watch<AuthProvider>();
              if (auth.isGuest) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.history_toggle_off_outlined,
                          size: 36, color: AppTheme.primaryColor),
                      const SizedBox(height: 10),
                      const Text(
                        'Document History is Available with an Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Want to keep your redaction history? Create a free account to save and access your previous redactions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.slate600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_add_outlined, size: 14),
                        label: const Text('Create Free Account',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }

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
  Widget buildSystemHealthCard() {
    final bool apiOnline = _systemHealth != null &&
    final bool isChecking = _healthStatus == HealthCheckStatus.checking;
    final bool isConnected = _healthStatus == HealthCheckStatus.connected;
    final bool apiOnline = isConnected &&
        _systemHealth != null &&
        (_systemHealth!['backend'] == 'running' ||
            _systemHealth!['backend'] == 'ok' ||
            _systemHealth!['api_gateway'] == 'online' ||
            _systemHealth!['status'] == 'healthy' ||
            _systemHealth!['status'] == 'degraded');
    final bool dbOnline = _systemHealth != null &&
    final bool dbOnline = isConnected &&
        _systemHealth != null &&
        (_systemHealth!['database'] == 'connected' ||
            _systemHealth!['database'] == 'ok');
    final String? rawEngine = _systemHealth?['database_engine']?.toString();
    final String dbEngineLabel = (rawEngine != null && rawEngine.isNotEmpty)
        ? 'Database Engine ($rawEngine)'
        : 'Database Engine';

    final String apiStatusText = isChecking
        ? 'Checking...'
        : (apiOnline ? 'Connected' : 'Disconnected');
    final Color apiStatusColor = isChecking
        ? AppTheme.slate500
        : (apiOnline ? AppTheme.accentColor : AppTheme.dangerColor);

    final String dbStatusText = isChecking
        ? 'Checking...'
        : (dbOnline ? 'Connected' : 'Disconnected');
    final Color dbStatusColor = isChecking
        ? AppTheme.slate500
        : (dbOnline ? AppTheme.accentColor : AppTheme.dangerColor);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: AppTheme.slate500),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 14,
                    tooltip: 'Refresh system health',
                    onPressed: _loadingSystemHealth ? null : () => loadSystemHealth(),
                    onPressed: isChecking ? null : () => loadSystemHealth(),
                  ),
                  const SizedBox(width: 4),
                  if (_loadingSystemHealth)
                  if (isChecking) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else if (_systemHealthError != null || !apiOnline)
                    const Text('Offline', style: TextStyle(fontSize: 11, color: AppTheme.dangerColor))
                    ),
                    const SizedBox(width: 6),
                    const Text('Checking...', style: TextStyle(fontSize: 11, color: AppTheme.slate500)),
                  ] else if (!apiOnline)
                    const Text('Disconnected', style: TextStyle(fontSize: 11, color: AppTheme.dangerColor))
                  else if (!dbOnline)
                    const Text('Degraded', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)))
                  else
                    const Text('Synced', style: TextStyle(fontSize: 11, color: AppTheme.accentColor)),
                    const Text('Connected', style: TextStyle(fontSize: 11, color: AppTheme.accentColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          healthRow(
            'API Gateway (Flask)',
            apiOnline ? 'ONLINE' : (_loadingSystemHealth ? 'CHECKING...' : 'DISCONNECTED'),
            apiOnline ? AppTheme.accentColor : AppTheme.dangerColor,
            apiStatusText,
            apiStatusColor,
          ),
          const SizedBox(height: 8),
          healthRow(
            dbEngineLabel,
            dbOnline ? 'CONNECTED' : (_loadingSystemHealth ? 'CHECKING...' : 'DISCONNECTED'),
            dbOnline ? AppTheme.accentColor : AppTheme.dangerColor,
            dbStatusText,
            dbStatusColor,
          ),
          const SizedBox(height: 8),
          healthRow(
            'Policy Corpus',
            'ACTIVE CORPUS',
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 8),
          healthRow(
            'Corpus Scope',
            'Legislation, Standards & Mappings',
            const Color(0xFF6D28D9),
          ),
        ],
      ),
    )
  }

  Widget healthRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
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

  Widget stepHeader(String number, String title) {
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
        ('selected_file');
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
              child: Image.memory(fileBytes,
                  width: double.infinity, height: 180, fit: BoxFit.contain),
            )
          else if (isImageType && file != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.file(file,
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
