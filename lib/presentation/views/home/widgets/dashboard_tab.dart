import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/design_system/components/liquid_glass_button.dart';
import '../../../../core/design_system/components/liquid_glass_card.dart';
import '../../../../core/design_system/components/liquid_glass_modal_sheet.dart';
import '../../../../core/design_system/tokens/glass_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/kith_components.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../domain/models/trip.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/currency_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';

/// Pilot Screen: Main Trip Management Dashboard elevated with the Liquid Glass Design System.
/// Features frosted optical depth, 10th-power chamfered bevels, zero-jitter tabular figures,
/// strict 48x48dp interactive touch targets, and responsive light/dark themes.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final homeVm = context.watch<HomeViewModel>();
    final l10n = context.l10n;
    final user = authVm.currentUser;

    final trips = homeVm.trips;
    final Trip? activeTrip = trips.where((t) => t.lifecycleState.isActive || t.lifecycleState.isCompleting).firstOrNull;
    final activeBalance = activeTrip != null ? homeVm.tripBalances[activeTrip.id] : null;
    final activeNet = activeBalance?.currentUserNetBalanceInPaise ?? 0;

    int totalOwedToUser = 0;
    int totalUserOwes = 0;

    for (final trip in trips) {
      final bal = homeVm.tripBalances[trip.id];
      final net = bal?.currentUserNetBalanceInPaise ?? 0;
      if (net > 0) {
        totalOwedToUser += net;
      } else if (net < 0) {
        totalUserOwes += net.abs();
      }
    }

    final storage = context.watch<LocalStorageService>();
    final hasConfiguredPayment = storage.hasPaymentMethodConfigured();
    final isPromptDismissed = storage.isPaymentPromptDismissed();

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          _buildHeaderRow(context, user?.displayName ?? 'Traveler', isDark, l10n),
          if (!hasConfiguredPayment && !isPromptDismissed) ...[
            const SizedBox(height: 16),
            _buildPaymentSetupPromptCard(context, isDark, storage, l10n),
          ],
          const SizedBox(height: 20),
          if (activeTrip != null)
            _buildActiveTripHeroCard(context, activeTrip, activeNet, isDark, l10n)
          else
            _buildNoActiveTripHeroCard(context, isDark, l10n),
          const SizedBox(height: 24),
          _buildMyBalancesSection(context, totalOwedToUser, totalUserOwes, isDark, l10n),
          const SizedBox(height: 24),
          _buildQuickActionsSection(context, isDark, l10n),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildPaymentSetupPromptCard(
    BuildContext context,
    bool isDark,
    LocalStorageService storage,
    AppLocalizations l10n,
  ) {
    return KithCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashPaymentSetupTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.dashPaymentSetupSub,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Accessible 48x48dp touch target for dismiss
              Semantics(
                button: true,
                label: 'Dismiss payment setup prompt',
                child: Tooltip(
                  message: 'Dismiss',
                  child: InkWell(
                    onTap: () {
                      HapticHelper.light();
                      storage.dismissPaymentPrompt();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          KithButton(
            label: l10n.dashPaymentSetupBtn,
            icon: Icons.add_card_rounded,
            isFullWidth: true,
            variant: KithButtonVariant.primary,
            height: 44,
            onPressed: () {
              HapticHelper.selection();
              context.push('/payment-methods');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, String displayName, bool isDark, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.dashGreeting(displayName),
                  style: GlassTypography.titleLarge(isDark: isDark),
                ),
                const SizedBox(width: 6),
                const Text('👋', style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l10n.dashGreetingSub,
              style: GlassTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        // Notifications Button (Enforces 48x48dp target)
        Semantics(
          button: true,
          label: 'Notifications',
          child: Tooltip(
            message: 'Notifications',
            child: InkWell(
              onTap: () {
                HapticHelper.light();
                context.push('/notifications');
              },
              borderRadius: GlassRadii.pillBorder,
              child: Container(
                constraints: GlassSpacing.touchTargetConstraints,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? GlassColors.darkSurfaceSubtle : GlassColors.lightSurfaceSubtle,
                  border: Border.all(
                    color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
                    width: 1,
                  ),
                ),
                child: Builder(
                  builder: (ctx) {
                    LocalStorageService? storage;
                    try {
                      storage = ctx.watch<LocalStorageService>();
                    } catch (_) {}
                    final unreadCount = storage?.getUnreadNotificationCount() ?? 0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: isDark ? GlassColors.darkTextPrimary : const Color(0xFF334155),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 8,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: GlassColors.brandLight,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTripHeroCard(
    BuildContext context,
    Trip trip,
    int userNetPaise,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final netColor = userNetPaise > 0
        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
        : (userNetPaise < 0
            ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary));

    return KithCard(
      padding: const EdgeInsets.all(18.0),
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticHelper.light();
        context.push('/trip/${trip.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  trip.emoji.isNotEmpty ? trip.emoji : '🏝️',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormatter.formatTripDateRange(trip.createdAt, trip.updatedAt)} • ${trip.members.length == 1 ? l10n.tripCardMemberSingle : l10n.tripCardMemberPlural(trip.members.length)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Inner financial summary block (adheres to nested radius formula: outer 20 - padding 8 = 12)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userNetPaise > 0
                          ? l10n.dashYouAreOwed.toUpperCase()
                          : (userNetPaise < 0 ? l10n.dashYouOwe.toUpperCase() : l10n.dashAllSettled.toUpperCase()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userNetPaise > 0
                          ? '+${CurrencyFormatter.formatPaise(userNetPaise, currencyCode: trip.currencyCode)}'
                          : (userNetPaise < 0
                              ? '-${CurrencyFormatter.formatPaise(userNetPaise.abs(), currencyCode: trip.currencyCode)}'
                              : CurrencyFormatter.formatPaise(0, currencyCode: trip.currencyCode)),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: netColor,
                      ),
                    ),
                  ],
                ),
                if (userNetPaise != 0)
                  KithButton(
                    label: l10n.dashSettleUp,
                    icon: Icons.handshake_outlined,
                    variant: KithButtonVariant.primary,
                    height: 40,
                    onPressed: () {
                      HapticHelper.medium();
                      context.push('/trip/${trip.id}?tab=1');
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Settled',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveTripHeroCard(BuildContext context, bool isDark, AppLocalizations l10n) {
    return KithCard(
      padding: const EdgeInsets.all(18.0),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('✈️', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashNoActiveTrips,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.dashCreateTripPrompt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          KithButton(
            label: l10n.dashCreateBtn,
            variant: KithButtonVariant.primary,
            height: 40,
            onPressed: () {
              HapticHelper.light();
              context.push('/create-trip');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyBalancesSection(
    BuildContext context,
    int totalOwedToUser,
    int totalUserOwes,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final baseCurrency = context.watch<CurrencyViewModel>().currencyCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashMyBalances,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KithCard(
                padding: const EdgeInsets.all(16.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashYouAreOwed.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatPaise(totalOwedToUser, currencyCode: baseCurrency),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KithCard(
                padding: const EdgeInsets.all(16.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashYouOwe.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatPaise(totalUserOwes, currencyCode: baseCurrency),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, bool isDark, AppLocalizations l10n) {
    final homeVm = context.watch<HomeViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashQuickActions,
          style: GlassTypography.titleMedium(isDark: isDark),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(
              context: context,
              icon: Icons.add_rounded,
              label: l10n.dashActionAddExpense,
              isDark: isDark,
              onTap: () => _handleSmartAddExpense(context, homeVm),
            ),
            _buildActionItem(
              context: context,
              icon: Icons.flight_takeoff_rounded,
              label: l10n.dashActionAddTrip,
              isDark: isDark,
              onTap: () {
                HapticHelper.medium();
                context.push('/create-trip');
              },
            ),
            _buildActionItem(
              context: context,
              icon: Icons.document_scanner_rounded,
              label: l10n.dashActionScanReceipt,
              isDark: isDark,
              onTap: () => _handleSmartAddExpense(context, homeVm, tab: 1),
            ),
            _buildActionItem(
              context: context,
              icon: Icons.qr_code_scanner_rounded,
              label: l10n.dashActionJoinScanner,
              isDark: isDark,
              onTap: () async {
                HapticHelper.medium();
                final scannedCode = await context.push<String>('/qr-scanner');
                if (scannedCode != null && scannedCode.isNotEmpty && context.mounted) {
                  context.push('/trip-preview?code=$scannedCode');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _handleSmartAddExpense(BuildContext context, HomeViewModel homeVm, {int tab = 0}) {
    HapticHelper.medium();
    final trips = homeVm.trips;
    final activeTrips = trips.where((t) => t.lifecycleState.isActive || t.lifecycleState.isCompleting).toList();

    if (activeTrips.isEmpty) {
      _showNoActiveTripSheet(context);
    } else if (activeTrips.length == 1) {
      context.push('/trip/${activeTrips.first.id}/add-expense?tab=$tab');
    } else {
      _showActiveTripPickerSheet(context, activeTrips, tab);
    }
  }

  void _showNoActiveTripSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_off_rounded,
                  size: 32,
                  color: Color(0xFF14B8A6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Trip Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'There is no active trip to add expenses to. Create a new trip or join one with your friends to start splitting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LiquidGlassButton(
                text: 'Create New Trip',
                icon: Icons.add_rounded,
                isFullWidth: true,
                variant: LiquidGlassButtonVariant.primary,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/create-trip');
                },
              ),
              const SizedBox(height: 10),
              LiquidGlassButton(
                text: 'Join with Invite Code',
                icon: Icons.group_add_outlined,
                isFullWidth: true,
                variant: LiquidGlassButtonVariant.secondary,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/join-trip');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActiveTripPickerSheet(
    BuildContext context,
    List<Trip> trips,
    int tab,
  ) {
    final l10n = context.l10n;
    LiquidGlassModalSheet.show(
      context: context,
      title: l10n.dashSelectActiveTrip,
      subtitle: l10n.dashSelectTripSub,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...trips.map((trip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LiquidGlassCard(
                padding: const EdgeInsets.all(14.0),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/trip/${trip.id}/add-expense?tab=$tab');
                },
                child: Row(
                  children: [
                    Text(trip.emoji.isNotEmpty ? trip.emoji : '🏝️', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trip.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  letterSpacing: -0.1,
                  height: 1.15,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
