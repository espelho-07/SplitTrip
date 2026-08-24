import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Small chip or badge tag for status, categories, or participant counts.
class PillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const PillBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = color ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary);
    final bg = backgroundColor ?? primaryColor.withValues(alpha: isDark ? 0.16 : 0.10);

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: primaryColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.badgeText(color: primaryColor),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: pill,
      );
    }

    return pill;
  }
}
