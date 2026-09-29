import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeVariant {
  primary,
  success,
  warning,
  danger,
  purple,
  slate,
}

class PrivLockBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final BadgeVariant variant;
  final bool isPill;
  final double fontSize;

  const PrivLockBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = BadgeVariant.primary,
    this.isPill = false,
    this.fontSize = 11,
  });

  factory PrivLockBadge.decision(String decision) {
    switch (decision.toLowerCase()) {
      case 'redact':
        return const PrivLockBadge(
          label: 'REDACT',
          icon: Icons.block,
          variant: BadgeVariant.danger,
        );
      case 'mask':
        return const PrivLockBadge(
          label: 'MASK',
          icon: Icons.visibility_off_outlined,
          variant: BadgeVariant.warning,
        );
      case 'keep':
      default:
        return const PrivLockBadge(
          label: 'KEEP',
          icon: Icons.check_circle_outline,
          variant: BadgeVariant.success,
        );
    }
  }

  factory PrivLockBadge.source(String source) {
    switch (source.toLowerCase()) {
      case 'regex':
        return const PrivLockBadge(
          label: 'REGEX',
          variant: BadgeVariant.success,
        );
      case 'ner':
        return const PrivLockBadge(
          label: 'NER',
          variant: BadgeVariant.purple,
        );
      case 'hybrid':
      default:
        return const PrivLockBadge(
          label: 'HYBRID',
          variant: BadgeVariant.primary,
        );
    }
  }

  factory PrivLockBadge.severity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const PrivLockBadge(
          label: 'CRITICAL',
          variant: BadgeVariant.danger,
        );
      case 'high':
        return const PrivLockBadge(
          label: 'HIGH',
          variant: BadgeVariant.warning,
        );
      case 'medium':
        return const PrivLockBadge(
          label: 'MEDIUM',
          variant: BadgeVariant.warning,
        );
      case 'low':
      default:
        return const PrivLockBadge(
          label: 'LOW',
          variant: BadgeVariant.slate,
        );
    }
  }

  factory PrivLockBadge.status(String status) {
    final s = status.toLowerCase();
    if (s == 'active' || s == 'online' || s == 'processed' || s == 'success') {
      return PrivLockBadge(
        label: status.toUpperCase(),
        icon: Icons.circle,
        variant: BadgeVariant.success,
        isPill: true,
      );
    } else if (s == 'running' || s == 'processing') {
      return PrivLockBadge(
        label: status.toUpperCase(),
        icon: Icons.sync,
        variant: BadgeVariant.primary,
        isPill: true,
      );
    } else {
      return PrivLockBadge(
        label: status.toUpperCase(),
        icon: Icons.error_outline,
        variant: BadgeVariant.danger,
        isPill: true,
      );
    }
  }

  Color _bgColor() => switch (variant) {
        BadgeVariant.success => AppTheme.successLight,
        BadgeVariant.warning => AppTheme.warningLight,
        BadgeVariant.danger => AppTheme.dangerLight,
        BadgeVariant.purple => AppTheme.purpleLight,
        BadgeVariant.slate => AppTheme.slate100,
        BadgeVariant.primary => AppTheme.primaryLight,
      };

  Color _textColor() => switch (variant) {
        BadgeVariant.success => const Color(0xFF047857), // Emerald 700
        BadgeVariant.warning => const Color(0xFFB45309), // Amber 700
        BadgeVariant.danger => const Color(0xFFB91C1C), // Red 700
        BadgeVariant.purple => const Color(0xFF6D28D9), // Purple 700
        BadgeVariant.slate => AppTheme.slate700,
        BadgeVariant.primary => const Color(0xFF1D4ED8), // Blue 700
      };

  Color _borderColor() => switch (variant) {
        BadgeVariant.success => const Color(0xFFA7F3D0),
        BadgeVariant.warning => const Color(0xFFFDE68A),
        BadgeVariant.danger => const Color(0xFFFECACA),
        BadgeVariant.purple => const Color(0xFFDDD6FE),
        BadgeVariant.slate => AppTheme.slate200,
        BadgeVariant.primary => const Color(0xFFBFDBFE),
      };

  @override
  Widget build(BuildContext context) {
    final fg = _textColor();
    final bg = _bgColor();
    final border = _borderColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPill ? 8 : 7,
        vertical: isPill ? 3 : 2.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isPill ? 999 : 6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: fontSize + 1,
              color: fg,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
