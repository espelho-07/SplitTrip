import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/currency_display.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/expense_category.dart';
import '../../../domain/models/personal_debt.dart';
import '../../../domain/models/personal_expense.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import 'widgets/add_personal_expense_sheet.dart';
import 'widgets/personal_expense_detail_sheet.dart';
import 'widgets/personal_expense_filter_sheet.dart';
import 'widgets/record_repayment_sheet.dart';
import 'widgets/set_budget_dialog.dart';
import 'widgets/trip_sync_progress_sheet.dart';

class PersonalHomeTab extends StatelessWidget {
  const PersonalHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();

    final totalSpentPaise = personalVm.totalSpentInPaise;
    final avgPerDayPaise = personalVm.averageSpentPerDayInPaise;
    final expenses = personalVm.filteredExpenses;
    final debtsSummary = personalVm.debtsSummary;
    final budget = personalVm.budget;

    return RefreshIndicator(
      onRefresh: () async {
        final user = authVm.currentUser;
        if (user != null) {
          await personalVm.loadData(user.id);
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // 1. Month Navigation Header & Period Filter Chips
          _buildPeriodSelector(context, personalVm, isDark),
          const SizedBox(height: AppSpacing.md),

          // 2. Hero Spend Card
          _buildHeroSpendCard(context, personalVm, isDark, totalSpentPaise, avgPerDayPaise, budget),
          const SizedBox(height: AppSpacing.md),

          // 3. Smart Contextual Next Action (At most ONE most relevant item)
          _buildSmartNextAction(context, personalVm, isDark, debtsSummary, budget, expenses),
          const SizedBox(height: AppSpacing.md),

          // 4. Lending & Borrowing Section ("Who owes me / Who I owe")
          if (debtsSummary.debts.isNotEmpty) ...[
            _buildLendingBorrowingSection(context, personalVm, isDark, debtsSummary),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 5. Category Breakdown Section
          if (expenses.isNotEmpty) ...[
            _buildCategoryBreakdown(context, personalVm, isDark),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 6. Recent Activity / Expenses List Header & Search Filter Bar
          _buildExpenseSearchAndFilters(context, personalVm, isDark, expenses.length),
          const SizedBox(height: AppSpacing.sm),

          // Expenses List or Empty State
          if (expenses.isEmpty)
            _buildEmptyState(context, isDark)
          else
            ...expenses.map((e) => _buildExpenseTile(context, e, isDark)),

          const SizedBox(height: 80), // Bottom padding for FAB and Nav
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
  ) {
    final monthFormat = DateFormat('MMMM yyyy');
    final formattedMonth = monthFormat.format(vm.selectedMonth);

    return Column(
      children: [
        // Month Navigation Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              onPressed: vm.previousMonth,
              tooltip: 'Previous month',
            ),
            Text(
              formattedMonth,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 28),
              onPressed: vm.nextMonth,
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PersonalTimeFilter.values.map((filter) {
              final isSelected = vm.timeFilter == filter;
              String chipLabel = filter.label;
              if (filter == PersonalTimeFilter.custom && vm.customDateRange != null && isSelected) {
                final startStr = DateFormat('d MMM').format(vm.customDateRange!.start);
                final endStr = DateFormat('d MMM').format(vm.customDateRange!.end);
                chipLabel = 'Custom: $startStr - $endStr';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(chipLabel),
                  selected: isSelected,
                  onSelected: (_) async {
                    if (filter == PersonalTimeFilter.custom) {
                      final now = DateTime.now();
                      final initialRange = vm.customDateRange ?? DateTimeRange(
                        start: DateTime(now.year, now.month, 1),
                        end: now,
                      );
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: initialRange,
                        builder: (ctx, child) {
                          return Theme(
                            data: isDark
                                ? ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppColors.emeraldPrimary,
                                      onPrimary: Colors.white,
                                      surface: AppColors.darkSurfaceCard,
                                      onSurface: Colors.white,
                                    ),
                                  )
                                : ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.emeraldPrimary,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        vm.setCustomDateRange(picked);
                      }
                    } else {
                      vm.setTimeFilter(filter);
                    }
                  },
                  selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.emeraldPrimary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.emeraldPrimary)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSpendCard(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
    int totalSpentPaise,
    int avgPerDayPaise,
    dynamic budget,
  ) {
    final statusRed = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;

    return SurfaceCard(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SPENT ${vm.timeFilter.label.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  SetBudgetDialog.show(
                    context,
                    currentBudgetPaise: budget.monthlyLimitInPaise,
                    monthYear: vm.currentMonthKey,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        budget.hasBudget
                            ? Icons.tune_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 14,
                        color: AppColors.emeraldPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        budget.hasBudget
                            ? 'Budget: ${CurrencyFormatter.formatPaise(budget.monthlyLimitInPaise, currencyCode: 'INR')}'
                            : 'Set Budget',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CurrencyDisplay(
            amountInPaise: totalSpentPaise,
            size: CurrencyDisplaySize.hero,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avgPerDayPaise > 0
                          ? '${CurrencyFormatter.formatPaise(avgPerDayPaise, currencyCode: 'INR')} / day avg'
                          : 'No spending recorded',
                      style: AppTypography.bodySmall(isDark: isDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (vm.includeTripExpenses) ...[
                      const SizedBox(height: 2),
                      const Text(
                        '✓ Trip spends included',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final user = context.read<AuthViewModel>().currentUser;
                  if (user != null) {
                    if (!vm.includeTripExpenses) {
                      TripSyncProgressSheet.show(context);
                      vm.toggleIncludeTripExpenses(user.id);
                    } else {
                      vm.toggleIncludeTripExpenses(user.id);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: vm.includeTripExpenses
                        ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: vm.includeTripExpenses
                          ? AppColors.emeraldPrimary.withValues(alpha: 0.5)
                          : (isDark ? Colors.white24 : Colors.black12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vm.isSyncingTrips) ...[
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Syncing ${(vm.syncProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.sync_alt_rounded,
                          size: 13,
                          color: vm.includeTripExpenses
                              ? AppColors.emeraldPrimary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          vm.includeTripExpenses ? 'Trips Synced' : 'Sync from Trips',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: vm.includeTripExpenses
                                ? AppColors.emeraldPrimary
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (budget.hasBudget && budget.monthlyLimitInPaise > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (budget.percentageUsed / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                color: budget.percentageUsed > 90
                    ? statusRed
                    : (budget.percentageUsed > 70 ? AppColors.amberAccent : AppColors.emeraldPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${budget.percentageUsed}% of monthly budget',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: budget.percentageUsed > 90
                        ? statusRed
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
                Text(
                  budget.remainingInPaise < 0
                      ? '${CurrencyFormatter.formatPaise(budget.remainingInPaise.abs(), currencyCode: 'INR')} over budget'
                      : '${CurrencyFormatter.formatPaise(budget.remainingInPaise, currencyCode: 'INR')} left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: budget.remainingInPaise < 0
                        ? statusRed
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Displays at most ONE relevant contextual action. Completely silent if nothing requires action.
  Widget _buildSmartNextAction(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
    PersonalDebtsSummary debtsSummary,
    dynamic budget,
    List<PersonalExpense> expenses,
  ) {
    // 1. Outstanding money owed to you
    final uncollected = debtsSummary.debts
        .where((d) => d.debtType == PersonalDebtType.lent && !d.isSettled)
        .firstOrNull;

    if (uncollected != null) {
      final green = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: green.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_downward_rounded, size: 18, color: green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${uncollected.personName} owes you ${CurrencyFormatter.formatPaise(uncollected.remainingAmountInPaise, currencyCode: 'INR')}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: green),
              ),
            ),
            TextButton(
              onPressed: () => RecordRepaymentSheet.show(context, debt: uncollected),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text('Settle', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
            ),
          ],
        ),
      );
    }

    // 2. Outstanding money you owe
    final unpayed = debtsSummary.debts
        .where((d) => d.debtType == PersonalDebtType.borrowed && !d.isSettled)
        .firstOrNull;

    if (unpayed != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.emeraldPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You owe ${unpayed.personName} ${CurrencyFormatter.formatPaise(unpayed.remainingAmountInPaise, currencyCode: 'INR')}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emeraldPrimary),
              ),
            ),
            TextButton(
              onPressed: () => RecordRepaymentSheet.show(context, debt: unpayed),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Repay', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
            ),
          ],
        ),
      );
    }

    // 3. Budget nearing limit warning (>85%)
    if (budget.hasBudget && budget.percentageUsed >= 85) {
      final statusRed = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: statusRed.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: statusRed.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: statusRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                budget.remainingInPaise < 0
                    ? '${CurrencyFormatter.formatPaise(budget.remainingInPaise.abs(), currencyCode: 'INR')} over budget this month (${budget.percentageUsed}% spent)'
                    : '${CurrencyFormatter.formatPaise(budget.remainingInPaise, currencyCode: 'INR')} left this month (${budget.percentageUsed}% spent)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusRed),
              ),
            ),
            TextButton(
              onPressed: () {
                SetBudgetDialog.show(
                  context,
                  currentBudgetPaise: budget.monthlyLimitInPaise,
                  monthYear: vm.currentMonthKey,
                );
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text('Budget', style: TextStyle(fontWeight: FontWeight.w700, color: statusRed)),
            ),
          ],
        ),
      );
    }

    // No active alerts: Return nothing to keep UI uncluttered
    return const SizedBox.shrink();
  }

  Widget _buildLendingBorrowingSection(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
    PersonalDebtsSummary summary,
  ) {
    final lentDebts = summary.debts.where((d) => d.debtType == PersonalDebtType.lent).toList();
    final borrowedDebts = summary.debts.where((d) => d.debtType == PersonalDebtType.borrowed).toList();
    final green = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lending & Borrowing', style: AppTypography.titleMedium(isDark: isDark)),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.push('/personal/debts'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.emeraldPrimary),
              label: Text(
                'View Detailed (${summary.debts.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // You're Owed
        if (lentDebts.isNotEmpty) ...[
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 16, color: green),
                        const SizedBox(width: 6),
                        Text(
                          "YOU'RE OWED",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: green,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(summary.totalLentPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                ...lentDebts.take(2).map((d) => _buildDebtItem(context, d, isDark)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // You Owe
        if (borrowedDebts.isNotEmpty) ...[
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.emeraldPrimary),
                        const SizedBox(width: 6),
                        const Text(
                          "YOU OWE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(summary.totalBorrowedPaise, currencyCode: 'INR'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                ...borrowedDebts.take(2).map((d) => _buildDebtItem(context, d, isDark)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDebtItem(BuildContext context, PersonalDebt debt, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
            child: Text(
              debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.personName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                if (debt.description != null && debt.description!.isNotEmpty)
                  Text(
                    debt.description!,
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPaise(debt.remainingAmountInPaise, currencyCode: 'INR'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              if (debt.isSettled || debt.remainingAmountInPaise <= 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 11,
                        color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    RecordRepaymentSheet.show(context, debt: debt);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
  ) {
    final totals = vm.categoryTotalsInPaise;
    final totalSpent = vm.totalSpentInPaise;
    if (totals.isEmpty || totalSpent == 0) return const SizedBox.shrink();

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Category Breakdown', style: AppTypography.titleMedium(isDark: isDark)),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.push('/personal/categories'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.emeraldPrimary),
              label: const Text(
                'View Detailed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SurfaceCard(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: sortedEntries.take(4).map((entry) {
              final cat = entry.key;
              final amount = entry.value;
              final percentage = ((amount / totalSpent) * 100).round();
              final isSelected = vm.selectedCategoryFilter == cat;

              return InkWell(
                onTap: () => vm.setCategoryFilter(cat),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  cat.displayName,
                                  style: AppTypography.titleSmall(isDark: isDark),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Filtered', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(amount, currencyCode: 'INR'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          color: cat.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSearchAndFilters(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
    int expenseCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: TextField(
                  onChanged: vm.setSearchQuery,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search expenses, merchant, notes...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34),
                    suffixIcon: vm.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () => vm.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => PersonalExpenseFilterSheet.show(context),
              borderRadius: AppRadius.mdBorder,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: vm.hasActiveFilters
                      ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                      : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(
                    color: vm.hasActiveFilters
                        ? AppColors.emeraldPrimary
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: vm.hasActiveFilters
                          ? AppColors.emeraldPrimary
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: vm.hasActiveFilters
                            ? AppColors.emeraldPrimary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    if (vm.hasActiveFilters) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.emeraldPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Category Horizontal Quick-Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All', style: TextStyle(fontSize: 12)),
                selected: vm.selectedCategoryFilter == null,
                onSelected: (_) => vm.setCategoryFilter(null),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ...ExpenseCategory.values.map((cat) {
                final isSelected = vm.selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                    label: Text(cat.displayName, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (_) => vm.setCategoryFilter(cat),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
        ),

        if (vm.hasActiveFilters) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Filters active (${vm.filteredExpenses.length} results)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emeraldPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: vm.resetAllFilters,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expenses',
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            Text(
              '$expenseCount total',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseTile(BuildContext context, PersonalExpense expense, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PersonalExpenseDetailSheet.show(context, expense: expense);
          },
          borderRadius: AppRadius.mdBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: expense.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    expense.category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.isToday(expense.date)
                            ? 'Today'
                            : DateFormatter.formatDate(expense.date),
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatPaise(expense.amountInPaise, currencyCode: 'INR'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.emeraldPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No expenses yet',
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your spending and lending will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Add Expense',
              icon: Icons.add_rounded,
              onPressed: () {
                AddPersonalExpenseSheet.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
