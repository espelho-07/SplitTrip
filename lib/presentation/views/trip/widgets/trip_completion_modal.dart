import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/models/balance_summary.dart';
import '../../../../domain/models/trip.dart';

class TripCompletionModal extends StatelessWidget {
  final Trip trip;
  final BalanceSummary balanceSummary;
  final int expenseCount;
  final VoidCallback? onViewSettlements;

  const TripCompletionModal({
    super.key,
    required this.trip,
    required this.balanceSummary,
    required this.expenseCount,
    this.onViewSettlements,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required BalanceSummary balanceSummary,
    required int expenseCount,
    VoidCallback? onViewSettlements,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripCompletionModal(
        trip: trip,
        balanceSummary: balanceSummary,
        expenseCount: expenseCount,
        onViewSettlements: onViewSettlements,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSpentFormatted = CurrencyFormatter.formatPaise(
      balanceSummary.totalTripSpentInPaise,
      currencyCode: trip.currencyCode,
    );
    final settlements = balanceSummary.simplifiedSettlements;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.emeraldPrimary, AppColors.emeraldLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.celebration_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Trip Completed!',
            style: AppTypography.titleLarge(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Congratulations on wrapping up "${trip.name}"! Here is your final trip summary.',
            style: AppTypography.bodyMedium(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    borderRadius: AppRadius.lgBorder,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SPENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalSpentFormatted,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    borderRadius: AppRadius.lgBorder,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$expenseCount items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: AppRadius.lgBorder,
            ),
            child: Row(
              children: [
                Icon(
                  settlements.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  color: settlements.isEmpty
                      ? AppColors.positiveGreenLight
                      : Colors.amberAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settlements.isEmpty
                            ? 'All Balances Settled'
                            : '${settlements.length} Settlements Pending',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settlements.isEmpty
                            ? 'No outstanding payments between members.'
                            : 'Tap below to review and mark transfers as paid.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              if (settlements.isNotEmpty) ...[
                Expanded(
                  child: AppButton(
                    text: 'View Settlements',
                    icon: Icons.account_balance_wallet_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      onViewSettlements?.call();
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton(
                  text: 'Done',
                  variant: settlements.isNotEmpty
                      ? AppButtonVariant.outline
                      : AppButtonVariant.primary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
