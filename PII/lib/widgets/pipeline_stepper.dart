import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PipelineStepper extends StatelessWidget {
  const PipelineStepper({super.key});

  static const List<Map<String, String>> _steps = [
    {
      'step': 'STEP 1',
      'title': 'OCR Extraction',
      'subtitle': 'Tesseract + Preprocessing',
      'icon': 'text',
    },
    {
      'step': 'STEP 2',
      'title': 'Regex Detection',
      'subtitle': 'Aadhaar, PAN, DL, Phone',
      'icon': 'pattern',
    },
    {
      'step': 'STEP 3',
      'title': 'NER Recognition',
      'subtitle': 'Names, Locations, Context',
      'icon': 'ai',
    },
    {
      'step': 'STEP 4',
      'title': 'Hybrid Fusion',
      'subtitle': 'Dedup & Confidence Scoring',
      'icon': 'fusion',
    },
    {
      'step': 'STEP 5',
      'title': 'Policy Engine',
      'subtitle': 'DPDP & UIDAI Compliance',
      'icon': 'policy',
    },
    {
      'step': 'STEP 6',
      'title': 'Secure Redactor',
      'subtitle': 'Dual Image & Text Masking',
      'icon': 'lock',
    },
  ];

  IconData _iconFor(String type) {
    switch (type) {
      case 'text':
        return Icons.document_scanner_outlined;
      case 'pattern':
        return Icons.code_rounded;
      case 'ai':
        return Icons.psychology_outlined;
      case 'fusion':
        return Icons.hub_outlined;
      case 'policy':
        return Icons.gavel_outlined;
      case 'lock':
      default:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 480;
              if (isCompact) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_tree_outlined,
                            size: 16, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI Redaction Pipeline Architecture',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.only(left: 24),
                      child: Text(
                        'End-to-End Privacy Workflow',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate400,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const Row(
                children: [
                  Icon(Icons.account_tree_outlined,
                      size: 16, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'AI Redaction Pipeline Architecture',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'End-to-End Privacy Workflow',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate400,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_steps.length, (index) {
                  final step = _steps[index];
                  // On wide screen, width is fraction; on narrow, it wraps
                  final double itemWidth = constraints.maxWidth > 900
                      ? (constraints.maxWidth - (5 * 8)) / 6
                      : constraints.maxWidth > 600
                          ? (constraints.maxWidth - (2 * 8)) / 3
                          : constraints.maxWidth;

                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _iconFor(step['icon']!),
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                step['step']!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                step['title']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.slate800,
                                ),
                              ),
                              Text(
                                step['subtitle']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
