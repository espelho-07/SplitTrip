import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/models/person_ledger_item.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/person_ledger_viewmodel.dart';

/// Conversational, Chat-style Financial Relationship Timeline & Ledger for a single Person.
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

  void _showAddTransactionModal() {
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
                Text(
                  'Add with ${widget.personName}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionTile(
                  icon: Icons.arrow_outward_rounded,
                  iconColor: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                  title: 'Lend Money',
                  subtitle: 'You gave money to ${widget.personName}',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAmountSheet(isLend: true);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildActionTile(
                  icon: Icons.call_received_rounded,
                  iconColor: AppColors.emeraldPrimary,
                  title: 'Borrow Money',
                  subtitle: 'You borrowed money from ${widget.personName}',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAmountSheet(isLend: false);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildActionTile(
                  icon: Icons.receipt_long_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Split a Trip Expense',
                  subtitle: 'Add 1-on-1 expense with ${widget.personName}',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/add-expense?person=${Uri.encodeComponent(widget.personName)}');
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAmountSheet({required bool isLend}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final vm = context.read<PersonLedgerViewModel>();

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLend ? 'Lend to ' : 'Borrow from ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Amount',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Note / Reason (Optional)',
                    hintText: 'e.g. Dinner, Cab, Tickets',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLend ? AppColors.emeraldPrimary : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final parsedAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                      final paise = (parsedAmount * 100).round();
                      if (paise <= 0) return;

                      Navigator.pop(ctx);
                      if (isLend) {
                        await vm.addLendTransaction(
                          amountInPaise: paise,
                          note: noteController.text.trim(),
                        );
                      } else {
                        await vm.addBorrowTransaction(
                          amountInPaise: paise,
                          note: noteController.text.trim(),
                        );
                      }
                    },
                    child: Text(
                      isLend ? 'Save Lend' : 'Save Borrow',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(
              name: widget.personName,
              size: 32,
              showBorder: false,
            ),
            const SizedBox(width: 10),
            Text(
              widget.personName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Running Balance Sticky Hero
          _buildRunningBalanceHero(isDark, vm),

          // 2. Chat / Conversation Timeline
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (vm.items.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: vm.items.length,
                        itemBuilder: (ctx, i) {
                          final item = vm.items[i];
                          return _buildTimelineItem(item, isDark);
                        },
                      )),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionModal,
        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildRunningBalanceHero(bool isDark, PersonLedgerViewModel vm) {
    final net = vm.netBalancePaise;
    final isOwed = net > 0;
    final isYouOwe = net < 0;
    final isSettled = net == 0;

    final badgeColor = isOwed
        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
        : (isYouOwe ? Colors.orangeAccent : AppColors.emeraldPrimary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.runningBalanceStatusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSettled ? 'Even' : CurrencyFormatter.formatPaise(net.abs(), currencyCode: 'INR'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isSettled
                          ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                          : badgeColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSettled
                          ? Icons.check_circle_rounded
                          : (isOwed ? Icons.call_received_rounded : Icons.call_made_rounded),
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSettled ? 'Settled' : (isOwed ? 'To Collect' : 'To Pay'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Total Lent & Total Borrowed Sub-metrics
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Lent / Paid',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatPaise(vm.totalLentPaise, currencyCode: 'INR'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Borrowed / Received',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatPaise(vm.totalBorrowedPaise, currencyCode: 'INR'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
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

  Widget _buildTimelineItem(PersonLedgerItem item, bool isDark) {
    final isCredit = item.isCreditToUser;
    final bubbleColor = isCredit
        ? (isDark ? const Color(0xFF132A22) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF1E2630) : const Color(0xFFF1F5F9));

    final accentColor = isCredit
        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
        : (isDark ? Colors.blueAccent : Colors.indigo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isCredit ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isCredit ? 16 : 4),
              bottomRight: Radius.circular(isCredit ? 4 : 16),
            ),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: isCredit ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Direction Tag
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCredit ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                    size: 12,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.directionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Amount
              Text(
                CurrencyFormatter.formatPaise(item.amountInPaise, currencyCode: 'INR'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (item.title.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
              if (item.note != null && item.note!.isNotEmpty && item.note != item.title) ...[
                const SizedBox(height: 2),
                Text(
                  item.note!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              // Date
              Text(
                DateFormatter.formatRelative(item.date),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No financial history yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All lends, borrows, and trip splits with ${widget.personName} will appear here in a clean conversational timeline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
