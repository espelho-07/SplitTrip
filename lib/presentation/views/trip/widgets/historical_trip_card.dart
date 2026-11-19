import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../domain/enums/trip_lifecycle.dart';
import '../../../../domain/models/trip.dart';

/// Clean, minimal card for historical / completed trips in the "ALL TRIPS" section.
/// Elevated with Airbnb-inspired micro-interactions, tactile scaling, and clear typography.
class HistoricalTripCard extends StatelessWidget {
  final Trip trip;
  final int totalExpensesPaise;
  final int totalExpensesCount;

  const HistoricalTripCard({
    super.key,
    required this.trip,
    this.totalExpensesPaise = 0,
    this.totalExpensesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final dateRangeText = DateFormatter.formatTripHistoricalRange(
      trip.startedAt,
      trip.completedAt,
    );

    return KithCard(
      onTap: () {
        context.push('/trip/${trip.id}');
      },
      padding: const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          // Emoji circle with ambient border
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              trip.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Main Info: Name, Date Range, Status + Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        trip.lifecycleState == TripLifecycle.completedWithPendingChanges
                            ? l10n.tripCardPendingSyncBadge
                            : l10n.tripCardCompletedBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Date range
                Text(
                  dateRangeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 8),

                // Members and Spending Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        trip.members.length == 1
                            ? l10n.tripCardMemberSingle
                            : l10n.tripCardMemberPlural(trip.members.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.formatPaise(totalExpensesPaise, currencyCode: trip.currencyCode),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
