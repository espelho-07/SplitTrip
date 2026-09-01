import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
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
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final accounts = ipoVm.accounts;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        elevation: 0,
        title: Text(
          'IPO Accounts & Balances',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.emeraldPrimary),
            tooltip: 'Add Account',
            onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(height: 12),
                  Text(
                    'No IPO accounts added yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add First Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final acc = accounts[index];
                final metrics = ipoVm.getAccountMetrics(acc.id);
                return _buildAccountCard(context, acc, metrics, ipoVm, isDark);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Add New IPO Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
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
    final pendingPaise = metrics['totalPendingPaise'] as int? ?? 0;
    final appCount = metrics['applicationCount'] as int? ?? 0;
    final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(acc.id);

    String statusSubtitle = '';
    Color statusColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (pendingPaise > 0) {
      statusSubtitle = '${CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR')} pending';
      statusColor = pendingPaise > 0 ? (isDark ? Colors.amberAccent : Colors.amber.shade800) : statusColor;
    } else if (availableCreditPaise > 0) {
      statusSubtitle = '${CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR')} released credit';
      statusColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    } else {
      statusSubtitle = '₹0 pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          HapticHelper.light();
          _showAccountTimelineSheet(context, acc, metrics, ipoVm, isDark);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: acc.isSelf
                      ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15)
                      : Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  acc.isSelf ? Icons.person_rounded : Icons.person_outline_rounded,
                  color: acc.isSelf
                      ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                      : Colors.blueAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          acc.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (acc.isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '$appCount ${appCount == 1 ? 'application' : 'applications'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!acc.isSelf)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Delete Account',
                  onPressed: () => _confirmDeleteAccount(context, acc, ipoVm, isDark),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }



  void _showAddAccountSheet(BuildContext context, IpoViewModel ipoVm, bool isDark) {
    HapticHelper.light();
    final nameCtrl = TextEditingController();
    final panCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final upiCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
              Text(
                'Add IPO Application Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save family or friend accounts to easily apply for IPOs on their behalf.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Account Nickname *',
                  hintText: 'e.g. Brother, Papa, Friend',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: panCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'PAN Number (Optional, Securely Masked)',
                  hintText: 'e.g. ABCDE1234F',
                  helperText: 'Only last 4 digits are visible in the app for safety',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holderCtrl,
                decoration: InputDecoration(
                  labelText: 'Account Holder Full Name (Optional)',
                  hintText: 'As per bank account',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiCtrl,
                decoration: InputDecoration(
                  labelText: 'UPI ID (Optional)',
                  hintText: 'e.g. name@okhdfcbank',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    Navigator.pop(ctx);
                    await ipoVm.createAccount(
                      displayName: name,
                      rawPan: panCtrl.text.trim(),
                      accountHolderName: holderCtrl.text.trim(),
                      upiId: upiCtrl.text.trim(),
                    );
                    HapticHelper.success();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context, IpoAccount acc, IpoViewModel ipoVm, bool isDark) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        title: Text('Delete ${acc.displayName}?'),
        content: const Text('This will remove the account from your quick selection list. Previous applications will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ipoVm.deleteAccount(acc.id);
              HapticHelper.medium();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAccountTimelineSheet(
    BuildContext context,
    IpoAccount acc,
    Map<String, dynamic> metrics,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final apps = (metrics['applications'] as List<IpoApplication>?) ?? [];
    final pendingPaise = metrics['totalPendingPaise'] as int? ?? 0;
    final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(acc.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0B1117) : const Color(0xFFECE5DD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollCtrl) {
            return Column(
              children: [
                // ── WhatsApp-style header ──
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            acc.displayName.isNotEmpty ? acc.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
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
                              acc.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (acc.maskedPan.isNotEmpty)
                              Text(
                                'PAN: ${acc.maskedPan}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              )
                            else
                              Text(
                                '${apps.length} IPO application${apps.length != 1 ? "s" : ""}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Released credit sticky banner ──
                if (availableCreditPaise > 0)
                  Container(
                    width: double.infinity,
                    color: isDark ? const Color(0xFF0A3D26) : const Color(0xFF25D366).withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.recycling_rounded, size: 18, color: Color(0xFF25D366)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF075E54),
                              ),
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR'),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const TextSpan(text: ' released — available for next IPO'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Chat feed ──
                Expanded(
                  child: apps.isEmpty
                      ? Center(
                          child: Text(
                            'No applications yet for ${acc.displayName}',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                          itemCount: apps.length,
                          itemBuilder: (ctx2, idx) {
                            return _buildIpoChatThread(ctx2, apps[idx], acc, ipoVm, isDark);
                          },
                        ),
                ),

                // ── Bottom WhatsApp-style action bar ──
                if (pendingPaise > 0 && !acc.isSelf)
                  Container(
                    color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _sendWhatsAppAccountPaymentRequest(context, acc, pendingPaise),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Request ${CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR')} via WhatsApp',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIpoChatThread(
    BuildContext context,
    IpoApplication app,
    IpoAccount acc,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final events = _buildChatEvents(app, acc, ipoVm, isDark, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IPO name separator — WhatsApp date-chip style
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182229) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              app.ipoName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : const Color(0xFF54656F),
              ),
            ),
          ),
        ),
        ...events,
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _buildChatEvents(
    IpoApplication app,
    IpoAccount acc,
    IpoViewModel ipoVm,
    bool isDark,
    BuildContext context,
  ) {
    final bubbles = <Widget>[];
    final amt = CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR');
    final paid = CurrencyFormatter.formatPaise(app.effectivePaidPaise, currencyCode: 'INR');
    final remaining = CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR');
    final dateStr = DateFormatter.formatDate(app.applicationDate);

    // 1. Applied bubble
    bubbles.add(_chatBubble(
      isDark: isDark,
      isRight: false,
      icon: Icons.check_circle_outline_rounded,
      iconColor: Colors.blueAccent,
      title: 'Applied for ${app.lotsApplied} lot${app.lotsApplied > 1 ? "s" : ""} (${app.totalSharesApplied} shares)',
      subtitle: '$amt • $dateStr',
      bubbleColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      textColor: isDark ? Colors.white : const Color(0xFF111B21),
    ));

    // 2. Peer funding bubbles
    for (final f in app.fundings.where((f) => !f.isSelf)) {
      final fAmt = CurrencyFormatter.formatPaise(f.amountInPaise, currencyCode: 'INR');
      bubbles.add(_chatBubble(
        isDark: isDark,
        isRight: false,
        icon: Icons.person_pin_rounded,
        iconColor: Colors.orangeAccent,
        title: '${f.displayName} contributed $fAmt',
        subtitle: 'Peer funding for this application',
        bubbleColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
        textColor: isDark ? Colors.white : const Color(0xFF111B21),
      ));
    }

    // 3. Payment pending bubble
    final isPendingPayment = app.effectiveRemainingPaise > 0 &&
        app.status != IpoApplicationStatus.allotted &&
        app.status != IpoApplicationStatus.notAllotted &&
        app.status != IpoApplicationStatus.refunded;
    if (isPendingPayment) {
      bubbles.add(_chatBubble(
        isDark: isDark,
        isRight: false,
        icon: Icons.hourglass_top_rounded,
        iconColor: Colors.amber.shade600,
        title: '$remaining pending from ${acc.isSelf ? "you" : acc.displayName}',
        subtitle: '$paid received of $amt total',
        bubbleColor: isDark ? const Color(0xFF2A2000) : const Color(0xFFFFFBEB),
        textColor: isDark ? Colors.amberAccent : Colors.amber.shade900,
        action: _markReceivedAction(context, app, ipoVm),
      ));
    }

    // 4. Payment received bubble
    if (app.effectivePaidPaise > 0 &&
        app.effectiveRemainingPaise == 0 &&
        app.status != IpoApplicationStatus.notAllotted &&
        app.status != IpoApplicationStatus.refunded) {
      bubbles.add(_chatBubble(
        isDark: isDark,
        isRight: true,
        icon: Icons.done_all_rounded,
        iconColor: const Color(0xFF25D366),
        title: '$paid received ✓',
        subtitle: 'Payment settled',
        bubbleColor: isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6),
        textColor: isDark ? Colors.white : const Color(0xFF111B21),
      ));
    }

    // 5. Allotment result
    switch (app.status) {
      case IpoApplicationStatus.allotted:
        final invested = CurrencyFormatter.formatPaise(
          app.actualInvestedAmountInPaise ?? app.applicationAmountInPaise,
          currencyCode: 'INR',
        );
        bubbles.add(_chatBubble(
          isDark: isDark,
          isRight: true,
          icon: Icons.verified_rounded,
          iconColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
          title: '🎉 Allotted! ${app.allottedLots ?? 1} lot${(app.allottedLots ?? 1) > 1 ? "s" : ""}',
          subtitle: '$invested invested',
          bubbleColor: isDark ? const Color(0xFF003D2A) : const Color(0xFFD1FAE5),
          textColor: isDark ? AppColors.emeraldLight : const Color(0xFF065F46),
        ));
        break;

      case IpoApplicationStatus.notAllotted:
      case IpoApplicationStatus.refunded:
        final released = CurrencyFormatter.formatPaise(
          app.releasedAmountInPaise ?? app.applicationAmountInPaise,
          currencyCode: 'INR',
        );
        bubbles.add(_chatBubble(
          isDark: isDark,
          isRight: false,
          icon: Icons.undo_rounded,
          iconColor: Colors.purple.shade300,
          title: 'Not allotted — $released released',
          subtitle: 'Funds back in pool for next IPO',
          bubbleColor: isDark ? const Color(0xFF1A0F2E) : const Color(0xFFF3E8FF),
          textColor: isDark ? Colors.purple.shade200 : Colors.purple.shade800,
        ));
        break;

      case IpoApplicationStatus.partiallyAllotted:
        final invested = CurrencyFormatter.formatPaise(app.actualInvestedAmountInPaise ?? 0, currencyCode: 'INR');
        final releasedP = CurrencyFormatter.formatPaise(app.releasedAmountInPaise ?? 0, currencyCode: 'INR');
        bubbles.add(_chatBubble(
          isDark: isDark,
          isRight: true,
          icon: Icons.pie_chart_rounded,
          iconColor: Colors.amber.shade600,
          title: 'Partially allotted — ${app.allottedLots ?? 1} lot${(app.allottedLots ?? 1) > 1 ? "s" : ""}',
          subtitle: '$invested invested • $releasedP released',
          bubbleColor: isDark ? const Color(0xFF2A1500) : const Color(0xFFFEF3C7),
          textColor: isDark ? Colors.amberAccent : Colors.amber.shade900,
        ));
        break;

      case IpoApplicationStatus.refundPending:
        bubbles.add(_chatBubble(
          isDark: isDark,
          isRight: false,
          icon: Icons.sync_rounded,
          iconColor: Colors.blueGrey,
          title: 'Refund in process',
          subtitle: 'Funds credited within 2–3 business days',
          bubbleColor: isDark ? const Color(0xFF1A2332) : const Color(0xFFE0F2FE),
          textColor: isDark ? Colors.lightBlueAccent : Colors.blue.shade800,
        ));
        break;

      default:
        break;
    }

    // 6. Released credit reuse info pill
    final credit = ipoVm.getAccountAvailableCreditPaise(acc.id);
    if (credit > 0 &&
        (app.status == IpoApplicationStatus.notAllotted || app.status == IpoApplicationStatus.refunded)) {
      bubbles.add(
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A3D26) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings_rounded, size: 16, color: Color(0xFF25D366)),
                const SizedBox(width: 6),
                Text(
                  '${CurrencyFormatter.formatPaise(credit, currencyCode: 'INR')} available — reuse for next IPO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.emeraldLight : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return bubbles;
  }

  Widget _chatBubble({
    required bool isDark,
    required bool isRight,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color bubbleColor,
    required Color textColor,
    Widget? action,
  }) {
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isRight ? 16 : 4),
            bottomRight: Radius.circular(isRight ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 23),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.65),
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }

  Widget _markReceivedAction(BuildContext context, IpoApplication app, IpoViewModel ipoVm) {
    return GestureDetector(
      onTap: () async {
        HapticHelper.medium();
        await ipoVm.recordPayment(
          applicationId: app.id,
          amountInPaise: app.effectiveRemainingPaise,
          note: 'Marked received for ${app.ipoName} (${app.accountName})',
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR')} marked as received!',
              ),
              backgroundColor: const Color(0xFF25D366),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_rounded, size: 14, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'Mark as Received',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
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
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
    }
  }

}
