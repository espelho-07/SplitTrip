import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'kith_inline_progress.dart';

/// Contextual action progress banner/bar for in-flight requests.
class KithActionProgress extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isIndeterminate;

  const KithActionProgress({
    super.key,
    required this.title,
    this.subtitle,
    this.isIndeterminate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const KithInlineProgress(size: 18, strokeWidth: 2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
