import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/user_avatar_button.dart';
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
  String _selectedDocType = 'general';
  String _selectedAction = 'redact';
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _systemHealth;
  String? _systemHealthError;
  bool _loadingSystemHealth = true;

  @override
  void initState() {
    super.initState();
    _loadSystemHealth();
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
    {'value': 'aadhaar', 'label': 'Aadhaar Card', 'icon': Icons.credit_card},
    {
      'value': 'pan',
      'label': 'PAN Card',
      'icon': Icons.account_balance_wallet_outlined
    },
    {
      'value': 'driving_license',
      'label': 'Driving License',
      'icon': Icons.directions_car_outlined
    },
    {
      'value': 'voter_id',
      'label': 'Voter ID',
      'icon': Icons.how_to_vote_outlined
    },
    {
      'value': 'passport',
      'label': 'Passport',
      'icon': Icons.airplanemode_active_outlined
    },
    {
      'value': 'bank_statement',
      'label': 'Bank Statement',
      'icon': Icons.account_balance_outlined
    },
    {'value': 'invoice', 'label': 'Invoice', 'icon': Icons.receipt_outlined},
    {
      'value': 'contract',
      'label': 'Contract',
      'icon': Icons.description_outlined
    },
    {
      'value': 'general',
      'label': 'General Document',
      'icon': Icons.document_scanner_outlined
    },
  ];

  final List<Map<String, dynamic>> _actions = [
    {
      'value': 'redact',
      'label': 'Redact',
      'icon': Icons.remove_red_eye_outlined,
      'description': 'Permanently remove sensitive data'
    },
    {
      'value': 'mask',
      'label': 'Mask',
      'icon': Icons.visibility_off_outlined,
      'description': 'Hide sensitive data with placeholders'
    },
    {
      'value': 'blur',
      'label': 'Blur',
      'icon': Icons.blur_on_outlined,
      'description': 'Blur sensitive data in the document image'
    },
  ];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select document source',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF1A73E8)),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF34A853)),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_present_outlined,
                      color: Color(0xFF9C27B0)),
                ),
                title: const Text('Select file'),
                subtitle: const Text('PDF, DOCX, TXT files'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
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
          backgroundColor: const Color(0xFFEA4335),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('PII Redaction'),
        actions: const [
          UserAvatarButton(),
        ],
      ),
      drawer: AppDrawer(
        currentRoute: 'dashboard',
        onMenuItemSelected: (menuItem) {
          // Handle menu item selection if needed
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hello, ${auth.username} 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upload a document to detect and redact PII',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 24),

            _SystemHealthCard(
              isLoading: _loadingSystemHealth,
              errorText: _systemHealthError,
              health: _systemHealth,
            ),

            const SizedBox(height: 20),

            // ── STEP 1: Document Type ─────────────────────────────────────
            _sectionLabel('Step 1 — Select document type'),
            const SizedBox(height: 12),
            ...(_docTypes.map((dt) => _DocTypeRadioTile(
                  value: dt['value'] as String,
                  label: dt['label'] as String,
                  icon: dt['icon'] as IconData,
                  groupValue: _selectedDocType,
                  onChanged: (v) => setState(() => _selectedDocType = v!),
                ))),

            const SizedBox(height: 24),

            // ── STEP 2: Action Type ───────────────────────────────────────
            _sectionLabel('Step 2 — Choose redaction action'),
            const SizedBox(height: 12),
            ...(_actions.map((action) => _ActionRadioTile(
                  value: action['value'] as String,
                  label: action['label'] as String,
                  description: action['description'] as String,
                  icon: action['icon'] as IconData,
                  groupValue: _selectedAction,
                  onChanged: (v) => setState(() => _selectedAction = v!),
                ))),

            const SizedBox(height: 24),

            // ── STEP 3: Upload Document ───────────────────────────────────
            _sectionLabel('Step 3 — Upload document'),
            const SizedBox(height: 12),

            (_selectedFile != null || _selectedFileBytes != null)
                ? _FilePreviewCard(
                    file: _selectedFile,
                    fileBytes: _selectedFileBytes,
                    fileName: _selectedFileName,
                    onReplace: _showFileSourceSheet,
                  )
                : _UploadPlaceholder(onTap: _showFileSourceSheet),

            const SizedBox(height: 24),

            // ── STEP 4: Process ───────────────────────────────────────────
            _sectionLabel('Step 4 — Process document'),
            const SizedBox(height: 12),

            Consumer<DocumentProvider>(
              builder: (_, docProvider, __) => ElevatedButton.icon(
                onPressed: (docProvider.isProcessing ||
                        (_selectedFile == null && _selectedFileBytes == null))
                    ? null
                    : _processDocument,
                icon: docProvider.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(docProvider.isProcessing
                    ? 'Processing document...'
                    : 'Process Document'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),

            if (context.watch<DocumentProvider>().isProcessing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.memory, color: Color(0xFF1A73E8), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Analyzing document → Detecting PII → Applying redaction...',
                        style: TextStyle(
                            color: Color(0xFF1A73E8),
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Info cards
            _InfoRow(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.3,
        ),
      );
}

class _SystemHealthCard extends StatelessWidget {
  final bool isLoading;
  final String? errorText;
  final Map<String, dynamic>? health;

  const _SystemHealthCard({
    required this.isLoading,
    required this.errorText,
    required this.health,
  });

  Color _statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'running':
      case 'connected':
      case 'ok':
      case 'loaded':
      case 'available':
      case 'true':
        return const Color(0xFF34A853);
      case 'false':
        return const Color(0xFFEA4335);
      default:
        return const Color(0xFFEA4335);
    }
  }

  Widget _pill(String label, String value) {
    final color = _statusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking backend, AI engine, and database status...'),
          ],
        ),
      );
    }

    if (errorText != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          'System check failed: $errorText',
          style: const TextStyle(
            color: Color(0xFFB91C1C),
            fontSize: 13,
          ),
        ),
      );
    }

    final healthData = health;
    final backend = (healthData?['backend'] ?? 'unknown').toString();
    final database = (healthData?['database'] ?? 'unknown').toString();
    final dynamic aiRaw = healthData?['ai'];
    final ai = aiRaw is Map<String, dynamic>
      ? aiRaw
      : <String, dynamic>{};
    final aiLoaded = (ai['loaded'] == true) ? 'loaded' : 'false';
    String ragEnabled = 'false';
    final rag = ai['rag'];
    if (rag is Map<String, dynamic>) {
      ragEnabled = (rag['rag_enabled'] == true) ? 'enabled' : 'false';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live system status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Backend, AI pipeline, and database connection',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Backend', backend),
              _pill('Database', database),
              _pill('AI modules', aiLoaded),
              _pill('RAG', ragEnabled),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────

class _DocTypeRadioTile extends StatelessWidget {
  final String value, label, groupValue;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _DocTypeRadioTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE8EAED),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF9CA3AF),
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : const Color(0xFF1A1A2E),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  isSelected ? const Color(0xFF1A73E8) : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRadioTile extends StatelessWidget {
  final String value, label, description, groupValue;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _ActionRadioTile({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE8EAED),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF9CA3AF),
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF1A73E8)
                          : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  isSelected ? const Color(0xFF1A73E8) : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1A73E8),
            width: 1.5,
            // dashed via custom painter would require package; solid is fine
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                color: Color(0xFF1A73E8), size: 40),
            SizedBox(height: 10),
            Text('Tap to add document',
                style: TextStyle(
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            SizedBox(height: 4),
            Text('Camera, gallery, or file picker • PDF, DOCX, TXT, Images',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // File preview based on type
          if (isImageType && fileBytes != null)
            Image.memory(fileBytes!,
                width: double.infinity, height: 200, fit: BoxFit.cover)
          else if (isImageType && file != null)
            Image.file(file!,
                width: double.infinity, height: 200, fit: BoxFit.cover)
          else
            Container(
              width: double.infinity,
              height: 120,
              color: const Color(0xFFF9FAFB),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getFileIcon(fileExt),
                    size: 48,
                    color: _getFileColor(fileExt),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedFileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '.${fileExt.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

          // Replace button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onReplace,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Replace',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'docx':
      case 'doc':
        return const Color(0xFF2563EB);
      case 'txt':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _InfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
            child: _InfoCard(
                icon: Icons.verified_user_outlined,
                label: 'Regex + NER',
                sub: 'Hybrid detection',
                color: Color(0xFF1A73E8))),
        SizedBox(width: 10),
        Expanded(
            child: _InfoCard(
                icon: Icons.psychology_outlined,
                label: 'RAG Engine',
                sub: 'Policy-aware',
                color: Color(0xFF34A853))),
        SizedBox(width: 10),
        Expanded(
            child: _InfoCard(
                icon: Icons.blur_on,
                label: 'Auto Redact',
                sub: 'Image + text',
                color: Color(0xFFEA4335))),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  const _InfoCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}
