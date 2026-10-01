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
      'title': 'PII Detection',
      'subtitle': 'Regex + NER',
      'detail': 'Indian PII patterns + contextual entities',
      'icon': 'detection',
    },
    {
      'step': 'STEP 3',
      'title': 'Hybrid Fusion',
      'subtitle': 'Deduplication + confidence scoring',
      'icon': 'fusion',
    },
    {
      'step': 'STEP 4',
      'title': 'Policy Decision',
      'subtitle': 'Regulatory retrieval + decision',
      'icon': 'policy',
    },
    {
      'step': 'STEP 5',
      'title': 'Secure Redaction',
      'subtitle': 'Image + text masking',
      'icon': 'lock',
    },
  ];

  IconData _iconFor(String type) {
    switch (type) {
      case 'text':
        return Icons.document_scanner_outlined;
      case 'detection':
        return Icons.manage_search_rounded;
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
              final isCompact = constraints.maxWidth < 760;
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
                  final columns = constraints.maxWidth > 900
                      ? 5
                      : constraints.maxWidth > 600
                          ? 3
                          : 1;
                  final itemWidth = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - ((columns - 1) * 8)) / columns;

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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.slate500,
                                ),
                              ),
                              if (step['detail'] != null)
                                Text(
                                  step['detail']!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
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
