import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../domain/models/balance_summary.dart';
import '../../../../domain/models/trip.dart';

/// Featured Hero Card for Active / Ongoing Trips.
/// Prioritized visually at the top of the Trips page.
class ActiveTripHeroCard extends StatelessWidget {
  final Trip trip;
  final BalanceSummary? balance;
  final int totalExpensesCount;
  final int totalExpensesPaise;
  final bool hasPendingSync;

  const ActiveTripHeroCard({
    super.key,
    required this.trip,
    this.balance,
    this.totalExpensesCount = 0,
    this.totalExpensesPaise = 0,
    this.hasPendingSync = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final gradientColors = AppColors.getGradient(trip.coverGradientIndex);
    final userNetPaise = balance?.currentUserNetBalanceInPaise ?? 0;

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        context.push('/trip/${trip.id}');
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cover Gradient Header Banner
            Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji container + Live status badge
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          trip.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.tripCardOngoing.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasPendingSync) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.tripCardSyncing,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // Started Date Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      DateFormatter.formatTripActiveDate(trip.startedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Card Content Body
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Name & Destination
                  Text(
                    trip.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (trip.description != null && trip.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      trip.description!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Members Avatars & Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatars Stack + Count
                      Row(
                        children: [
                          SizedBox(
                            height: 28,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < trip.members.take(3).length; i++)
                                  Align(
                                    widthFactor: 0.7,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF0F1418) : Colors.white,
                                          width: 1.8,
                                        ),
                                      ),
                                      child: MemberAvatar(
                                        name: trip.members[i].displayName,
                                        avatarUrl: trip.members[i].avatarUrl,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trip.members.length == 1
                                ? l10n.tripCardPersonSingle
                                : l10n.tripCardPersonPlural(trip.members.length),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),

                      // Expenses count & Total
                      Text(
                        totalExpensesCount > 0
                            ? '$totalExpensesCount exp · ${CurrencyFormatter.formatPaise(totalExpensesPaise, currencyCode: trip.currencyCode)}'
                            : l10n.tripCardNoExpenses,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Action Row: [ Net Balance Status ]   [ Open Trip → ]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Balance Pill
                      if (userNetPaise > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 15,
                              color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tripCardGetBack(CurrencyFormatter.formatPaise(userNetPaise, currencyCode: trip.currencyCode)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                              ),
                            ),
                          ],
                        )
                      else if (userNetPaise < 0)
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 15,
                              color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tripCardYouOwe(CurrencyFormatter.formatPaise(userNetPaise.abs(), currencyCode: trip.currencyCode)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tripCardAllSettled,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                      // Primary Button: Open Trip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.tripCardOpenTrip,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
