import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/trip.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';

/// Master Group Trips Home Tab.
/// Features a prominent financial hero overview card, quick "+ Join Trip" action,
/// polished empty state matching user design specification, and rich trip journey cards.
class TripsHomeTab extends StatelessWidget {
  const TripsHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeVm = context.watch<HomeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;
    final user = authVm.currentUser;

    final totalSpentPaise = homeVm.totalSpentOnTripsInPaise;
    final net = homeVm.overallNetBalanceInPaise;

    String insightText = l10n.tripsHomeAllSettledMsg;
    IconData insightIcon = Icons.check_circle_outline_rounded;
    Color? insightColor;

    if (net > 0) {
      insightText = l10n.tripsHomeGetBackOverall(CurrencyFormatter.formatPaise(net, currencyCode: 'INR'));
      insightIcon = Icons.arrow_downward_rounded;
      insightColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
    } else if (net < 0) {
      insightText = l10n.tripsHomeOweOverall(CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR'));
      insightIcon = Icons.arrow_upward_rounded;
      insightColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
    } else {
      insightText = l10n.tripsHomeAllSettledMsg;
      insightIcon = Icons.check_circle_outline_rounded;
      insightColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
        }
      },
      child: homeVm.isLoading && homeVm.trips.isEmpty
          ? _buildLoadingSkeleton(isDark)
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              children: [
                // 1. Hero Financial Overview Card
                _buildHeroFinancialCard(
                  totalSpentPaise: totalSpentPaise,
                  tripsCount: homeVm.trips.length,
                  insightText: insightText,
                  insightIcon: insightIcon,
                  insightColor: insightColor,
                  isDark: isDark,
                  l10n: l10n,
                ),

                const SizedBox(height: 28),

                // 2. Section Header: [ Your Group Trips ]     [ + Join Trip ]
                _buildSectionHeader(context, isDark, l10n),

                const SizedBox(height: 16),

                // 3. Trips List or Specification Empty State
                if (homeVm.trips.isEmpty)
                  _buildEmptyState(context, isDark, l10n)
                else
                  ...homeVm.trips.map((trip) {
                    final balance = homeVm.tripBalances[trip.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildTripCard(context, trip, balance, isDark, user?.id ?? '', l10n),
                    );
                  }),

                const SizedBox(height: 90),
              ],
            ),
    );
  }

  /// 1. Hero Financial Overview Card matching the screenshot specification
  Widget _buildHeroFinancialCard({
    required int totalSpentPaise,
    required int tripsCount,
    required String insightText,
    required IconData insightIcon,
    Color? insightColor,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: [ TOTAL SPENT ON TRIPS ]   [ 0 Trips ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.tripsHomeTotalSpent,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$tripsCount ${tripsCount == 1 ? 'Trip' : 'Trips'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Hero Number: ₹0 or ₹12,450
          Text(
            CurrencyFormatter.formatPaise(totalSpentPaise, currencyCode: 'INR'),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 14),

          // Status Row: (icon) + All trip balances settled up / You get back ₹X / You owe ₹Y
          Row(
            children: [
              Icon(
                insightIcon,
                size: 17,
                color: insightColor ?? (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insightText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: insightColor ?? (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Section Header: [ Your Group Trips ]     [ + Join Trip ]
  Widget _buildSectionHeader(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.tripsHomeGroupTrips,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticHelper.light();
            context.push('/join-trip');
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 17,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.tripsJoin,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 3. Specification Empty State matching the exact screenshot design
  Widget _buildEmptyState(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular badge with map illustration
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '🗺️',
              style: TextStyle(fontSize: 38),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.tripsNoTrips,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              l10n.tripsHomeNoTripsDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              context.push('/create-trip');
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : AppColors.emeraldPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    l10n.tripsHomeNewTripBtn,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Populated Trip Card
  Widget _buildTripCard(
    BuildContext context,
    Trip trip,
    dynamic balance,
    bool isDark,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    final gradientColors = AppColors.getGradient(trip.coverGradientIndex);
    final userNetPaise = balance?.currentUserNetBalanceInPaise ?? 0;

    return SurfaceCard(
      onTap: () {
        HapticHelper.light();
        context.push('/trip/${trip.id}');
      },
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip Cover Gradient Banner
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        trip.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          l10n.tripsHomeMembersCount(trip.members.length),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                PillBadge(
                  label: trip.lifecycleState.displayName,
                  color: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),

          // Card Body Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Member Avatars Row
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      for (int i = 0; i < trip.members.length && i < 4; i++)
                        Align(
                          widthFactor: 0.7,
                          child: MemberAvatar(
                            name: trip.members[i].displayName,
                            size: 28,
                            showBorder: true,
                          ),
                        ),
                      if (trip.members.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '+${trip.members.length - 4}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // User Balance in Trip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      userNetPaise > 0
                          ? l10n.tripDetailYouGetBack
                          : (userNetPaise < 0 ? l10n.tripDetailYouOwe : l10n.tripsHomeCardSettled),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(userNetPaise.abs(), currencyCode: trip.currencyCode),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: userNetPaise > 0
                            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                            : (userNetPaise < 0
                                ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
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

  Widget _buildLoadingSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          ShimmerSkeleton(height: 140, borderRadius: BorderRadius.circular(24)),
          const SizedBox(height: 24),
          const ShimmerSkeleton(height: 24, width: 140),
          const SizedBox(height: 16),
          ShimmerSkeleton(height: 160, borderRadius: BorderRadius.circular(20)),
        ],
      ),
    );
  }
}
