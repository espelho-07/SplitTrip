import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/components/liquid_glass_button.dart';
import '../../../core/design_system/components/liquid_glass_card.dart';
import '../../../core/design_system/tokens/glass_tokens.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/trip_lifecycle.dart';
import '../../../domain/models/balance_summary.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/journey_moment.dart';
import '../../../domain/models/payment_verification_request.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../../domain/services/trip_export_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/p2p_sync_service.dart';
import '../../../data/services/sync_service.dart';
import 'dart:async';
import '../../../core/localization/app_localizations.dart';
import '../add_expense/add_expense_view.dart';
import '../payment/payment_verification_dialog.dart';
import '../payment/payment_verification_view.dart';
import 'trip_members_view.dart';
import 'widgets/activity_log_sheet.dart';
import 'widgets/add_journey_moment_sheet.dart';
import 'widgets/add_journey_stop_sheet.dart';
import 'widgets/expense_detail_sheet.dart';
import 'widgets/member_spend_breakdown_sheet.dart';
import 'widgets/nearby_sync_badge.dart';
import 'widgets/nearby_trip_friends_radar_sheet.dart';
import 'widgets/trip_sync_sheet.dart';
import 'widgets/settlement_sheet.dart';
import 'widgets/trip_completion_verification_sheet.dart';
import 'widgets/trip_qr_sheet.dart';

class TripDetailView extends StatefulWidget {
  final String tripId;
  final String? settlementId;
  final String? expenseId;

  const TripDetailView({
    super.key,
    required this.tripId,
    this.settlementId,
    this.expenseId,
  });

  @override
  State<TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends State<TripDetailView> {
  int _topLevelTab = 0; // 0 = Spending, 1 = Journey, 2 = Memories
  int _spendingSubTab = 0; // 0 = Expenses, 1 = People, 2 = Categories
  final TextEditingController _searchController = TextEditingController();
  bool _dismissedLocationPrompt = false;
  bool _initialLoading = true;
  bool _isOpeningDeepLink = false;
  String _deepLinkStatus = '';
  String? _activePresentedExpenseId;
  bool _isPresentedSheetOpen = false;
  StreamSubscription<Map<String, dynamic>>? _notifSubscription;

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
    final hasExpenseDeepLink = widget.expenseId != null && widget.expenseId!.isNotEmpty;
    final hasSettlementDeepLink = widget.settlementId != null && widget.settlementId!.isNotEmpty;
    _isOpeningDeepLink = hasExpenseDeepLink || hasSettlementDeepLink;
    _deepLinkStatus = hasExpenseDeepLink
        ? 'Opening Expense Details...'
        : (hasSettlementDeepLink ? 'Loading Payment Verification...' : '');

    final vm = context.read<TripDetailViewModel>();
    _notifSubscription = vm.notificationEvents.listen((notif) async {
      if (mounted) {
        final payerName = notif['payerName'] as String? ?? 'A friend';
        final amountInPaise = notif['amountInPaise'] as int? ?? 0;
        final formatted = CurrencyFormatter.formatPaise(amountInPaise, currencyCode: notif['currency'] as String? ?? 'INR');
        final l10n = context.l10n;
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.payments_rounded, color: AppColors.emeraldLight, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.settlementNotifBody(payerName, formatted),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        await PaymentVerificationManager.checkAndPrompt(context);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authVm = context.read<AuthViewModel>();
      final tripDetailVm = context.read<TripDetailViewModel>();
      final expenseRepo = context.read<ExpenseRepository>();
      var user = authVm.currentUser;
      if (user == null) {
        try {
          await authVm.initSession().timeout(const Duration(seconds: 1));
          user = authVm.currentUser;
        } catch (_) {}
      }
      if (!mounted) return;
      final effectiveUserId = user?.id ?? '';
      
      // 1. FAST LOCAL HYDRATION: Immediate (< 5ms) sync from cache/SQLite
      tripDetailVm.hydrateLocally(widget.tripId, effectiveUserId);
      if (mounted) {
        setState(() => _initialLoading = false);
      }

      // 2. Immediate Deep Link handling (ZERO LAG - does not block on network)
      if (mounted) {
        await _handleDeepLinkNavigation();
      }

      // 3. Background settlements & trip sync non-blocking
      unawaited(tripDetailVm.loadTrip(widget.tripId, effectiveUserId));
      if (mounted) {
        expenseRepo.getSettlements(widget.tripId);
      }
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _searchController.dispose();
    try {
      context.read<TripDetailViewModel>().unsubscribeCurrentTrip();
    } catch (_) {}
    super.dispose();
  }

  void _showAddFriendDialog() {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.read<TripDetailViewModel>();
    final trip = tripDetailVm.trip;
    String? localError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
              title: Text(
                'Add Friend to Trip',
                style: AppTypography.titleMedium(isDark: isDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    onChanged: (_) {
                      if (localError != null) {
                        setDialogState(() => localError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Friend\'s name (e.g. Rahul, Tanya)',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      errorText: localError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          // Check if friend with same name already exists in active members
                          if (trip != null &&
                              trip.members.any((m) =>
                                  !m.isMerged &&
                                  m.displayName.trim().toLowerCase() == name.toLowerCase())) {
                            setDialogState(() {
                              localError = '$name is already a member of this trip';
                            });
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final authVm = context.read<AuthViewModel>();
                          final user = authVm.currentUser;
                          if (user != null) {
                            try {
                              await tripDetailVm.addMember(name, user.id);
                              HapticHelper.success();
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(KithErrorFormatter.format(e))),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCompleteTripConfirmation() {
    final tripDetailVm = context.read<TripDetailViewModel>();
    final trip = tripDetailVm.trip;
    if (trip == null) return;

    final remainingSettlements = tripDetailVm.balanceSummary.simplifiedSettlements;
    final totalPendingPaise = remainingSettlements.fold(0, (sum, s) => sum + s.amountInPaise);

    if (totalPendingPaise > 0) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final formattedTotal = CurrencyFormatter.formatPaise(totalPendingPaise, currencyCode: trip.currencyCode);

      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pending Payments Remaining',
                  style: AppTypography.titleMedium(isDark: isDark),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'There is still $formattedTotal pending across members in this trip.\n\nPlease settle outstanding balances between members before completing this trip.',
                style: AppTypography.bodyMedium(isDark: isDark),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(
                'Dismiss',
                style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                _showSettlementSheet();
              },
              child: const Text('Review Payments'),
            ),
          ],
        ),
      );
      return;
    }

    TripCompletionVerificationSheet.show(
      context,
      tripId: trip.id,
      onTripCompleted: () {
        if (mounted) {
          _showSettlementSheet();
        }
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
        onRecordTransfer: (
          fromMemberId,
          toMemberId,
          amountInPaise, {
          paymentReference,
          recipientUpiId,
          fromName,
          toName,
          paymentStatus,
        }) async {
          final fromMember = trip.members.where((m) => m.id == fromMemberId).firstOrNull;
          final toMember = trip.members.where((m) => m.id == toMemberId).firstOrNull;
          await tripDetailVm.recordSettlement(
            fromMemberId: fromMemberId,
            toMemberId: toMemberId,
            amountInPaise: amountInPaise,
            paymentReference: paymentReference,
            recipientUpiId: recipientUpiId,
            fromName: fromName,
            toName: toName,
            paymentStatus: paymentStatus ?? 'paid',
            currentUserId: authVm.currentUser?.id ?? '',
            fromUserId: fromMember?.userId,
            toUserId: toMember?.userId,
          );
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TripDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expenseChanged = widget.expenseId != null &&
        widget.expenseId!.isNotEmpty &&
        widget.expenseId != oldWidget.expenseId;
    final settlementChanged = widget.settlementId != null &&
        widget.settlementId!.isNotEmpty &&
        widget.settlementId != oldWidget.settlementId;

    if (expenseChanged || settlementChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleDeepLinkNavigation();
      });
    }
  }

  Future<void> _handleDeepLinkNavigation() async {
    final user = context.read<AuthViewModel>().currentUser;
    final effectiveUserId = user?.id ?? '';

    final hasExpenseDeepLink = widget.expenseId != null && widget.expenseId!.isNotEmpty;
    final hasSettlementDeepLink = widget.settlementId != null && widget.settlementId!.isNotEmpty;

    if (!hasExpenseDeepLink && !hasSettlementDeepLink) {
      await PaymentVerificationManager.checkAndPrompt(context);
      return;
    }

    final currentVm = context.read<TripDetailViewModel>();
    final expenseRepo = context.read<ExpenseRepository>();
    final storage = context.read<LocalStorageService>();

    if (hasExpenseDeepLink) {
      if (_isPresentedSheetOpen && _activePresentedExpenseId == widget.expenseId) {
        return;
      }

      Expense? targetExpense = currentVm.expenses.where((e) => e.id == widget.expenseId).firstOrNull;
      
      if (targetExpense == null) {
        if (mounted) {
          setState(() {
            _isOpeningDeepLink = true;
            _deepLinkStatus = 'Fetching expense from cloud...';
          });
        }
        try {
          final freshExpenses = await expenseRepo.getExpenses(widget.tripId).timeout(const Duration(seconds: 3));
          targetExpense = freshExpenses.where((e) => e.id == widget.expenseId).firstOrNull;
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isOpeningDeepLink = false);
        if (targetExpense != null && targetExpense.tripId == widget.tripId && currentVm.trip != null) {
          _showExpenseDetailSheet(targetExpense, currentVm.trip!, effectiveUserId);
        } else {
          debugPrint('[TripDetailView] Target expense ${widget.expenseId} not found or mismatched with trip ${widget.tripId}');
          await PaymentVerificationManager.checkAndPrompt(context);
        }
      }
    } else if (hasSettlementDeepLink) {
      final allPending = storage.getSavedPaymentVerifications();
      var match = allPending.firstWhere(
        (p) =>
            (p['settlementId'] == widget.settlementId || p['id'] == widget.settlementId) &&
            (p['tripId'] == null || p['tripId'] == widget.tripId),
        orElse: () => <String, dynamic>{},
      );

      if (match.isEmpty) {
        if (mounted) {
          setState(() {
            _isOpeningDeepLink = true;
            _deepLinkStatus = 'Syncing payment verification...';
          });
        }
        await expenseRepo.syncPendingVerifications(effectiveUserId);
        final updatedPending = storage.getSavedPaymentVerifications();
        match = updatedPending.firstWhere(
          (p) =>
              (p['settlementId'] == widget.settlementId || p['id'] == widget.settlementId) &&
              (p['tripId'] == null || p['tripId'] == widget.tripId),
          orElse: () => <String, dynamic>{},
        );
      }

      if (mounted) {
        setState(() => _isOpeningDeepLink = false);
        if (match.isNotEmpty) {
          final req = PaymentVerificationRequest.fromJson(match);
          final effectiveReq = (req.tripId.isEmpty && widget.tripId.isNotEmpty)
              ? req.copyWith(tripId: widget.tripId, tripName: currentVm.trip?.name ?? req.tripName)
              : req;

          if (effectiveReq.tripId == widget.tripId) {
            await PaymentVerificationView.show(context, request: effectiveReq);
          } else {
            debugPrint('[TripDetailView] Settlement verification ${widget.settlementId} trip mismatch: expected ${widget.tripId}, found ${effectiveReq.tripId}');
            await PaymentVerificationManager.checkAndPrompt(context);
          }
        } else {
          await PaymentVerificationManager.checkAndPrompt(context);
        }
      }
    }
  }

  void _showExpenseDetailSheet(Expense expense, Trip trip, String currentUserId) {
    if (_isPresentedSheetOpen && _activePresentedExpenseId == expense.id) {
      return;
    }
    if (_isPresentedSheetOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _isPresentedSheetOpen = true;
    _activePresentedExpenseId = expense.id;
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
    ).whenComplete(() {
      _isPresentedSheetOpen = false;
      _activePresentedExpenseId = null;
    });
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
    final tripRepo = context.watch<TripRepository>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;

    final cachedTrip = tripRepo.getCachedTripById(widget.tripId);
    final trip = (tripDetailVm.trip?.id == widget.tripId)
        ? tripDetailVm.trip
        : cachedTrip;
    final user = authVm.currentUser;
    final balanceSummary = tripDetailVm.balanceSummary;

    if (trip == null) {
      if (tripDetailVm.isLoading || _initialLoading || tripDetailVm.errorMessage == null) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (_isOpeningDeepLink) ...[
                  _buildDeepLinkLoadingBanner(isDark),
                  const SizedBox(height: 16),
                ],
                const ShimmerSkeleton(height: 180),
                const SizedBox(height: 20),
                const ShimmerSkeleton(height: 80),
                const SizedBox(height: 16),
                const ShimmerSkeleton(height: 80),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(height: 16),
                Text(
                  tripDetailVm.errorMessage ?? 'Trip not found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    final uid = user?.id ?? '';
                    if (uid.isNotEmpty) {
                      setState(() => _initialLoading = true);
                      tripDetailVm.loadTrip(widget.tripId, uid);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            icon: const Icon(Icons.qr_code_2_rounded, size: 22),
            tooltip: 'Share Trip & QR',
            onPressed: () => _showInviteShareDialog(trip),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            tooltip: 'Trip Options',
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
            onSelected: (val) {
              if (val == 'nearby_radar') {
                NearbyTripFriendsRadarSheet.show(
                  context,
                  trip: trip,
                  syncService: context.read<SyncService>(),
                  p2pService: context.read<P2PSyncService>(),
                  onSyncCompleted: () {
                    if (user != null) {
                      tripDetailVm.loadTrip(trip.id, user.id);
                    }
                  },
                );
              } else if (val == 'sync_trip') {
                TripSyncSheet.show(
                  context,
                  tripId: trip.id,
                  syncService: context.read<SyncService>(),
                  p2pService: context.read<P2PSyncService>(),
                  onSyncCompleted: () {
                    if (user != null) {
                      tripDetailVm.loadTrip(trip.id, user.id);
                    }
                  },
                );
              } else if (val == 'friend') {
                _showAddFriendDialog();
              } else if (val == 'activity') {
                _showActivityLogsSheet();
              } else if (val == 'export') {
                _showExportSheet(trip, tripDetailVm.expenses, balanceSummary);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'nearby_radar',
                child: Row(
                  children: [
                    Icon(Icons.radar_rounded, size: 18, color: AppColors.emeraldPrimary),
                    SizedBox(width: 10),
                    Text('Nearby Trip Friends', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync_trip',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: AppColors.emeraldPrimary),
                    SizedBox(width: 10),
                    Text('Sync Trip (Cloud & Nearby)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'friend',
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Add Friend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'activity',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Activity Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Export Financials', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
                  // Hero Trip Financial Overview Card
                  _buildHeroTripCard(
                    trip,
                    balanceSummary,
                    userNetPaise,
                    _calculateUserSpentPaise(tripDetailVm.expenses, user?.id, trip),
                    isDark,
                    gradientColors,
                    l10n,
                    isCreator,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Contextual Lifecycle Action Bar
                  _buildLifecycleActionBar(trip, isCreator, isDark, l10n),

                  const SizedBox(height: AppSpacing.lg),

                  // Top-Level Segmented Navigation [ 🏝️ Overview ] [ 💳 Spending ] [ 🗺️ Journey (if enabled) ]
                  _buildTopTabSwitcher(trip, isDark, l10n),

                  const SizedBox(height: AppSpacing.lg),

                  // Active Tab Content
                  if (_topLevelTab == 0)
                    _buildOverviewSection(tripDetailVm, trip, balanceSummary, isDark, user?.id ?? '', l10n)
                  else if (_topLevelTab == 1)
                    _buildSpendingSection(tripDetailVm, trip, balanceSummary, isDark, user?.id ?? '', l10n)
                  else if (trip.isJourneyEnabled)
                    _buildJourneySection(tripDetailVm, trip, isDark, user?.id ?? '')
                  else
                    _buildOverviewSection(tripDetailVm, trip, balanceSummary, isDark, user?.id ?? '', l10n),

                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
          if (_isOpeningDeepLink)
            Positioned(
              top: 14,
              left: 20,
              right: 20,
              child: Center(
                child: _buildDeepLinkLoadingBanner(isDark),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticHelper.light();
          if (_topLevelTab == 0 || _topLevelTab == 1 || !trip.isJourneyEnabled) {
            if (!trip.lifecycleState.allowsExpenses) {
              _showSettlementSheet();
              return;
            }
            final homeVm = context.read<HomeViewModel>();
            final messenger = ScaffoldMessenger.of(context);
            final result = await context.push('/trip/${trip.id}/add-expense');
            if (result == true && user != null && mounted) {
              await tripDetailVm.loadTrip(trip.id, user.id);
              if (mounted) {
                homeVm.loadTrips(user.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.tripsTitle),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          } else {
            _showAddJourneyMomentSheet(trip, tripDetailVm.expenses, user?.id ?? '');
          }
        },
        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        elevation: 4,
        icon: Icon(
          (_topLevelTab == 0 || _topLevelTab == 1 || !trip.isJourneyEnabled)
              ? (trip.lifecycleState.allowsExpenses ? Icons.add_rounded : Icons.payments_outlined)
              : Icons.add_location_alt_rounded,
          size: 20,
        ),
        label: Text(
          (_topLevelTab == 0 || _topLevelTab == 1 || !trip.isJourneyEnabled)
              ? (trip.lifecycleState.allowsExpenses ? l10n.tripDetailBtnAddExpense : l10n.tripDetailBtnSettleUp)
              : l10n.tripDetailBtnAddMoment,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
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
    AppLocalizations l10n,
    bool isCreator,
  ) {
    final totalTripPaise = balanceSummary.totalTripSpentInPaise;
    final netColor = userNetPaise > 0
        ? GlassColors.positive(isDark)
        : (userNetPaise < 0 ? GlassColors.negative(isDark) : (isDark ? Colors.white : const Color(0xFF0F172A)));

    return LiquidGlassCard(
      padding: const EdgeInsets.all(20.0),
      borderRadius: GlassRadii.xlBorder,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Trip Name (Full breathing room, never truncated)
              Padding(
                padding: const EdgeInsets.only(right: 68.0),
                child: Text(
                  trip.name,
                  style: GlassTypography.titleMedium(isDark: isDark).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),

              // 2. Subtitle: Date range, Members count, Lifecycle pill & Sync badge
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${DateFormatter.formatTripDateRange(trip.createdAt, trip.updatedAt)} • ${trip.members.where((m) => !m.isMerged).length == 1 ? l10n.tripCardMemberSingle : l10n.tripCardMemberPlural(trip.members.where((m) => !m.isMerged).length)}',
                    style: GlassTypography.bodySmall(isDark: isDark),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: trip.lifecycleState == TripLifecycle.active
                          ? (isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5))
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trip.lifecycleState.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: trip.lifecycleState == TripLifecycle.active
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                            : (isDark ? GlassColors.darkTextSecondary : GlassColors.lightTextSecondary),
                      ),
                    ),
                  ),
                  NearbySyncBadge(
                    p2pService: context.read<P2PSyncService>(),
                    syncService: context.read<SyncService>(),
                    tripId: trip.id,
                    trip: trip,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. User Balance & Trip Spent (Clean, bold, matching Home screen hero)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userNetPaise > 0
                              ? l10n.dashYouAreOwed
                              : (userNetPaise < 0 ? l10n.dashYouOwe : l10n.dashAllSettled),
                          style: GlassTypography.labelCaps(isDark: isDark),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.formatPaise(userNetPaise.abs(), currencyCode: trip.currencyCode),
                            style: GlassTypography.moneyLarge(isDark: isDark, color: netColor).copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL SPENT',
                        style: GlassTypography.labelCaps(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.formatPaise(totalTripPaise, currencyCode: trip.currencyCode),
                          style: GlassTypography.titleMedium(isDark: isDark).copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Action Buttons (Tactile Liquid Glass)
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassButton(
                      text: balanceSummary.simplifiedSettlements.isNotEmpty
                          ? '${l10n.tripDetailBtnSettleUp} (${balanceSummary.simplifiedSettlements.length})'
                          : l10n.tripDetailBtnSettleUp,
                      icon: Icons.handshake_outlined,
                      variant: LiquidGlassButtonVariant.primary,
                      onPressed: _showSettlementSheet,
                    ),
                  ),
                  if (isCreator && trip.lifecycleState == TripLifecycle.active) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: LiquidGlassButton(
                        text: l10n.tripDetailCompleteBtn,
                        icon: Icons.check_circle_outline_rounded,
                        variant: LiquidGlassButtonVariant.secondary,
                        onPressed: _showCompleteTripConfirmation,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Top-Right Frosted Circle with Emoji (Exact match to Home Screen hero card)
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? GlassColors.darkSurfaceSubtle : GlassColors.lightSurfaceSubtle,
                border: Border.all(
                  color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                trip.emoji.isNotEmpty ? trip.emoji : '🏝️',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleActionBar(Trip trip, bool isCreator, bool isDark, AppLocalizations l10n) {
    if (trip.lifecycleState == TripLifecycle.active) {
      return const SizedBox.shrink();
    } else if (trip.lifecycleState == TripLifecycle.completing) {
      final syncService = Provider.of<SyncService?>(context);
      final pendingCount = syncService != null ? syncService.getPendingCountForTrip(trip.id) : 0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.amberAccent.withValues(alpha: 0.12),
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: AppColors.amberAccent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.amberAccent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pendingCount > 0
                        ? l10n.tripDetailChangesSyncing(pendingCount)
                        : l10n.tripDetailFinishingSync,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.amberAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tripDetailSyncPendingDesc,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: 12),
            AppButton(
              text: l10n.tripDetailViewSettlements,
              icon: Icons.payments_outlined,
              isFullWidth: true,
              height: 44,
              variant: AppButtonVariant.outline,
              onPressed: _showSettlementSheet,
            ),
          ],
        ),
      );
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
                    l10n.tripDetailCompletedTitle,
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
              l10n.tripDetailSettledDesc,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: 12),
            AppButton(
              text: l10n.tripDetailSettleNowBtn,
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

  Widget _buildTopTabSwitcher(Trip trip, bool isDark, AppLocalizations l10n) {
    final tabs = [
      {'label': l10n.tripDetailTabOverview, 'icon': Icons.space_dashboard_outlined},
      {'label': l10n.tripDetailTabSpending, 'icon': Icons.credit_card_rounded},
      if (trip.isJourneyEnabled)
        {'label': l10n.tripDetailTabJourney, 'icon': Icons.map_outlined},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: AppRadius.mdBorder,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _topLevelTab == index;
          final tab = tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticHelper.selection();
                setState(() => _topLevelTab = index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                      : Colors.transparent,
                  borderRadius: AppRadius.smBorder,
                  boxShadow: isSelected
                      ? (isDark ? AppElevation.darkSubtle : AppElevation.lightSubtle)
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                        color: isSelected
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showAddJourneyMomentSheet(Trip trip, List<Expense> expenses, String currentUserId) {
    final vm = context.read<TripDetailViewModel>();
    AddJourneyMomentSheet.show(
      context,
      trip: trip,
      expenses: expenses,
      currentUserId: currentUserId,
      onAdd: (moment) {
        vm.addJourneyMoment(moment);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment saved to Journey ✓'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection(
    TripDetailViewModel vm,
    Trip trip,
    BalanceSummary balanceSummary,
    bool isDark,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    final recentExpenses = vm.expenses.take(4).toList();
    final recentMoments = vm.journeyMoments.take(3).toList();
    final isCreator = trip.creatorId == currentUserId ||
        trip.members.any((m) => m.userId == currentUserId && m.isCreator);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        // Trip Crew Card (Clean, focused, no duplicate trip name)
        LiquidGlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: GlassRadii.lgBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticHelper.light();
                        Navigator.push(context, TripMembersView.route(trip.id));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 18,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Members (${trip.members.where((m) => !m.isMerged).length})',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isCreator) ...[
                    InkWell(
                      onTap: () {
                        HapticHelper.light();
                        context.push('/trip/${trip.id}/members/manage');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.manage_accounts_rounded, size: 13, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                            const SizedBox(width: 3),
                            Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: _showAddFriendDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, size: 13, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                          const SizedBox(width: 3),
                          Text(
                            '+ Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: trip.members.where((m) => !m.isMerged).map((m) {
                  final isSelf = m.userId == currentUserId || m.id == currentUserId;
                  final isVirtual = m.isVirtual;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticHelper.light();
                      Navigator.push(context, TripMembersView.route(trip.id));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVirtual
                            ? (isDark ? Colors.amber.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.15))
                            : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                        borderRadius: BorderRadius.circular(16),
                        border: isVirtual
                            ? Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 1)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MemberAvatar(name: m.displayName, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isSelf ? '${m.displayName} ${l10n.tripDetailYouSuffix}' : m.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelf ? FontWeight.w700 : FontWeight.w500,
                              color: isVirtual
                                  ? Colors.amber.shade700
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
                          ),
                          if (isVirtual) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'VIRTUAL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Recent Spending Activity Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.tripDetailRecentSpending, style: AppTypography.titleSmall(isDark: isDark)),
            TextButton(
              onPressed: () {
                HapticHelper.selection();
                setState(() => _topLevelTab = 1);
              },
              child: Text(l10n.tripDetailViewAllSpending),
            ),
          ],
        ),
        if (recentExpenses.isEmpty) ...[
          EmptyStateView(
            emoji: '💳',
            title: l10n.tripDetailNoExpenses,
            subtitle: l10n.tripDetailNoExpensesSub,
            buttonText: l10n.tripDetailAddFirstExpense,
            onButtonPressed: () async {
              final homeVm = context.read<HomeViewModel>();
              final result = await context.push('/trip/${trip.id}/add-expense');
              if (result == true && mounted) {
                await vm.loadTrip(trip.id, currentUserId);
                homeVm.loadTrips(currentUserId);
              }
            },
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentExpenses.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final expense = recentExpenses[i];
              return _buildCleanExpenseRow(expense, trip, isDark, currentUserId, l10n);
            },
          ),
        ],

        if (trip.isJourneyEnabled) ...[
          const SizedBox(height: AppSpacing.lg),

          // Recent Journey Moments Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tripDetailJourneyTimeline, style: AppTypography.titleSmall(isDark: isDark)),
              TextButton(
                onPressed: () {
                  HapticHelper.selection();
                  setState(() => _topLevelTab = 2);
                },
                child: Text(l10n.tripDetailViewFullJourney),
              ),
            ],
          ),
          if (recentMoments.isEmpty) ...[
            EmptyStateView(
              emoji: '🗺️',
              title: l10n.tripDetailNoMoments,
              subtitle: l10n.tripDetailNoMomentsSub,
              buttonText: l10n.tripDetailAddFirstMoment,
              onButtonPressed: () => _showAddJourneyMomentSheet(trip, vm.expenses, currentUserId),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentMoments.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final moment = recentMoments[i];
                return _buildCleanMomentRow(moment, isDark);
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCleanExpenseRow(Expense expense, Trip trip, bool isDark, String currentUserId, AppLocalizations l10n) {
    final payer = trip.members.where((m) => m.id == expense.paidById || m.userId == expense.paidById).firstOrNull;
    final payerName = payer?.displayName ?? 'Member';
    final isPayerSelf = payer?.userId == currentUserId || payer?.id == currentUserId;

    final userSplit = expense.splits.where((s) => s.memberId == currentUserId || (payer != null && s.memberId == payer.id && isPayerSelf)).firstOrNull;
    final userSharePaise = userSplit?.amountInPaise ?? (expense.amountInPaise ~/ (expense.splits.isNotEmpty ? expense.splits.length : 1));

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _showExpenseDetailSheet(expense, trip, currentUserId),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              expense.category.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPayerSelf ? l10n.tripDetailYou : payerName} paid · ${DateFormatter.formatRelative(expense.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${(expense.amountInPaise / 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${l10n.tripDetailYourShare}: ₹${(userSharePaise / 100).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanMomentRow(JourneyMoment moment, bool isDark) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place_rounded, size: 18, color: AppColors.emeraldPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        moment.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Day ${moment.dayIndex} · ${DateFormatter.formatTime(moment.occurredAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                if (moment.placeName != null && moment.placeName!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          moment.placeName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (moment.note != null && moment.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    moment.note!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSection(
    TripDetailViewModel vm,
    Trip trip,
    BalanceSummary balanceSummary,
    bool isDark,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSpendingSubSwitcher(isDark, vm.expenses.length, trip.members.length, l10n),
        const SizedBox(height: AppSpacing.md),
        if (_spendingSubTab == 0)
          _buildExpensesTab(vm, trip, isDark, currentUserId, l10n)
        else if (_spendingSubTab == 1)
          _buildBalancesAndPeopleTab(trip, balanceSummary, vm.expenses, isDark, currentUserId)
        else
          _buildCategoriesBreakdownTab(trip, vm.expenses, isDark),
      ],
    );
  }

  Widget _buildSpendingSubSwitcher(bool isDark, int expenseCount, int memberCount, AppLocalizations l10n) {
    final subTabs = [
      {'label': '${l10n.tripDetailTabExpenses} ($expenseCount)', 'index': 0},
      {'label': '${l10n.tripDetailTabPeople} ($memberCount)', 'index': 1},
      {'label': l10n.tripDetailTabCategories, 'index': 2},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: AppRadius.mdBorder,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: subTabs.map((tab) {
          final idx = tab['index'] as int;
          final isSelected = _spendingSubTab == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticHelper.selection();
                setState(() => _spendingSubTab = idx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard)
                      : Colors.transparent,
                  borderRadius: AppRadius.smBorder,
                  boxShadow: isSelected
                      ? (isDark ? AppElevation.darkSubtle : AppElevation.lightSubtle)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tab['label'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isSelected
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJourneySection(TripDetailViewModel vm, Trip trip, bool isDark, String currentUserId) {
    final moments = vm.journeyMoments;
    final locationPromptBanner = !_dismissedLocationPrompt
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.emeraldPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-create Journey',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Kith can use your location during this trip to build your Journey automatically.',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _dismissedLocationPrompt = true);
                      },
                      child: Text('Not now', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () async {
                        setState(() => _dismissedLocationPrompt = true);
                        final granted = await PermissionService.requestLocationPermission();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(granted ? 'Location-assisted Journey enabled ✓' : 'Location permission not granted'),
                            ),
                          );
                        }
                      },
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final Map<int, List<JourneyMoment>> dayMap = {};
    for (final m in moments) {
      dayMap.putIfAbsent(m.dayIndex, () => []).add(m);
    }
    final sortedDays = dayMap.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        locationPromptBanner,
        _buildItineraryStopsSection(vm, trip, isDark),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Travel Timeline (${moments.length})', style: AppTypography.titleSmall(isDark: isDark)),
            TextButton.icon(
              onPressed: () => _showAddJourneyMomentSheet(trip, vm.expenses, currentUserId),
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text('Add Moment'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (moments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: EmptyStateView(
              emoji: '🗺️',
              title: 'No memories yet.',
              subtitle: 'Add your first moment when something worth remembering happens.',
              buttonText: 'Add Moment',
              onButtonPressed: () => _showAddJourneyMomentSheet(trip, vm.expenses, currentUserId),
            ),
          )
        else ...[
          ...sortedDays.map((day) {
            final dayMoments = dayMap[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DAY $day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                    ],
                  ),
                ),
                ...dayMoments.map((moment) {
                  final linkedExp = moment.expenseId != null
                      ? vm.expenses.where((e) => e.id == moment.expenseId).firstOrNull
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.place_rounded, size: 18, color: AppColors.emeraldPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      moment.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormatter.formatTime(moment.occurredAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              if (moment.placeName != null && moment.placeName!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        moment.placeName!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (moment.note != null && moment.note!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  moment.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                              if (linkedExp != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Linked: ${linkedExp.title} (₹${(linkedExp.amountInPaise / 100).toStringAsFixed(0)})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () {
                            HapticHelper.light();
                            vm.deleteJourneyMoment(moment.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
      ],
    );
  }

  Widget _buildItineraryStopsSection(TripDetailViewModel vm, Trip trip, bool isDark) {
    final stops = vm.journeyStops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Itinerary Stops (${stops.length})', style: AppTypography.titleSmall(isDark: isDark)),
            TextButton.icon(
              onPressed: () {
                HapticHelper.light();
                AddJourneyStopSheet.show(
                  context,
                  trip: trip,
                  onAdd: (stop) => vm.addJourneyStop(stop),
                );
              },
              icon: const Icon(Icons.add_road_rounded, size: 16),
              label: const Text('Add Stop'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (stops.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No stops planned yet. Add upcoming places, waypoints, or stays.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final stop = stops[index];
              return SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Day ${stop.dayNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.locationName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (stop.notes != null && stop.notes!.isNotEmpty)
                            Text(
                              stop.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      stop.time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                      onPressed: () {
                        HapticHelper.light();
                        vm.deleteJourneyStop(stop.id);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCategoriesBreakdownTab(Trip trip, List<Expense> expenses, bool isDark) {
    int totalTripSpent = 0;
    final Map<String, int> catAmounts = {};
    final Map<String, int> catCounts = {};

    for (final exp in expenses) {
      if (exp.isDeleted) continue;
      totalTripSpent += exp.amountInPaise;
      final catKey = exp.category.name;
      catAmounts[catKey] = (catAmounts[catKey] ?? 0) + exp.amountInPaise;
      catCounts[catKey] = (catCounts[catKey] ?? 0) + 1;
    }

    if (catAmounts.isEmpty) {
      return EmptyStateView(
        emoji: '📊',
        title: 'No category data yet',
        subtitle: 'Add expenses to see a breakdown of spending by category.',
      );
    }

    final sortedCategories = catAmounts.keys.toList()
      ..sort((a, b) => (catAmounts[b] ?? 0).compareTo(catAmounts[a] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category Spending Breakdown', style: AppTypography.titleSmall(isDark: isDark)),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedCategories.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final catName = sortedCategories[i];
            final amount = catAmounts[catName] ?? 0;
            final count = catCounts[catName] ?? 0;
            final percentage = totalTripSpent > 0 ? (amount / totalTripSpent) : 0.0;
            final percentInt = (percentage * 100).round();

            return SurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        catName.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      CurrencyDisplay(
                        amountInPaise: amount,
                        size: CurrencyDisplaySize.medium,
                        currencyCode: trip.currencyCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$count ${count == 1 ? "expense" : "expenses"}',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      Text(
                        '$percentInt% of trip',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
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

  String _getCategoryLabel(String? value, AppLocalizations l10n) {
    switch (value) {
      case 'food': return l10n.tripDetailCatFood;
      case 'transport': return l10n.tripDetailCatTransport;
      case 'stay': return l10n.tripDetailCatStay;
      case 'fuel': return l10n.tripDetailCatFuel;
      case 'activity': return l10n.tripDetailCatActivity;
      case 'shopping': return l10n.tripDetailCatShopping;
      case 'general': return l10n.tripDetailCatOther;
      default: return l10n.tripDetailCatAll;
    }
  }

  Widget _buildExpensesTab(TripDetailViewModel vm, Trip trip, bool isDark, String currentUserId, AppLocalizations l10n) {
    if (vm.expenses.isEmpty) {
      return EmptyStateView(
        emoji: '🧾',
        title: l10n.tripDetailNoExpenses,
        subtitle: l10n.tripDetailNoExpensesSub,
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
                  decoration: KithInputDecoration.borderless(
                    hintText: l10n.tripDetailSearchExpenses,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
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
                        _getCategoryLabel(cat['value'], l10n),
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
                            '${isPayerCurrentUser ? l10n.tripDetailYou : (payer?.displayName ?? 'Someone')} paid • ${DateFormatter.formatRelative(expense.createdAt)}',
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
                                : '${l10n.tripDetailYourShare} ${CurrencyFormatter.formatPaise(userSplit.amountInPaise, currencyCode: trip.currencyCode)}',
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

  Widget _buildBalancesAndPeopleTab(
    Trip trip,
    BalanceSummary balanceSummary,
    List<Expense> expenses,
    bool isDark,
    String currentUserId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Member Total Spending (Individual Consumption) Section
        _buildMemberSpendingSection(trip, expenses, isDark, currentUserId),

        const SizedBox(height: AppSpacing.lg),

        // 2. Personal Balances Section (Pairwise "What you owe / What they owe you")
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
              onTap: isSelf ? null : () => _showMemberOptions(context, member, trip),
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

  void _showMemberOptions(BuildContext context, TripMember member, Trip trip) {
    HapticHelper.light();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    MemberAvatar(name: member.displayName, avatarUrl: member.avatarUrl, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Member in ${trip.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary, size: 20),
                  ),
                  title: const Text('View Person Ledger & Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('See all lends, borrows & splits with ${member.displayName}', style: const TextStyle(fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/person-ledger?name=${Uri.encodeComponent(member.displayName)}&userId=${member.userId}');
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent, size: 20),
                  ),
                  title: Text('Add Expense with ${member.displayName}', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Pre-selects 1-on-1 split on this trip', style: TextStyle(fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/trip/${trip.id}/add-expense?memberId=${member.id}&person=${Uri.encodeComponent(member.displayName)}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberSpendingSection(
    Trip trip,
    List<Expense> expenses,
    bool isDark,
    String currentUserId,
  ) {
    int totalTripSpent = 0;
    for (final exp in expenses) {
      if (!exp.isDeleted) {
        totalTripSpent += exp.amountInPaise;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline_rounded, size: 18, color: AppColors.emeraldPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Member Total Spending',
                    style: AppTypography.titleSmall(isDark: isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'What each person consumed in "${trip.name}" (Tap for breakdown)',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trip.members.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final member = trip.members[index];
            final isSelf = member.userId == currentUserId;

            // Calculate member's total consumed share from non-deleted expenses
            int memberSpentPaise = 0;
            int expenseCount = 0;
            for (final exp in expenses) {
              if (exp.isDeleted) continue;
              final split = exp.splits.where((s) => s.memberId == member.id).firstOrNull;
              if (split != null && split.amountInPaise > 0) {
                memberSpentPaise += split.amountInPaise;
                expenseCount++;
              }
            }

            final percentage = totalTripSpent > 0
                ? ((memberSpentPaise / totalTripSpent) * 100).round()
                : 0;

            return SurfaceCard(
              onTap: () {
                MemberSpendBreakdownSheet.show(
                  context,
                  trip: trip,
                  member: member,
                  expenses: expenses,
                  currentUserId: currentUserId,
                );
              },
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                                  borderRadius: AppRadius.smBorder,
                                ),
                                child: Text(
                                  'CREATOR',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                  ),
                                ),
                              ),
                            ] else if (member.isVirtual) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.smBorder,
                                ),
                                child: Text(
                                  'VIRTUAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'} ($percentage% of trip)',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CurrencyDisplay(
                        amountInPaise: memberSpentPaise,
                        size: CurrencyDisplaySize.medium,
                        currencyCode: trip.currencyCode,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.emeraldPrimary),
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (member.isVirtual) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: AppRadius.smBorder,
                                  ),
                                  child: Text(
                                    'VIRTUAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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

  Widget _buildDeepLinkLoadingBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.emeraldLight,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _deepLinkStatus.isNotEmpty ? _deepLinkStatus : 'Loading Details...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
