import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

/// Premium typography-first financial hero display.
/// Presents large tabular money figures with period metadata and optional progress.
class KithAmountDisplay extends StatelessWidget {
  final int amountInPaise;
  final String currencyCode;
  final String? periodSubtitle;
  final String? contextualInsight;
  final IconData? insightIcon;
  final Color? insightColor;
  final double? budgetProgress; // 0.0 to 1.0+
  final VoidCallback? onInsightTap;
  final VoidCallback? onPeriodTap;

  const KithAmountDisplay({
    super.key,
    required this.amountInPaise,
    this.currencyCode = 'INR',
    this.periodSubtitle,
    this.contextualInsight,
    this.insightIcon,
    this.insightColor,
    this.budgetProgress,
    this.onInsightTap,
    this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = CurrencyFormatter.formatPaise(amountInPaise, currencyCode: currencyCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Period subtitle with optional dropdown/navigation
        if (periodSubtitle != null)
          GestureDetector(
            onTap: onPeriodTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodSubtitle!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                if (onPeriodTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.xs),

        // 2. Hero Financial Amount (The Hero Number)
        Text(
          formattedAmount,
          style: AppTypography.moneyHero(isDark: isDark).copyWith(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),

        // 3. Optional Budget Progress Bar (clean & subtle)
        if (budgetProgress != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.fullBorder,
            child: LinearProgressIndicator(
              value: budgetProgress!.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(
                budgetProgress! > 0.9 ? AppColors.negativeRedDark : AppColors.emeraldPrimary,
              ),
            ),
          ),
        ],

        // 4. One Single Contextual Insight Line
        if (contextualInsight != null && contextualInsight!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: onInsightTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (insightColor ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)).withValues(alpha: 0.1),
                borderRadius: AppRadius.mdBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (insightIcon != null) ...[
                    Icon(
                      insightIcon,
                      size: 14,
                      color: insightColor ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      contextualInsight!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: insightColor ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onInsightTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: insightColor ?? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
