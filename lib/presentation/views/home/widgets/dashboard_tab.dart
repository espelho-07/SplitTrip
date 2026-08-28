import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../domain/models/trip.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

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
          _buildHeaderRow(context, user?.displayName ?? 'Traveler', isDark),
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

  Widget _buildHeaderRow(BuildContext context, String displayName, bool isDark) {
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
                  'Hi, $displayName',
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
              "What's the plan today?",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // QR Scanner Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticHelper.light();
                context.push('/qr-scanner');
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
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 21,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 8),

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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 22,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
                    ),
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
                ),
              ),
            ),
          ],
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
                    '${DateFormatter.formatTripDateRange(trip.createdAt, trip.updatedAt)} • ${trip.members.length} members',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userNetPaise > 0
                        ? 'You are owed'
                        : (userNetPaise < 0 ? 'You owe' : 'All balances settled'),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Settle Up',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.handshake_outlined, size: 14, color: Colors.white),
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
                  'No Active Trips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create a trip to split expenses with friends',
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
              child: const Text(
                'Create',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
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
          'My Balances',
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
                      'You are owed',
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
                      'You owe',
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
    final homeVm = context.read<HomeViewModel>();
    final activeTrip = homeVm.trips.isNotEmpty ? homeVm.trips.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
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
              label: 'Add\nExpense',
              isDark: isDark,
              onTap: () {
                HapticHelper.medium();
                if (activeTrip != null) {
                  context.push('/trip/${activeTrip.id}/add-expense');
                } else {
                  context.push('/add-expense');
                }
              },
            ),
            _buildActionItem(
              context: context,
              icon: Icons.flight_takeoff_rounded,
              label: 'Add Trip',
              isDark: isDark,
              onTap: () {
                HapticHelper.medium();
                context.push('/create-trip');
              },
            ),
            _buildActionItem(
              context: context,
              icon: Icons.document_scanner_rounded,
              label: 'Scan\nReceipt',
              isDark: isDark,
              onTap: () {
                HapticHelper.medium();
                if (activeTrip != null) {
                  context.push('/trip/${activeTrip.id}/add-expense?tab=1');
                } else {
                  context.push('/add-expense?tab=1');
                }
              },
            ),
            _buildActionItem(
              context: context,
              icon: Icons.mic_rounded,
              label: 'Voice AI',
              isDark: isDark,
              onTap: () {
                HapticHelper.medium();
                if (activeTrip != null) {
                  context.push('/trip/${activeTrip.id}/add-expense?tab=0');
                } else {
                  context.push('/add-expense?tab=0');
                }
              },
            ),
          ],
        ),
      ],
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
