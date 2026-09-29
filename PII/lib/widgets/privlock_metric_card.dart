import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivLockMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color accentColor;
  final String? subtitle;

  const PrivLockMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor = AppTheme.primaryColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                  letterSpacing: 0.4,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: accentColor.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
