import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../domain/models/expense.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/services/trip_export_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import '../add_expense/add_expense_view.dart';
import 'widgets/activity_log_sheet.dart';
import 'widgets/expense_detail_sheet.dart';
import 'widgets/settlement_sheet.dart';
import 'widgets/trip_qr_sheet.dart';

class TripDetailView extends StatefulWidget {
  final String tripId;

  const TripDetailView({super.key, required this.tripId});

  @override
  State<TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends State<TripDetailView> {
  int _activeTab = 0; // 0 = Expenses, 1 = Balances & People
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String?>> _categories = [
    {'label': 'All', 'value': null, 'emoji': '✨'},
    {'label': 'Food', 'value': 'food', 'emoji': '🍕'},
    {'label': 'Transport', 'value': 'transport', 'emoji': '🚗'},
    {'label': 'Stay', 'value': 'stay', 'emoji': '🏨'},
    {'label': 'Fuel', 'value': 'fuel', 'emoji': '⛽'},
    {'label': 'Activity', 'value': 'activity', 'emoji': '🎟️'},
    {'label': 'Shopping', 'value': 'shopping', 'emoji': '🛍️'},
    {'label': 'Other', 'value': 'general', 'emoji': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        context.read<TripDetailViewModel>().loadTrip(widget.tripId, user.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Text(
            'Add Friend to Trip',
            style: AppTypography.titleMedium(isDark: isDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter friend\'s name to add them as a trip member and split expenses.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Friend\'s name (e.g. Rahul, Tanya)',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  final tripDetailVm = context.read<TripDetailViewModel>();
                  final authVm = context.read<AuthViewModel>();
                  final user = authVm.currentUser;
                  if (user != null) {
                    await tripDetailVm.addMember(name, user.id);
                  }
                }
              },
              child: const Text('Add Member'),
            ),
          ],
        );
      },
    );
  }

  void _showCompleteTripConfirmation() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) {
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
                      color: AppColors.indigoAccent.withValues(alpha: 0.15),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Completing this trip locks expense creation and generates simplified settlement transfers for all members to settle debts.',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Keep Active',
                      variant: AppButtonVariant.outline,
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
        onRecordTransfer: (fromMemberId, toMemberId, amountInPaise) async {
          await tripDetailVm.recordSettlement(
            fromMemberId: fromMemberId,
            toMemberId: toMemberId,
            amountInPaise: amountInPaise,
            currentUserId: authVm.currentUser?.id ?? '',
          );
        },
        onMarkSettled: () {
          tripDetailVm.markAsSettled(authVm.currentUser?.id ?? '');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Trip marked as fully settled!')),
          );
        },
      ),
    );
  }

  void _showExpenseDetailSheet(Expense expense, Trip trip, String currentUserId) {
    final tripDetailVm = context.read<TripDetailViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseDetailSheet(
        expense: expense,
        trip: trip,
        currentUserId: currentUserId,
        onEdit: () async {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddExpenseView(
                tripId: trip.id,
                existingExpense: expense,
              ),
            ),
          );
          if (updated == true && mounted) {
            await tripDetailVm.refresh(currentUserId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated "${expense.title}"')),
              );
            }
          }
        },
        onDelete: () async {
          await tripDetailVm.deleteExpense(expense.id, currentUserId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Deleted "${expense.title}"')),
            );
          }
        },
      ),
    );
  }

  void _showActivityLogsSheet() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    tripDetailVm.fetchActivityLogs();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<TripDetailViewModel>(
        builder: (context, vm, _) => ActivityLogSheet(
          logs: vm.activityLogs,
          isLoading: vm.isLoadingActivity,
          onRefresh: vm.fetchActivityLogs,
        ),
      ),
    );
  }

  void _showExportSheet(Trip trip, List<Expense> expenses, BalanceSummary balanceSummary) {
    final textSummary = TripExportService.generateTextSummary(
      trip: trip,
      expenses: expenses,
      balanceSummary: balanceSummary,
    );
    final csvSummary = TripExportService.generateCsvSummary(
      trip: trip,
      expenses: expenses,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: AppRadius.topSheetBorder,
          ),
          padding: AppSpacing.bottomSheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Export Trip Financials', style: AppTypography.titleLarge(isDark: isDark)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Copy or share clean formatted summaries and CSV reports for ${trip.name}.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: 'Copy Text Summary',
                icon: Icons.copy_rounded,
                isFullWidth: true,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: textSummary));
                  HapticHelper.success();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied financial summary to clipboard!')),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Copy CSV Report',
                variant: AppButtonVariant.outline,
                icon: Icons.table_chart_outlined,
                isFullWidth: true,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvSummary));
                  HapticHelper.success();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied CSV report to clipboard!')),
                  );
                },
              ),
            ],
          ),
        );
      },
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final gradientColors = AppColors.getGradient(trip.coverGradientIndex);
    final userNetPaise = balanceSummary.currentUserNetBalanceInPaise;
    final isCreator = user != null && trip.creatorId == user.id;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
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
            icon: const Icon(Icons.history_rounded, size: 20),
            tooltip: 'Activity Logs',
            onPressed: _showActivityLogsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 20),
            tooltip: 'Export Financials',
            onPressed: () => _showExportSheet(trip, tripDetailVm.expenses, balanceSummary),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 22),
            tooltip: 'Trip QR Code & Invite',
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
              _buildHeroTripCard(
                trip,
                balanceSummary,
                userNetPaise,
                _calculateUserSpentPaise(tripDetailVm.expenses, user?.id, trip),
                isDark,
                gradientColors,
              ),

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
                final homeVm = context.read<HomeViewModel>();
                final result = await context.push('/trip/${trip.id}/add-expense');
                if (result == true && user != null && mounted) {
                  await tripDetailVm.loadTrip(trip.id, user.id);
                  if (mounted) {
                    homeVm.loadTrips(user.id);
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

  int _calculateUserSpentPaise(List<Expense> expenses, String? currentUserId, Trip trip) {
    if (currentUserId == null) return 0;
    final userMemberIds = <String>{currentUserId};
    for (final member in trip.members) {
      if (member.userId == currentUserId || member.id == currentUserId) {
        userMemberIds.add(member.id);
        userMemberIds.add(member.userId);
      }
    }
    if (trip.creatorId == currentUserId && trip.members.isNotEmpty) {
      userMemberIds.add(trip.members.first.id);
      userMemberIds.add(trip.members.first.userId);
    }

    int totalUserShare = 0;
    for (final exp in expenses) {
      if (exp.isDeleted) continue;
      final userSplits = exp.splits.where((s) => userMemberIds.contains(s.memberId)).toList();
      if (userSplits.isNotEmpty) {
        for (final s in userSplits) {
          totalUserShare += s.amountInPaise;
        }
      } else if (userMemberIds.contains(exp.paidById)) {
        totalUserShare += exp.amountInPaise;
      }
    }
    return totalUserShare;
  }

  Widget _buildHeroTripCard(
    Trip trip,
    BalanceSummary balanceSummary,
    int userNetPaise,
    int userSpentPaise,
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
            color: gradientColors[0].withValues(alpha: 0.35),
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
                backgroundColor: Colors.black.withValues(alpha: 0.25),
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
            (trip.lifecycleState == TripLifecycle.completed ||
                    trip.lifecycleState == TripLifecycle.settling ||
                    trip.lifecycleState == TripLifecycle.settled)
                ? (userNetPaise > 0
                    ? 'FINAL SETTLEMENT — TO RECEIVE'
                    : (userNetPaise < 0 ? 'FINAL SETTLEMENT — TO PAY' : 'FINAL SETTLEMENT — SETTLED'))
                : (userNetPaise > 0
                    ? 'CURRENT BALANCE — YOU ARE OWED'
                    : (userNetPaise < 0 ? 'CURRENT BALANCE — YOU OWE' : 'CURRENT BALANCE — SETTLED')),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
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
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.formatPaise(
                          balanceSummary.totalTripSpentInPaise,
                          currencyCode: trip.currencyCode,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('You Spent', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.formatPaise(
                          userSpentPaise,
                          currencyCode: trip.currencyCode,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  HapticHelper.light();
                  _showInviteShareDialog(trip);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CODE & QR', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700)),
                          Text(
                            trip.inviteCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.indigoAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trip is active. You can add expenses and invite members.',
                  style: AppTypography.bodySmall(isDark: isDark),
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
          color: AppColors.indigoAccent.withValues(alpha: 0.12),
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: AppColors.indigoAccent.withValues(alpha: 0.3),
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
          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.12),
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

    final filtered = vm.filteredExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            borderRadius: AppRadius.mdBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: vm.setSearchQuery,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search title or payer...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (vm.searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    vm.setSearchQuery('');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Horizontal Category Filter Pills
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = vm.selectedCategory == cat['value'];
              return GestureDetector(
                onTap: () {
                  HapticHelper.selection();
                  vm.setSelectedCategory(cat['value']);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                        : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                    borderRadius: AppRadius.fullBorder,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Column(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'No expenses match your filter',
                    style: AppTypography.titleSmall(isDark: isDark),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      vm.clearFilters();
                    },
                    child: const Text('Clear All Filters'),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final expense = filtered[index];
              final payer = trip.members.where((m) => m.id == expense.paidById).firstOrNull;
              final isPayerCurrentUser = payer != null && payer.userId == currentUserId;

              // User's share of this expense
              final userMember = trip.members.where((m) => m.userId == currentUserId).firstOrNull;
              final userSplit = userMember != null
                  ? expense.splits.where((s) => s.memberId == userMember.id).firstOrNull
                  : null;

              return SurfaceCard(
                onTap: () => _showExpenseDetailSheet(expense, trip, currentUserId),
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
                          currencyCode: trip.currencyCode,
                        ),
                        const SizedBox(height: 2),
                        if (userSplit != null)
                          Text(
                            isPayerCurrentUser
                                ? 'you lent ${CurrencyFormatter.formatPaise(expense.amountInPaise - userSplit.amountInPaise, currencyCode: trip.currencyCode)}'
                                : 'your share ${CurrencyFormatter.formatPaise(userSplit.amountInPaise, currencyCode: trip.currencyCode)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPayerCurrentUser
                                  ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                  : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'not involved',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBalancesAndPeopleTab(Trip trip, BalanceSummary balanceSummary, bool isDark, String currentUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Balances Section (Pairwise "What you owe / What they owe you")
        _buildPersonalBalancesSection(trip, balanceSummary, isDark, currentUserId),

        const SizedBox(height: AppSpacing.lg),

        Text(
          'All Member Net Balances',
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
                            Flexible(
                              child: Text(
                                isSelf ? '${member.displayName} (You)' : member.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (member.isCreator) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                                  borderRadius: AppRadius.smBorder,
                                ),
                                child: Text(
                                  'CREATOR',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          net > 0
                              ? 'Gets back ${CurrencyFormatter.formatPaise(net, currencyCode: trip.currencyCode)}'
                              : (net < 0
                                  ? 'Owes ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: trip.currencyCode)}'
                                  : 'Settled up'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: net > 0
                                ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                : (net < 0
                                    ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                          ),
                        ),
                      ],
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
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        // Settle Up Button
        if (balanceSummary.simplifiedSettlements.isNotEmpty)
          AppButton(
            text: 'View Simplified Settlements (${balanceSummary.simplifiedSettlements.length})',
            icon: Icons.payments_outlined,
            isFullWidth: true,
            onPressed: _showSettlementSheet,
          ),
      ],
    );
  }

  Widget _buildPersonalBalancesSection(
    Trip trip,
    BalanceSummary balanceSummary,
    bool isDark,
    String currentUserId,
  ) {
    final otherMembers = trip.members.where((m) => m.userId != currentUserId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_pin_rounded, size: 18, color: AppColors.emeraldPrimary),
            const SizedBox(width: 8),
            Text(
              'Your Personal Balances',
              style: AppTypography.titleSmall(isDark: isDark),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Exact breakdown of what you owe to and receive from each person',
          style: AppTypography.bodySmall(isDark: isDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (otherMembers.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No other members yet. Invite friends to start splitting!',
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherMembers.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final member = otherMembers[index];

              // What you owe this member
              final oweTransfer = balanceSummary.debtsToPay.where((d) => d.toMemberId == member.id).firstOrNull;
              final youOwePaise = oweTransfer?.amountInPaise ?? 0;

              // What this member owes you
              final receiveTransfer = balanceSummary.debtsToReceive.where((d) => d.fromMemberId == member.id).firstOrNull;
              final theyOwePaise = receiveTransfer?.amountInPaise ?? 0;

              final bool youOwe = youOwePaise > 0;
              final bool theyOwe = theyOwePaise > 0;

              final Color cardHighlightColor = youOwe
                  ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
                  : (theyOwe
                      ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted));

              return SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    MemberAvatar(
                      name: member.displayName,
                      isCreator: member.isCreator,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                youOwe
                                    ? Icons.arrow_upward_rounded
                                    : (theyOwe ? Icons.arrow_downward_rounded : Icons.check_circle_outline_rounded),
                                size: 14,
                                color: cardHighlightColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  youOwe
                                      ? 'You owe ${CurrencyFormatter.formatPaise(youOwePaise, currencyCode: trip.currencyCode)}'
                                      : (theyOwe
                                          ? 'Owes you ${CurrencyFormatter.formatPaise(theyOwePaise, currencyCode: trip.currencyCode)}'
                                          : 'Settled up'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cardHighlightColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (youOwe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight).withValues(alpha: 0.15),
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Text(
                          CurrencyFormatter.formatPaise(youOwePaise, currencyCode: trip.currencyCode),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                          ),
                        ),
                      )
                    else if (theyOwe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Text(
                          CurrencyFormatter.formatPaise(theyOwePaise, currencyCode: trip.currencyCode),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Text(
                          '₹0',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
