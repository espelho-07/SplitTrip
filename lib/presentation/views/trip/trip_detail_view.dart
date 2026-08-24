import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/trip_lifecycle.dart';
import '../../../domain/models/balance_summary.dart';
import '../../../domain/models/trip.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import 'widgets/settlement_sheet.dart';
import 'widgets/trip_qr_sheet.dart';

class TripDetailView extends StatefulWidget {
  final String tripId;

  const TripDetailView({super.key, required this.tripId});

  @override
  State<TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends State<TripDetailView> {
  int _activeTab = 0; // 0: Expenses, 1: Balances & People

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
      context.read<TripDetailViewModel>().loadTrip(widget.tripId, user.id);
    }
  }

  void _showAddFriendDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Friend to Trip'),
          content: TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: "Friend's name (e.g. Priya)",
              prefixIcon: Icon(Icons.person_add_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            AppButton(
              text: 'Add',
              height: 44,
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final authVm = context.read<AuthViewModel>();
                  context.read<TripDetailViewModel>().addMember(name, authVm.currentUser?.id ?? '');
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCompleteTripConfirmation() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();

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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.indigoAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_outlined, color: AppColors.indigoAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Complete Trip?',
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Completing the trip locks normal expense additions and generates the final simplified settlement for everyone.',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Keep Active',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Complete Trip',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await tripDetailVm.completeTrip(authVm.currentUser?.id ?? '');
                        if (mounted) {
                          _showSettlementSheet();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettlementSheet() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();
    final trip = tripDetailVm.trip;
    if (trip == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettlementSheet(
        trip: trip,
        balanceSummary: tripDetailVm.balanceSummary,
        currentUserId: authVm.currentUser?.id ?? '',
        onMarkSettled: () {
          tripDetailVm.markAsSettled(authVm.currentUser?.id ?? '');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Trip marked as fully settled!')),
          );
        },
      ),
    );
  }

  void _showInviteShareDialog(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripQrSheet(trip: trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final authVm = context.watch<AuthViewModel>();

    final trip = tripDetailVm.trip;
    final user = authVm.currentUser;
    final balanceSummary = tripDetailVm.balanceSummary;

    if (tripDetailVm.isLoading && trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              ShimmerSkeleton(height: 180),
              SizedBox(height: 20),
              ShimmerSkeleton(height: 80),
              SizedBox(height: 16),
              ShimmerSkeleton(height: 80),
            ],
          ),
        ),
      );
    }

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final gradientColors = AppColors.getGradient(trip.coverGradientIndex);
    final userNetPaise = balanceSummary.currentUserNetBalanceInPaise;
    final isCreator = user != null && trip.creatorId == user.id;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Text(trip.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trip.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Invite Friends',
            onPressed: () => _showInviteShareDialog(trip),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined, size: 20),
            tooltip: 'Add Friend',
            onPressed: _showAddFriendDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) {
            await tripDetailVm.refresh(user.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Trip Card
              _buildHeroTripCard(trip, balanceSummary, userNetPaise, isDark, gradientColors),

              const SizedBox(height: AppSpacing.lg),

              // Contextual Lifecycle Action Bar
              _buildLifecycleActionBar(trip, isCreator, isDark),

              const SizedBox(height: AppSpacing.lg),

              // Segmented Tab Switcher (Expenses vs Balances & People)
              _buildTabSwitcher(isDark, tripDetailVm.expenses.length, trip.members.length),

              const SizedBox(height: AppSpacing.lg),

              // Tab View Content
              if (_activeTab == 0)
                _buildExpensesTab(tripDetailVm, trip, isDark, user?.id ?? '')
              else
                _buildBalancesAndPeopleTab(trip, balanceSummary, isDark, user?.id ?? ''),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      floatingActionButton: trip.lifecycleState.allowsExpenses
          ? FloatingActionButton.extended(
              onPressed: () async {
                HapticHelper.light();
                final result = await context.push('/trip/${trip.id}/add-expense');
                if (result == true && user != null && mounted) {
                  await tripDetailVm.loadTrip(trip.id, user.id);
                  if (mounted) {
                    context.read<HomeViewModel>().loadTrips(user.id);
                  }
                }
              },
              backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add Expense',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )
          : null,
    );
  }

  Widget _buildHeroTripCard(
    Trip trip,
    BalanceSummary balanceSummary,
    int userNetPaise,
    bool isDark,
    List<Color> gradientColors,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: trip.lifecycleState.displayName.toUpperCase(),
                color: Colors.white,
                backgroundColor: Colors.black.withOpacity(0.25),
              ),
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.members.length} people',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            userNetPaise > 0
                ? 'YOU ARE OWED'
                : (userNetPaise < 0 ? 'YOU OWE' : 'YOUR BALANCE'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.formatPaise(
              userNetPaise.abs(),
              currencyCode: trip.currencyCode,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatPaise(
                      balanceSummary.totalTripSpentInPaise,
                      currencyCode: trip.currencyCode,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Invite Code', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    trip.inviteCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleActionBar(Trip trip, bool isCreator, bool isDark) {
    if (trip.lifecycleState == TripLifecycle.active) {
      if (isCreator) {
        return SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip is Active',
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    Text(
                      'Members can add expenses. Complete when trip ends.',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                text: 'Complete',
                height: 38,
                variant: AppButtonVariant.outline,
                onPressed: _showCompleteTripConfirmation,
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    } else if (trip.lifecycleState == TripLifecycle.completed || trip.lifecycleState == TripLifecycle.settling) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.indigoAccent : AppColors.indigoAccent).withOpacity(0.12),
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: AppColors.indigoAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.indigoAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trip Completed — Settlements Ready',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.indigoAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Normal expense entry is locked. View simplified transactions to settle up between friends.',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Settle Up Now',
              icon: Icons.payments_outlined,
              isFullWidth: true,
              height: 44,
              onPressed: _showSettlementSheet,
            ),
          ],
        ),
      );
    } else {
      // Settled
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withOpacity(0.12),
          borderRadius: AppRadius.lgBorder,
        ),
        child: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: AppColors.positiveGreenLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trip Fully Settled 🎉',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTabSwitcher(bool isDark, int expenseCount, int memberCount) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: AppRadius.mdBorder,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 0
                      ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                      : Colors.transparent,
                  borderRadius: AppRadius.smBorder,
                  boxShadow: _activeTab == 0
                      ? (isDark ? AppElevation.darkSubtle : AppElevation.lightSubtle)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Expenses ($expenseCount)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _activeTab == 0
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 1
                      ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                      : Colors.transparent,
                  borderRadius: AppRadius.smBorder,
                  boxShadow: _activeTab == 1
                      ? (isDark ? AppElevation.darkSubtle : AppElevation.lightSubtle)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Balances ($memberCount)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _activeTab == 1
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(TripDetailViewModel vm, Trip trip, bool isDark, String currentUserId) {
    if (vm.expenses.isEmpty) {
      return EmptyStateView(
        emoji: '🧾',
        title: 'No expenses recorded yet',
        subtitle: 'Tap "Add Expense" below to speak or enter the first shared expense for "${trip.name}".',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vm.expenses.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final expense = vm.expenses[index];
        final payer = trip.members.where((m) => m.id == expense.paidById).firstOrNull;
        final isPayerCurrentUser = payer != null && payer.userId == currentUserId;

        // User's share of this expense
        final userMember = trip.members.where((m) => m.userId == currentUserId).firstOrNull;
        final userSplit = userMember != null
            ? expense.splits.where((s) => s.memberId == userMember.id).firstOrNull
            : null;

        return SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category Emoji & Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  borderRadius: AppRadius.mdBorder,
                ),
                alignment: Alignment.center,
                child: Text(
                  expense.category.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Payer Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: AppTypography.titleSmall(isDark: isDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isPayerCurrentUser ? 'You' : (payer?.displayName ?? 'Someone')} paid • ${DateFormatter.formatRelative(expense.createdAt)}',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    if (expense.splits.length < trip.members.length) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Split between ${expense.splits.length} people',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Amount & User Share
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CurrencyDisplay(
                    amountInPaise: expense.amountInPaise,
                    size: CurrencyDisplaySize.medium,
                    colorMode: CurrencyColorMode.neutral,
                    currencyCode: trip.currencyCode,
                  ),
                  const SizedBox(height: 2),
                  if (userSplit != null)
                    Text(
                      isPayerCurrentUser
                          ? 'You lent ${CurrencyFormatter.formatPaise(expense.amountInPaise - userSplit.amountInPaise, currencyCode: trip.currencyCode)}'
                          : 'Your share: ${CurrencyFormatter.formatPaise(userSplit.amountInPaise, currencyCode: trip.currencyCode)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isPayerCurrentUser
                            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                            : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalancesAndPeopleTab(Trip trip, BalanceSummary balanceSummary, bool isDark, String currentUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Member Net Balances',
          style: AppTypography.titleSmall(isDark: isDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trip.members.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final member = trip.members[index];
            final net = balanceSummary.memberNetBalances[member.id] ?? 0;
            final isSelf = member.userId == currentUserId;

            return SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  MemberAvatar(
                    name: member.displayName,
                    isCreator: member.isCreator,
                    size: 40,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.displayName,
                              style: AppTypography.titleSmall(isDark: isDark),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              PillBadge(
                                label: 'You',
                                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          member.isCreator ? 'Trip Creator' : 'Member',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        net > 0 ? 'Gets back' : (net < 0 ? 'Owes' : 'Settled'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      CurrencyDisplay(
                        amountInPaise: net.abs(),
                        size: CurrencyDisplaySize.medium,
                        colorMode: net > 0
                            ? CurrencyColorMode.positive
                            : (net < 0 ? CurrencyColorMode.negative : CurrencyColorMode.neutral),
                        currencyCode: trip.currencyCode,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // Quick Settlement Preview Action
        if (balanceSummary.simplifiedSettlements.isNotEmpty) ...[
          Text(
            'Simplified Transfers',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            text: 'View ${balanceSummary.simplifiedSettlements.length} Direct Settlement Payments',
            icon: Icons.alt_route_rounded,
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: _showSettlementSheet,
          ),
        ],
      ],
    );
  }
}
