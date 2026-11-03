import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../../domain/models/person_ledger_item.dart';
import '../../../domain/models/personal_debt.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/person_ledger_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import 'widgets/person_settle_up_sheet.dart';

/// Ultra-Clean, Modern Financial Relationship Timeline & 1-on-1 Ledger for a Person.
/// Matches the exact design language with Top Summary Hero, Connected Vertical Timeline,
/// Transaction Cards with illustrations, Summary Bar, and "You Gave" / "You Got" Action Dock.
class PersonLedgerView extends StatefulWidget {
  final String personName;
  final String? personUserId;
  final String? personPhone;

  const PersonLedgerView({
    super.key,
    required this.personName,
    this.personUserId,
    this.personPhone,
  });

  @override
  State<PersonLedgerView> createState() => _PersonLedgerViewState();
}

class _PersonLedgerViewState extends State<PersonLedgerView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      context.read<PersonLedgerViewModel>().loadLedger(
            personName: widget.personName,
            personUserId: widget.personUserId,
            personPhone: widget.personPhone,
            currentUserId: user.id,
          );
    }
  }

  Future<void> _openWhatsAppReminder(PersonLedgerViewModel vm) async {
    HapticHelper.medium();
    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final formattedAmount = CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR');
    final user = context.read<AuthViewModel>().currentUser;
    final senderName = user?.displayName ?? 'Me';

    String text;
    if (net == 0) {
      text = 'Hey ${widget.personName}, our accounts on Kith are all settled up! 🎉 - $senderName';
    } else if (isOwed) {
      text = 'Hi ${widget.personName}, gentle reminder that ₹$formattedAmount is pending on Kith for our expenses. You can pay via UPI whenever convenient. Thanks! 🙏 - $senderName';
    } else {
      text = 'Hi ${widget.personName}, I owe you ₹$formattedAmount on Kith. Let me know your UPI ID so I can clear it. Thanks! 🙏 - $senderName';
    }

    await WhatsAppShareHelper.sendWhatsAppMessage(
      context: context,
      text: text,
      phone: widget.personPhone ?? vm.personPhone,
    );
  }

  void _openSettleUpModal(PersonLedgerViewModel vm) {
    HapticHelper.medium();
    PersonSettleUpSheet.show(
      context,
      personName: widget.personName,
      personUserId: widget.personUserId,
      personPhone: widget.personPhone ?? vm.personPhone,
      netBalancePaise: vm.netBalancePaise,
      onSettled: _loadData,
    );
  }

  void _openAddTransactionModal({required bool isLend}) {
    HapticHelper.light();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LedgerQuickAddSheet(
        personName: widget.personName,
        isLend: isLend,
        isDark: isDark,
        onAdded: () {
          _loadData();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        },
      ),
    );
  }

  void _showSummaryDetailsSheet(BuildContext context, PersonLedgerViewModel vm, bool isDark) {
    HapticHelper.selection();
    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final isSettled = net == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141A21) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00594C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        size: 20,
                        color: Color(0xFF00594C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Summary with ${widget.personName}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stat Cards Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C241B) : const Color(0xFFF2FBF7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF134533) : const Color(0xFFD1FAE5),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total You Gave',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(vm.totalLentPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1D2F) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total You Got',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(vm.totalBorrowedPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Net Balance Pill
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B) : const Color(0xFF03312B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSettled
                                ? 'Net Balance'
                                : (isOwed ? 'Net Receivable (You will get)' : 'Net Payable (You owe)'),
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSettled ? '₹0 (Settled)' : CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
                      if (!isSettled)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openSettleUpModal(vm);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Settle Up', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Transactions Count
                Center(
                  child: Text(
                    '${vm.items.length} total transaction(s) recorded in ledger',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonLedgerViewModel>();

    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final isYouOwe = net < 0;
    final isSettled = net == 0;

    final subtitleText = isSettled
        ? 'All settled up ✓'
        : (isOwed
            ? 'You get ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'
            : 'You owe ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}');

    final items = vm.items;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1014) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF0B1014) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFF00897B),
              child: Text(
                widget.personName.isNotEmpty ? widget.personName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.personName,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSettled
                          ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                          : const Color(0xFF059669),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            tooltip: 'Share Statement',
            onPressed: () => _openWhatsAppReminder(vm),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            onPressed: () => _showLedgerOptionsMenu(context, vm, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Net Summary Card (Dark Teal Gradient Card)
          _buildTopSummaryHeroCard(isDark, vm, net, isOwed, isYouOwe, isSettled),

          // Timeline Transactions List
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (items.isEmpty ? _buildEmptyTimelineState(isDark) : _buildTimelineFeed(items, isDark)),
          ),

          // Summary Pill Bar with Person
          if (items.isNotEmpty)
            _buildSummaryWithPersonCard(isDark, vm),

          // Bottom Action Bar: "You Gave" & "You Got" Side-by-Side Dock
          _buildBottomActionDock(isDark, vm),
        ],
      ),
    );
  }

  /// 1. Top Summary Hero Card matching the Dark Teal UI from screenshot
  Widget _buildTopSummaryHeroCard(
    bool isDark,
    PersonLedgerViewModel vm,
    int net,
    bool isOwed,
    bool isYouOwe,
    bool isSettled,
  ) {
    final netLabel = isSettled
        ? 'Net Balance'
        : (isYouOwe ? 'Net Payable' : 'Net Receivable');

    final formattedNet = CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR');
    final formattedTotal = CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF022B25),
            Color(0xFF043E35),
            Color(0xFF064E43),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF022B25).withValues(alpha: isDark ? 0.4 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Net Payable / Amount / Pill
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  netLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedNet,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isYouOwe
                            ? Icons.arrow_outward_rounded
                            : (isOwed ? Icons.call_received_rounded : Icons.check_rounded),
                        size: 13,
                        color: const Color(0xFF4ADE80),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSettled ? 'Settled' : (isYouOwe ? 'You owe' : 'You will get'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider Line
          Container(
            width: 0.8,
            height: 64,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 16),

          // Right: Total Balance + Remind Button
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total balance',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedTotal,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4ADE80),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Remind or Settle Up Pill Button
                if (!isSettled)
                  InkWell(
                    onTap: () {
                      if (isYouOwe) {
                        _openSettleUpModal(vm);
                      } else {
                        _openWhatsAppReminder(vm);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isYouOwe
                            ? const Color(0xFF10B981).withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isYouOwe ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isYouOwe ? Icons.flash_on_rounded : Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: isYouOwe ? const Color(0xFF4ADE80) : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isYouOwe ? 'Settle Up' : 'Remind',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isYouOwe ? const Color(0xFF4ADE80) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Settled ✓',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Vertical Connected Timeline Feed
  Widget _buildTimelineFeed(List<PersonLedgerItem> items, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // Date Header Divider Logic
        bool showDateHeader = false;
        if (index == 0) {
          showDateHeader = true;
        } else {
          final prevItem = items[index - 1];
          final sameDay = item.date.year == prevItem.date.year &&
              item.date.month == prevItem.date.month &&
              item.date.day == prevItem.date.day;
          if (!sameDay) showDateHeader = true;
        }

        final isLast = index == items.length - 1;

        final dateHeaderStr = DateFormatter.isToday(item.date)
            ? 'TODAY'
            : (DateFormatter.isYesterday(item.date)
                ? 'YESTERDAY'
                : DateFormatter.formatDate(item.date).toUpperCase());

        return Column(
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        thickness: 0.8,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        dateHeaderStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        thickness: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

            // Timeline Row Item with connected line
            _buildTimelineRowItem(item, isDark, isLast),
          ],
        );
      },
    );
  }

  /// 3. Single Timeline Row with Left Time, Center Stepper Line & Right Transaction Card
  Widget _buildTimelineRowItem(PersonLedgerItem item, bool isDark, bool isLast) {
    final isOutgoing = item.isCreditToUser; // You Paid / Lent
    final timeStr = DateFormatter.formatTime(item.date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Left Time Label
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isOutgoing
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669))
                      : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
              ),
            ),
          ),

          // 2. Middle Stepper Line & Circle Node
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? (isDark ? const Color(0xFF133829) : const Color(0xFFE6F4EA))
                        : (isDark ? const Color(0xFF172D4A) : const Color(0xFFEFF6FF)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOutgoing
                          ? (isDark ? const Color(0xFF2D6A4F) : const Color(0xFFA7F3D0))
                          : (isDark ? const Color(0xFF2B527E) : const Color(0xFFBFDBFE)),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isOutgoing ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                      size: 13,
                      color: isOutgoing
                          ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669))
                          : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLast
                        ? Colors.transparent
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Right Transaction Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: isOutgoing
                      ? (isDark ? const Color(0xFF0C241B) : const Color(0xFFF2FBF7))
                      : (isDark ? const Color(0xFF0F1D2F) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOutgoing
                        ? (isDark ? const Color(0xFF134533) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0)),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Tag + Illustration
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isOutgoing
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isOutgoing
                                      ? 'You Paid / Lent'
                                      : '${widget.personName} Paid / You Borrowed',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isOutgoing
                                        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669))
                                        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top Right Illustration Graphic
                        if (isOutgoing)
                          _buildCashIllustration(isDark)
                        else
                          _buildCardIllustration(isDark),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Amount
                    Text(
                      CurrencyFormatter.formatPaise(item.amountInPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Note / Description
                    Text(
                      item.title.isNotEmpty
                          ? item.title
                          : (isOutgoing ? 'Direct Loan' : 'Borrowed from ${widget.personName}'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),

                    if (item.note != null && item.note!.isNotEmpty && item.note != item.title) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Bottom Right Timestamp + Double Tick
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (isOutgoing) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cash / Currency Note Graphic for Lent Transactions
  Widget _buildCashIllustration(bool isDark) {
    return SizedBox(
      width: 54,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back bill (tilted)
          Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF133829) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D6A4F) : const Color(0xFFA7F3D0),
                  width: 0.8,
                ),
              ),
            ),
          ),
          // Front bill
          Container(
            width: 46,
            height: 26,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B4332) : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF40916C) : const Color(0xFF86EFAC),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF52B788) : const Color(0xFF34D399),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF059669),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Credit Card Illustration for Borrowed Transactions
  Widget _buildCardIllustration(bool isDark) {
    return SizedBox(
      width: 54,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back layer
          Container(
            width: 42,
            height: 26,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172D4A) : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          // Front Card
          Container(
            width: 46,
            height: 26,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Summary Card with Person (Above Bottom Buttons)
  Widget _buildSummaryWithPersonCard(bool isDark, PersonLedgerViewModel vm) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF00594C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: Color(0xFF00594C),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Summary with ${widget.personName}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${vm.items.length} transaction${vm.items.length == 1 ? "" : "s"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showSummaryDetailsSheet(context, vm, isDark),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Bottom Action Dock with Side-by-Side "You Gave" & "You Got"
  Widget _buildBottomActionDock(bool isDark, PersonLedgerViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1014) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: YOU GAVE
            Expanded(
              child: InkWell(
                onTap: () => _openAddTransactionModal(isLend: true),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00594C),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00594C).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'You Gave',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Add payment / loan',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Right: YOU GOT
            Expanded(
              child: InkWell(
                onTap: () => _openAddTransactionModal(isLend: false),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D62D4),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D62D4).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'You Got',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Add payment / loan',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTimelineState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00594C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 40,
                color: Color(0xFF00594C),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No records with ${widget.personName} yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "You Gave" or "You Got" below to log transactions directly with your app keypad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLedgerOptionsMenu(BuildContext context, PersonLedgerViewModel vm, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161F26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flash_on_rounded, color: AppColors.emeraldPrimary),
                title: const Text('Settle Up / Record Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openSettleUpModal(vm);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                title: const Text('Share Ledger Summary on WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsAppReminder(vm);
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Color(0xFF00594C)),
                title: const Text('View Detailed Relationship Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSummaryDetailsSheet(context, vm, isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
                title: const Text('Add 1-on-1 Trip Split Expense', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-expense?person=${Uri.encodeComponent(widget.personName)}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-App Keypad Sheet for instant WhatsApp/Ledger transaction entry.
class _LedgerQuickAddSheet extends StatefulWidget {
  final String personName;
  final bool isLend;
  final bool isDark;
  final VoidCallback onAdded;

  const _LedgerQuickAddSheet({
    required this.personName,
    required this.isLend,
    required this.isDark,
    required this.onAdded,
  });

  @override
  State<_LedgerQuickAddSheet> createState() => _LedgerQuickAddSheetState();
}

class _LedgerQuickAddSheetState extends State<_LedgerQuickAddSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final amountPaise = (amount * 100).round();
    final note = _noteController.text.trim();
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    final vm = context.read<PersonalExpenseViewModel>();
    final debt = await vm.addDebt(
      userId: user.id,
      personName: widget.personName,
      debtType: widget.isLend ? PersonalDebtType.lent : PersonalDebtType.borrowed,
      amountInPaise: amountPaise,
      description: note.isEmpty ? null : note,
      date: DateTime.now(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (debt != null) {
        Navigator.of(context).pop();
        widget.onAdded();
        HapticHelper.success();
      } else {
        HapticHelper.error();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isLend = widget.isLend;

    final primaryColor = isLend ? const Color(0xFF00594C) : const Color(0xFF0D62D4);
    final actionTitle = isLend ? 'You Paid / Lent ${widget.personName}' : '${widget.personName} Paid / You Borrowed';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isLend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Native Amount Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                  hintText: '0',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B1014) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Note Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.notes_rounded, size: 18, color: primaryColor),
                  hintText: 'Add a note (e.g. Dinner, Rent, Fuel)...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B1014) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Save Action Button
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleSave,
                  child: const Text(
                    'SAVE TRANSACTION',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
