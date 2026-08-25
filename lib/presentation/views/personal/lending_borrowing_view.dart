import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/models/personal_debt.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import 'widgets/add_personal_expense_sheet.dart';
import 'widgets/record_repayment_sheet.dart';

enum DebtFilterType { all, lent, borrowed, settled }

class LendingBorrowingView extends StatefulWidget {
  const LendingBorrowingView({super.key});

  @override
  State<LendingBorrowingView> createState() => _LendingBorrowingViewState();
}

class _LendingBorrowingViewState extends State<LendingBorrowingView> {
  DebtFilterType _filter = DebtFilterType.all;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonalExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final summary = vm.debtsSummary;
    final allDebts = summary.debts;

    final filtered = allDebts.where((d) {
      if (_filter == DebtFilterType.lent && (d.debtType != PersonalDebtType.lent || d.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.borrowed && (d.debtType != PersonalDebtType.borrowed || d.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.settled && (!d.isSettled && d.remainingAmountInPaise > 0)) {
        return false;
      }
      if (_search.trim().isNotEmpty) {
        final query = _search.trim().toLowerCase();
        final matchPerson = d.personName.toLowerCase().contains(query);
        final matchNote = d.description?.toLowerCase().contains(query) ?? false;
        if (!matchPerson && !matchNote) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Lending & Borrowing', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
            tooltip: 'Add Loan / Borrow',
            onPressed: () {
              AddPersonalExpenseSheet.show(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = authVm.currentUser;
          if (user != null) {
            await vm.loadData(user.id);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Summary Hero Card
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      // To Collect (Lent)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Collect',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(summary.totalLentPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      const SizedBox(width: 16),
                      // To Pay (Borrowed)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Pay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(summary.totalBorrowedPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Balance Position',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      Text(
                        '${summary.netBalancePaise >= 0 ? '+' : ''}${CurrencyFormatter.formatPaise(summary.netBalancePaise, currencyCode: 'INR')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: summary.netBalancePaise >= 0
                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                              : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Search input
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: 'Search by person or note...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All ()'),
                    selected: _filter == DebtFilterType.all,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.all),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Lent ()'),
                    selected: _filter == DebtFilterType.lent,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.lent),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Borrowed ()'),
                    selected: _filter == DebtFilterType.borrowed,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.borrowed),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Settled ()'),
                    selected: _filter == DebtFilterType.settled,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.settled),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: EmptyStateView(
                  emoji: '🤝',
                  title: 'No debt records found',
                  subtitle: _search.isNotEmpty
                      ? 'No lending or borrowing records matched "".'
                      : 'You do not have any records in this category.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (ctx, i) {
                  final d = filtered[i];
                  final isLent = d.debtType == PersonalDebtType.lent;
                  final isSettled = d.isSettled || d.remainingAmountInPaise <= 0;
                  final repaidAmount = d.initialAmountInPaise - d.remainingAmountInPaise;
                  final progress = (d.initialAmountInPaise > 0
                          ? (repaidAmount / d.initialAmountInPaise)
                          : 1.0)
                      .clamp(0.0, 1.0);

                  return SurfaceCard(
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isLent
                                            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                            : AppColors.emeraldPrimary)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isLent ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: isLent
                                        ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                        : AppColors.emeraldPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.personName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      isLent ? 'Lent by you' : 'Borrowed by you',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isLent
                                            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                            : AppColors.emeraldPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isSettled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 12, color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Paid',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.formatPaise(d.remainingAmountInPaise, currencyCode: 'INR'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    'of ${CurrencyFormatter.formatPaise(d.initialAmountInPaise, currencyCode: 'INR')}',
                                    style: AppTypography.bodySmall(isDark: isDark),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        if (d.description != null && d.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            d.description!,
                            style: AppTypography.bodyMedium(isDark: isDark),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Repayment progress
                        if (!isSettled && repaidAmount > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(progress * 100).round()}% repaid (${CurrencyFormatter.formatPaise(repaidAmount, currencyCode: 'INR')})',
                            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(height: 8),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormatter.formatRelative(d.createdAt),
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            Row(
                              children: [
                                if (!isSettled)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.emeraldPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 14),
                                    label: const Text('Mark Paid / Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    onPressed: () {
                                      RecordRepaymentSheet.show(context, debt: d);
                                    },
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                  tooltip: 'Delete Record',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('Delete Record'),
                                        content: Text('Are you sure you want to delete the debt record for "${d.personName}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text('Deleted debt record for "${d.personName}"')),
                                            ],
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      vm.deleteDebt(d.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
