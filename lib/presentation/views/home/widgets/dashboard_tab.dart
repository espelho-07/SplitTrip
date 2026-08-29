import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../domain/models/trip.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';
import '../../personal/widgets/add_personal_expense_sheet.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final homeVm = context.watch<HomeViewModel>();
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final l10n = context.l10n;
    final user = authVm.currentUser;

    final trips = homeVm.trips;
    final Trip? activeTrip = trips.isNotEmpty ? trips.first : null;
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

    final debts = personalVm.debtsSummary;
    totalOwedToUser += debts.totalLentPaise;
    totalUserOwes += debts.totalBorrowedPaise;

    final storage = context.watch<LocalStorageService>();
    final hasConfiguredPayment = storage.hasPaymentMethodConfigured();
    final isPromptDismissed = storage.isPaymentPromptDismissed();

    return RefreshIndicator(
      onRefresh: () async {
        if (user != null) {
          await homeVm.refresh(user.id);
          await personalVm.loadData(user.id);
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
            RepaintBoundary(child: _buildActiveTripHeroCard(context, activeTrip, activeNet, isDark, l10n))
          else
            RepaintBoundary(child: _buildNoActiveTripHeroCard(context, isDark, l10n)),
          const SizedBox(height: 24),
          RepaintBoundary(child: _buildMyBalancesSection(context, totalOwedToUser, totalUserOwes, isDark, l10n)),
          const SizedBox(height: 24),
          _buildQuickActionsSection(context, isDark, l10n),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildPaymentSetupPromptCard(BuildContext context, bool isDark, LocalStorageService storage, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F1B16), const Color(0xFF0B1411)]
              : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.1 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.emeraldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashPaymentSetupTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.dashPaymentSetupSub,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticHelper.light();
                  storage.dismissPaymentPrompt();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticHelper.selection();
              context.push('/payment-methods');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_card_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.dashPaymentSetupBtn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('👋', style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l10n.dashGreetingSub,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        // Notifications Button
        GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticHelper.light();
                context.push('/notifications');
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
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
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF14B8A6),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticHelper.light();
          context.push('/trip/${trip.id}');
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1418) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${trip.name} ${trip.emoji}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormatter.formatTripDateRange(trip.createdAt, trip.updatedAt)} • ${trip.members.length == 1 ? l10n.tripCardMemberSingle : l10n.tripCardMemberPlural(trip.members.length)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userNetPaise > 0
                        ? l10n.dashYouAreOwed
                        : (userNetPaise < 0 ? l10n.dashYouOwe : l10n.dashAllSettled),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatPaise(userNetPaise.abs(), currencyCode: trip.currencyCode),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: userNetPaise > 0
                          ? const Color(0xFF14B8A6)
                          : (userNetPaise < 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A))),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.dashSettleUp,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.handshake_outlined, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 24,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                  ),
                  alignment: Alignment.center,
                  child: Text(trip.emoji.isNotEmpty ? trip.emoji : '🏝️', style: const TextStyle(fontSize: 30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoActiveTripHeroCard(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
            ),
            alignment: Alignment.center,
            child: const Text('✈️', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashNoActiveTrips,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.dashCreateTripPrompt,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              context.push('/create-trip');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.dashCreateBtn,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashMyBalances,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1418) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashYouAreOwed,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatPaise(totalOwedToUser, currencyCode: 'INR'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1418) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashYouOwe,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatPaise(totalUserOwes, currencyCode: 'INR'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Color(0xFFEF4444),
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
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
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
                  context.push('/join-trip?code=$scannedCode');
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

    if (trips.isEmpty) {
      AddPersonalExpenseSheet.show(context);
    } else if (trips.length == 1) {
      context.push('/trip/${trips.first.id}/add-expense?tab=$tab');
    } else {
      _showActiveTripPickerSheet(context, trips, tab);
    }
  }

  void _showActiveTripPickerSheet(
    BuildContext context,
    List<Trip> trips,
    int tab,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dashSelectActiveTrip,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dashSelectTripSub,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: trips.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/trip/${trip.id}/add-expense?tab=$tab');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(trip.emoji, style: const TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trip.members.length == 1 ? l10n.tripCardMemberSingle : l10n.tripCardMemberPlural(trip.members.length)} • ${trip.currencyCode}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  AddPersonalExpenseSheet.show(context);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.emeraldPrimary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.dashLogPersonalExpense,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
