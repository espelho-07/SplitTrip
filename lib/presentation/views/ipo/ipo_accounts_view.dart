import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo_account.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';

class IpoAccountsView extends StatefulWidget {
  const IpoAccountsView({super.key});

  @override
  State<IpoAccountsView> createState() => _IpoAccountsViewState();
}

class _IpoAccountsViewState extends State<IpoAccountsView> {
  static const Color forestGreen = Color(0xFF0E3E28);
  static const Color darkGreenText = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final accounts = ipoVm.accounts;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Accounts & Balances',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10B981) : forestGreen,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (accounts.isEmpty)
            _buildEmptyAccounts(isDark)
          else ...[
            ...accounts.map((acc) {
              final metrics = ipoVm.getAccountMetrics(acc.id);
              return _buildAccountCard(context, acc, metrics, ipoVm, isDark);
            }),
            const SizedBox(height: 12),
            _buildOverallSummaryCard(context, ipoVm, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    IpoAccount acc,
    Map<String, dynamic> metrics,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final apps = (metrics['applications'] as List<IpoApplication>?) ?? [];
    final pendingPaise = metrics['totalPendingPaise'] as int? ?? 0;
    final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(acc.id);

    final avatarColors = _getAvatarColors(acc.displayName, acc.isSelf);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            _showAccountDetailScreen(context, acc, metrics, ipoVm, isDark);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + Amount Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarColors['bg'],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          acc.displayName.isNotEmpty ? acc.displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: avatarColors['fg'],
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.isSelf ? '${acc.displayName} (Primary)' : acc.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${apps.length} IPO application${apps.length != 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              availableCreditPaise > 0
                                  ? CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR')
                                  : (pendingPaise > 0
                                      ? CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR')
                                      : '₹0'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: availableCreditPaise > 0
                                    ? (isDark ? const Color(0xFF34D399) : darkGreenText)
                                    : (pendingPaise > 0
                                        ? const Color(0xFFF59E0B)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                        Text(
                          availableCreditPaise > 0 ? 'Available' : (pendingPaise > 0 ? 'Pending' : 'Settled'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: availableCreditPaise > 0
                                ? (isDark ? const Color(0xFF34D399) : darkGreenText)
                                : (pendingPaise > 0
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pill Banner (Ready for Next IPO or Payment to Receive or Settled)
                if (availableCreditPaise > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.recycling_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR')} released • Ready for next IPO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFA7F3D0) : darkGreenText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (pendingPaise > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR')} pending • Payment to receive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'All payments settled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF10B981) : darkGreenText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallSummaryCard(BuildContext context, IpoViewModel ipoVm, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            _showSummarySheet(context, ipoVm, isDark);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.bar_chart_rounded, color: darkGreenText, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Overall Summary',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total applied, paid, pending & more',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SCREEN 4: Dedicated Account Detail / Transactions Screen
  // ══════════════════════════════════════════════════════════════════════════════
  void _showAccountDetailScreen(
    BuildContext context,
    IpoAccount acc,
    Map<String, dynamic> metrics,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final apps = (metrics['applications'] as List<IpoApplication>?) ?? [];
    final pendingPaise = metrics['totalPendingPaise'] as int? ?? 0;
    final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(acc.id);
    final notAllottedCount = apps.where((a) => a.status == IpoApplicationStatus.notAllotted || a.status == IpoApplicationStatus.refunded).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Top Action Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          acc.isSelf ? '${acc.displayName} (Primary)' : acc.displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        onPressed: () => _confirmDeleteAccount(context, acc, ipoVm, isDark),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    children: [
                      // Hero Vault Card (Dark Forest Green)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: forestGreen,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: forestGreen.withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Available for Next IPO',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notAllottedCount > 0
                                        ? 'From $notAllottedCount not allotted application${notAllottedCount > 1 ? "s" : ""}'
                                        : (availableCreditPaise > 0 ? 'Ready to allocate' : 'Zero unallocated funds'),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Filter Pills: All | IPO | Lending | Personal
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSubFilterPill('All', false, isDark),
                            const SizedBox(width: 8),
                            _buildSubFilterPill('IPO', true, isDark),
                            const SizedBox(width: 8),
                            _buildSubFilterPill('Lending', false, isDark),
                            const SizedBox(width: 8),
                            _buildSubFilterPill('Personal', false, isDark),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section Title: "IPO Transactions"
                      Text(
                        'IPO Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (apps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'No transactions recorded yet',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ...apps.map((app) => _buildTransactionItem(context, app, acc, ipoVm, isDark)),
                    ],
                  ),
                ),

                // Bottom Sticky Action Bar: [ Request Payment ] & [ + Add Transaction / Mark Received ]
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (pendingPaise > 0 && !acc.isSelf) ...[
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _sendWhatsAppAccountPaymentRequest(context, acc, pendingPaise),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text(
                                'Request Payment',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFF34D399) : darkGreenText,
                                side: BorderSide(color: isDark ? const Color(0xFF34D399) : darkGreenText, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticHelper.light();
                              Navigator.pop(sheetCtx);
                              context.push('/ipos');
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add Transaction',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    IpoApplication app,
    IpoAccount acc,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final isNotAllotted = app.status == IpoApplicationStatus.notAllotted || app.status == IpoApplicationStatus.refunded;
    final dateStr = DateFormatter.formatDate(app.applicationDate);

    final appAmount = CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR');
    final releasedAmount = CurrencyFormatter.formatPaise(app.releasedAmountInPaise ?? app.applicationAmountInPaise, currencyCode: 'INR');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // If Not Allotted: Show Released Back Transaction Row
          if (isNotAllotted) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEDD5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_outward_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.ipoName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Released back • $dateStr',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Not Allotted',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$releasedAmount',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 0.6, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
          ],

          // Application Amount Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.south_east_rounded, color: Color(0xFF2563EB), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.ipoName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Application Amount • $dateStr',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '-$appAmount',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          // If Payment Pending from non-self account: Show inline Mark as Received action
          if (app.effectiveRemainingPaise > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '${CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR')} pending',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      HapticHelper.medium();
                      await ipoVm.recordPayment(
                        applicationId: app.id,
                        amountInPaise: app.effectiveRemainingPaise,
                        note: 'Marked received for ${app.ipoName}',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Mark Received',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubFilterPill(String label, bool isSelected, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF10B981) : forestGreen)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER MODALS & ACTIONS
  // ══════════════════════════════════════════════════════════════════════════════
  void _showSummarySheet(BuildContext context, IpoViewModel ipoVm, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Portfolio Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow('Total Blocked / Applied', CurrencyFormatter.formatPaise(ipoVm.totalBlockedPaise, currencyCode: 'INR'), isDark),
              _buildSummaryRow('Total Invested (Allotted)', CurrencyFormatter.formatPaise(ipoVm.totalInvestedPaise, currencyCode: 'INR'), isDark),
              _buildSummaryRow('Total Released (Not Allotted)', CurrencyFormatter.formatPaise(ipoVm.totalReleasedPaise, currencyCode: 'INR'), isDark, color: const Color(0xFF10B981)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, IpoViewModel ipoVm, bool isDark) {
    final nameCtrl = TextEditingController();
    final panCtrl = TextEditingController();
    final bankCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add IPO Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Name (e.g. Brother, Papa)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: panCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'PAN Number (Optional, for auto-allotment)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Name / UPI (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    HapticHelper.medium();
                    await ipoVm.createAccount(
                      displayName: nameCtrl.text.trim(),
                      rawPan: panCtrl.text.trim().isNotEmpty ? panCtrl.text.trim() : null,
                      upiId: bankCtrl.text.trim().isNotEmpty ? bankCtrl.text.trim() : null,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context, IpoAccount acc, IpoViewModel ipoVm, bool isDark) {
    if (acc.isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete primary account.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${acc.displayName}?'),
        content: const Text('Are you sure you want to remove this account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              HapticHelper.medium();
              await ipoVm.deleteAccount(acc.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppAccountPaymentRequest(BuildContext context, IpoAccount acc, int pendingPaise) async {
    HapticHelper.medium();
    final remainingFormatted = CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR');

    final message = '*Kith — IPO Payment Request*\n'
        '*Account:* ${acc.displayName}\n'
        '*Amount Due:* $remainingFormatted\n'
        '*Status:* Pending Settlement\n\n'
        'Please send the remaining balance of $remainingFormatted for your IPO applications.\n'
        '— Sent via Kith';

    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    final webWaUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      } else if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment request copied to clipboard! Paste in WhatsApp or SMS.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Map<String, Color> _getAvatarColors(String name, bool isSelf) {
    if (isSelf) {
      return {'bg': const Color(0xFFDCFCE7), 'fg': darkGreenText}; // Emerald
    }
    final hash = name.hashCode.abs();
    final palettes = [
      {'bg': const Color(0xFFEFF6FF), 'fg': const Color(0xFF2563EB)}, // Blue
      {'bg': const Color(0xFFF5F3FF), 'fg': const Color(0xFF7E22CE)}, // Purple
      {'bg': const Color(0xFFFFEDD5), 'fg': const Color(0xFFEA580C)}, // Coral
      {'bg': const Color(0xFFFEF3C7), 'fg': const Color(0xFFD97706)}, // Amber
    ];
    return palettes[hash % palettes.length];
  }

  Widget _buildEmptyAccounts(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 14),
            Text(
              'No Accounts Created Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }
}
