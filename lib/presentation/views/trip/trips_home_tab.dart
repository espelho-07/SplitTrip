import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/trip.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/tooltips/contextual_hint_card.dart';

class TripsHomeTab extends StatelessWidget {
  const TripsHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeVm = context.watch<HomeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;
    final user = authVm.currentUser;

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
        }
      },
      child: homeVm.isLoading && homeVm.trips.isEmpty
          ? _buildLoadingSkeleton()
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First-use Contextual Hint
                  ContextualHintCard(
                    hintKey: 'trips_home',
                    title: l10n.hintTripsTitle,
                    description: l10n.hintTripsDesc,
                    icon: Icons.flight_takeoff_rounded,
                    iconColor: AppColors.tealAccent,
                  ),

                  // Balance Overview Card
                  _buildBalanceCard(homeVm, isDark),

                  const SizedBox(height: AppSpacing.xxl),

                  // Active Trips Header & Quick Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tripsMyTrips,
                        style: AppTypography.titleMedium(isDark: isDark),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/join-trip'),
                        icon: const Icon(Icons.group_add_outlined, size: 16),
                        label: Text(l10n.tripsJoin, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  if (homeVm.trips.isEmpty)
                    EmptyStateView(
                      emoji: '🗺️',
                      title: 'No trips yet',
                      subtitle: 'Create a trip when you\'re ready to split group expenses with friends.',
                      buttonText: 'New Trip',
                      buttonIcon: Icons.add_rounded,
                      onButtonPressed: () => context.push('/create-trip'),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: homeVm.trips.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final trip = homeVm.trips[index];
                        final balance = homeVm.tripBalances[trip.id];
                        return _buildTripCard(context, trip, balance, isDark, user?.id ?? '');
                      },
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(HomeViewModel homeVm, bool isDark) {
    final totalSpentPaise = homeVm.totalSpentOnTripsInPaise;
    final net = homeVm.overallNetBalanceInPaise;
    final isOwed = net > 0;
    final isDebt = net < 0;

    String subtitleText;
    Color statusColor;
    IconData statusIcon;

    if (isOwed) {
      subtitleText = 'You are owed ${CurrencyFormatter.formatPaise(net, currencyCode: 'INR')} overall';
      statusColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      statusIcon = Icons.arrow_downward_rounded;
    } else if (isDebt) {
      subtitleText = 'You owe ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')} overall';
      statusColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      statusIcon = Icons.arrow_upward_rounded;
    } else {
      subtitleText = 'All trip balances settled up';
      statusColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        ),
        boxShadow: isDark ? AppElevation.darkCard : AppElevation.lightCard,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL SPENT ON TRIPS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              PillBadge(
                label: '${homeVm.trips.length} ${homeVm.trips.length == 1 ? 'Trip' : 'Trips'}',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CurrencyDisplay(
            amountInPaise: totalSpentPaise,
            size: CurrencyDisplaySize.hero,
            colorMode: CurrencyColorMode.neutral,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 14, color: statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip, dynamic balance, bool isDark, String currentUserId) {
    final gradientColors = AppColors.getGradient(trip.coverGradientIndex);
    final userNetPaise = balance?.currentUserNetBalanceInPaise ?? 0;

    return SurfaceCard(
      onTap: () => context.push('/trip/${trip.id}'),
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
                          '${trip.members.length} members',
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
                          ? 'You receive'
                          : (userNetPaise < 0 ? 'You owe' : 'Settled'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    CurrencyDisplay(
                      amountInPaise: userNetPaise.abs(),
                      size: CurrencyDisplaySize.medium,
                      colorMode: userNetPaise > 0
                          ? CurrencyColorMode.positive
                          : (userNetPaise < 0 ? CurrencyColorMode.negative : CurrencyColorMode.neutral),
                      currencyCode: trip.currencyCode,
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const ShimmerSkeleton(height: 140),
          const SizedBox(height: 24),
          const ShimmerSkeleton(height: 120),
          const SizedBox(height: 16),
          const ShimmerSkeleton(height: 120),
        ],
      ),
    );
  }
}
