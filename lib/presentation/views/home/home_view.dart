import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/trip.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user != null) {
      context.read<HomeViewModel>().loadTrips(user.id);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showProfileSheet() {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: AppSpacing.bottomSheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemberAvatar(name: user.displayName, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTypography.titleMedium(isDark: isDark),
                        ),
                        Text(
                          user.isLinkedToAccount
                              ? (user.email ?? 'Linked Account')
                              : 'Anonymous Guest Account',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Recovery Key',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Keep this key safe. Use it to recover your trips if you switch devices or reinstall.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.recoveryKey,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.recoveryKey));
                        HapticHelper.success();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recovery key copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: 'Done',
                isFullWidth: true,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final homeVm = context.watch<HomeViewModel>();
    final themeVm = context.watch<ThemeViewModel>();

    final user = authVm.currentUser;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            GestureDetector(
              onTap: _showProfileSheet,
              child: MemberAvatar(
                name: user?.displayName ?? 'Traveler',
                size: 34,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  user?.displayName ?? 'Traveler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
            onPressed: () {
              HapticHelper.light();
              themeVm.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            onPressed: () => context.push('/join-trip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) {
            await homeVm.refresh(user.id);
          }
        },
        child: homeVm.isLoading
            ? _buildLoadingSkeleton()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Overview Card
                    _buildBalanceCard(homeVm, isDark),

                    const SizedBox(height: AppSpacing.xxl),

                    // Active Trips Header & Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Trips',
                          style: AppTypography.titleMedium(isDark: isDark),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push('/join-trip'),
                          icon: const Icon(Icons.group_add_outlined, size: 16),
                          label: const Text('Join Trip', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    if (homeVm.trips.isEmpty)
                      EmptyStateView(
                        emoji: '🗺️',
                        title: 'No active trips yet',
                        subtitle: 'Create a trip for your upcoming vacation or dinner with friends to start tracking expenses effortlessly.',
                        buttonText: 'Create First Trip',
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
                          return _buildTripCard(trip, balance, isDark, user?.id ?? '');
                        },
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticHelper.light();
          context.push('/create-trip');
        },
        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'New Trip',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(HomeViewModel homeVm, bool isDark) {
    final net = homeVm.overallNetBalanceInPaise;
    final isOwed = net > 0;
    final isDebt = net < 0;

    String subtitleText;
    Color statusColor;
    IconData statusIcon;

    if (isOwed) {
      subtitleText = 'You are owed overall';
      statusColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      statusIcon = Icons.arrow_downward_rounded;
    } else if (isDebt) {
      subtitleText = 'You owe overall';
      statusColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      statusIcon = Icons.arrow_upward_rounded;
    } else {
      subtitleText = 'All settled up';
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              PillBadge(
                label: '${homeVm.trips.length} ${homeVm.trips.length == 1 ? 'Trip' : 'Trips'}',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CurrencyDisplay(
            amountInPaise: net,
            size: CurrencyDisplaySize.hero,
            colorMode: CurrencyColorMode.auto,
            showPlusSign: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Live aggregate balance across all your trips and activities',
            style: AppTypography.bodySmall(isDark: isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip, dynamic balance, bool isDark, String currentUserId) {
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
