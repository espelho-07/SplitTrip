import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_amount_display.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/trip.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';

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

    String? insightText;
    IconData? insightIcon;
    Color? insightColor;

    if (net > 0) {
      insightText = l10n.tripsHomeGetBackOverall(CurrencyFormatter.formatPaise(net, currencyCode: 'INR'));
      insightIcon = Icons.arrow_downward_rounded;
      insightColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
    } else if (net < 0) {
      insightText = l10n.tripsHomeOweOverall(CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR'));
      insightIcon = Icons.arrow_upward_rounded;
      insightColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
    } else if (homeVm.trips.isNotEmpty) {
      insightText = l10n.tripsHomeAllSettled;
      insightIcon = Icons.check_circle_outline_rounded;
      insightColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
        }
      },
      child: homeVm.isLoading && homeVm.trips.isEmpty
          ? _buildLoadingSkeleton()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              children: [
                // 1. Hero Trips Spending Display
                KithAmountDisplay(
                  amountInPaise: totalSpentPaise,
                  periodSubtitle: l10n.tripsHomeActiveCount(homeVm.trips.length),
                  contextualInsight: insightText,
                  insightIcon: insightIcon,
                  insightColor: insightColor,
                ),

                const SizedBox(height: AppSpacing.xl),

                // 2. Section Header & Quick Join Action
                KithSectionHeader(
                  title: l10n.tripsMyTrips,
                  actionLabel: l10n.tripsJoin,
                  onAction: () {
                    HapticHelper.light();
                    context.push('/join-trip');
                  },
                ),

                const SizedBox(height: AppSpacing.sm),

                // 3. Trips List or Clean Empty State
                if (homeVm.trips.isEmpty)
                  KithEmptyState(
                    title: l10n.tripsNoTrips,
                    subtitle: l10n.tripsNoTripsSub,
                    icon: Icons.flight_takeoff_rounded,
                    actionLabel: l10n.tripsCreate,
                    onAction: () => context.push('/create-trip'),
                  )
                else
                  ...homeVm.trips.map((trip) {
                    final balance = homeVm.tripBalances[trip.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildTripCard(context, trip, balance, isDark, user?.id ?? '', l10n),
                    );
                  }),

                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip, dynamic balance, bool isDark, String currentUserId, AppLocalizations l10n) {
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

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const ShimmerSkeleton(height: 120),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerSkeleton(height: 100),
          const SizedBox(height: AppSpacing.md),
          const ShimmerSkeleton(height: 100),
        ],
      ),
    );
  }
}
