import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_numeric_keypad.dart';
import '../../../core/widgets/kith_text_keypad.dart';
import '../../../domain/models/person_ledger_item.dart';
import '../../../domain/models/personal_debt.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/person_ledger_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

/// WhatsApp Chat-Style Financial Relationship Timeline & 1-on-1 Ledger for a Person.
class PersonLedgerView extends StatefulWidget {
  final String personName;
  final String? personUserId;

  const PersonLedgerView({
    super.key,
    required this.personName,
    this.personUserId,
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
            currentUserId: user.id,
          );
    }
  }

  Future<void> _openWhatsAppReminder(PersonLedgerViewModel vm) async {
    HapticHelper.medium();
    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final formattedAmount = CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR');

    String text;
    if (net == 0) {
      text = 'Hey ${widget.personName}, our accounts on Kith are all settled up! 🎉';
    } else if (isOwed) {
      text = 'Hi ${widget.personName}, just a gentle reminder that ₹$formattedAmount is pending on Kith for our expenses. You can pay via UPI whenever convenient. Thanks! 🙏';
    } else {
      text = 'Hi ${widget.personName}, I owe you ₹$formattedAmount on Kith. Let me know your UPI ID so I can clear it. Thanks! 🙏';
    }

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonLedgerViewModel>();

    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final isYouOwe = net < 0;
    final isSettled = net == 0;

    final balanceColor = isSettled
        ? (isDark ? Colors.white60 : Colors.black54)
        : (isOwed
            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
            : const Color(0xFFF59E0B));

    final balanceText = isSettled
        ? 'Settled ✓'
        : (isOwed
            ? 'You will get ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'
            : 'You owe ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}');

    final items = vm.items;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1014) : const Color(0xFFEFEAE2),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: isDark ? const Color(0xFF161F26) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: isDark ? const Color(0xFF222E35) : const Color(0xFF128C7E),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    balanceText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isSettled ? Colors.white70 : (isOwed ? const Color(0xFF4ADE80) : const Color(0xFFFCD34D)),
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
            icon: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
            tooltip: 'Share on WhatsApp',
            onPressed: () => _openWhatsAppReminder(vm),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () => _showLedgerOptionsMenu(context, vm, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Summary Pill Banner
          _buildTopSummaryBanner(isDark, vm, net, isOwed, isYouOwe, isSettled, balanceColor),

          // WhatsApp Chat Timeline Feed
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (items.isEmpty ? _buildEmptyChatState(isDark) : _buildChatFeed(items, isDark)),
          ),

          // Bottom WhatsApp Action Bar (You Gave / You Got + In-App Keypad)
          _buildBottomChatBar(isDark, vm),
        ],
      ),
    );
  }

  Widget _buildTopSummaryBanner(
    bool isDark,
    PersonLedgerViewModel vm,
    int net,
    bool isOwed,
    bool isYouOwe,
    bool isSettled,
    Color balanceColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF10171D) : const Color(0xFFD8D0C5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isSettled
                    ? Icons.check_circle_outline_rounded
                    : (isOwed ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                size: 14,
                color: balanceColor,
              ),
              const SizedBox(width: 6),
              Text(
                isSettled
                    ? 'Total Balance: Settled'
                    : (isOwed
                        ? 'Net Receivable: ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'
                        : 'Net Payable: ${CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR')}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => _openWhatsAppReminder(vm),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF25D366), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_rounded, size: 12, color: Color(0xFF25D366)),
                  SizedBox(width: 4),
                  Text(
                    'Remind',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF25D366),
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

  Widget _buildChatFeed(List<PersonLedgerItem> items, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // Date separator logic
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

        final dateHeaderStr = DateFormatter.isToday(item.date)
            ? 'TODAY'
            : (DateFormatter.isYesterday(item.date)
                ? 'YESTERDAY'
                : DateFormatter.formatDate(item.date).toUpperCase());

        return Column(
          children: [
            if (showDateHeader)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182229) : const Color(0xFFE1DCD3),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    dateHeaderStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark ? Colors.white60 : const Color(0xFF54656F),
                    ),
                  ),
                ),
              ),
            _buildChatBubble(item, isDark),
          ],
        );
      },
    );
  }

  Widget _buildChatBubble(PersonLedgerItem item, bool isDark) {
    // Lent by user = Outgoing (Right side, Green WhatsApp style bubble)
    // Borrowed by user = Incoming (Left side, White / Dark Grey bubble)
    final isOutgoing = item.isCreditToUser; // You gave money

    final bubbleBg = isOutgoing
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final textColor = isOutgoing
        ? (isDark ? Colors.white : const Color(0xFF111B21))
        : (isDark ? Colors.white : const Color(0xFF111B21));

    final timeColor = isOutgoing
        ? (isDark ? Colors.white60 : const Color(0xFF667781))
        : (isDark ? Colors.white54 : const Color(0xFF667781));

    final timeStr = DateFormatter.formatTime(item.date);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isOutgoing ? 12 : 2),
            bottomRight: Radius.circular(isOutgoing ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Direction Title Tag
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOutgoing ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                  size: 13,
                  color: isOutgoing
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                      : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                ),
                const SizedBox(width: 4),
                Text(
                  isOutgoing ? 'You Paid / Lent' : '${widget.personName} Paid / You Borrowed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOutgoing
                        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Big Bold Amount
            Text(
              CurrencyFormatter.formatPaise(item.amountInPaise, currencyCode: 'INR'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: textColor,
              ),
            ),

            if (item.title.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],

            if (item.note != null && item.note!.isNotEmpty && item.note != item.title) ...[
              const SizedBox(height: 2),
              Text(
                item.note!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],

            const SizedBox(height: 4),

            // Time + Blue Double Tick
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: timeColor,
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: Color(0xFF53BDEB),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomChatBar(bool isDark, PersonLedgerViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F26) : const Color(0xFFF0F2F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // YOU GAVE (LENT) Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openAddTransactionModal(isLend: true),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text(
                  'You Gave (₹)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // YOU GOT (BORROWED) Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openAddTransactionModal(isLend: false),
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: const Text(
                  'You Got (₹)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: Color(0xFF25D366),
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
                leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                title: const Text('Share Ledger Summary on WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsAppReminder(vm);
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

/// In-App Keypad Sheet for instant WhatsApp-style transaction entry.
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
  bool _isEditingNote = false;
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

    final primaryColor = isLend ? const Color(0xFF10B981) : const Color(0xFF0284C7);
    final actionTitle = isLend ? 'You Paid ${widget.personName}' : '${widget.personName} Paid You';

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

            // Amount Display Field
            GestureDetector(
              onTap: () => setState(() => _isEditingNote = false),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1014) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !_isEditingNote ? primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '₹ ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      _amountController.text.isEmpty ? '0' : _amountController.text,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Note Display / Input Trigger
            GestureDetector(
              onTap: () => setState(() => _isEditingNote = true),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1014) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEditingNote ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _noteController.text.isEmpty ? 'Add a note (e.g. Dinner, Rent, Fuel)...' : _noteController.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _noteController.text.isEmpty ? FontWeight.w400 : FontWeight.w600,
                          color: _noteController.text.isEmpty
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                    if (_isEditingNote)
                      IconButton(
                        icon: const Icon(Icons.dialpad_rounded, size: 18),
                        tooltip: 'Switch to numeric keypad',
                        onPressed: () => setState(() => _isEditingNote = false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // In-App Keypad
            if (!_isEditingNote)
              KithNumericKeypad(
                controller: _amountController,
                actionIcon: Icons.check_rounded,
                onExpressionChanged: (_) => setState(() {}),
                onDone: _handleSave,
                onNext: () => setState(() => _isEditingNote = true),
              )
            else
              KithTextKeypad(
                controller: _noteController,
                actionLabel: 'SAVE',
                onDone: _handleSave,
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
      ),
    );
  }
}
