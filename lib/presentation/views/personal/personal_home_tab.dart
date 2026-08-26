import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_amount_display.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../domain/models/personal_debt.dart';
import '../../../domain/models/personal_expense.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import 'widgets/add_personal_expense_sheet.dart';
import 'widgets/personal_expense_detail_sheet.dart';
import 'widgets/personal_expense_filter_sheet.dart';
import 'widgets/record_repayment_sheet.dart';
import 'widgets/set_budget_dialog.dart';

class PersonalHomeTab extends StatelessWidget {
  const PersonalHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;

    final totalSpentPaise = personalVm.totalSpentInPaise;
    final avgPerDayPaise = personalVm.averageSpentPerDayInPaise;
    final expenses = personalVm.filteredExpenses;
    final debtsSummary = personalVm.debtsSummary;
    final budget = personalVm.budget;

    // Determine one single high-priority contextual insight
    String? insightText;
    IconData? insightIcon;
    Color? insightColor;
    VoidCallback? insightTap;

    final uncollected = debtsSummary.debts
        .where((d) => d.debtType == PersonalDebtType.lent && !d.isSettled)
        .firstOrNull;
    final unpayed = debtsSummary.debts
        .where((d) => d.debtType == PersonalDebtType.borrowed && !d.isSettled)
        .firstOrNull;

    if (uncollected != null) {
      insightText = '${uncollected.personName} · ${CurrencyFormatter.formatPaise(uncollected.remainingAmountInPaise, currencyCode: 'INR')} (${l10n.personalYouAreOwed})';
      insightIcon = Icons.arrow_downward_rounded;
      insightColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      insightTap = () => RecordRepaymentSheet.show(context, debt: uncollected);
    } else if (unpayed != null) {
      insightText = '${unpayed.personName} · ${CurrencyFormatter.formatPaise(unpayed.remainingAmountInPaise, currencyCode: 'INR')} (${l10n.personalYouOwe})';
      insightIcon = Icons.arrow_upward_rounded;
      insightColor = AppColors.emeraldPrimary;
      insightTap = () => RecordRepaymentSheet.show(context, debt: unpayed);
    } else if (budget.hasBudget && budget.monthlyLimitInPaise > 0) {
      if (budget.remainingInPaise < 0) {
        insightText = '${CurrencyFormatter.formatPaise(budget.remainingInPaise.abs(), currencyCode: 'INR')} ${l10n.personalOverBudgetBy}';
        insightIcon = Icons.warning_amber_rounded;
        insightColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      } else {
        insightText = '${CurrencyFormatter.formatPaise(budget.remainingInPaise, currencyCode: 'INR')} ${l10n.personalRemainingLabel}';
        insightIcon = Icons.pie_chart_outline_rounded;
        insightColor = AppColors.emeraldPrimary;
      }
      insightTap = () => SetBudgetDialog.show(
            context,
            currentBudgetPaise: budget.monthlyLimitInPaise,
            monthYear: personalVm.currentMonthKey,
          );
    } else if (avgPerDayPaise > 0) {
      insightText = '${CurrencyFormatter.formatPaise(avgPerDayPaise, currencyCode: 'INR')} / ${l10n.personalDailyAverage.toLowerCase()}';
      insightIcon = Icons.trending_up_rounded;
      insightColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    final monthFormat = DateFormat('MMMM yyyy');
    final formattedMonth = monthFormat.format(personalVm.selectedMonth);

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
          // 1. Typography-First Hero Spending Display
          KithAmountDisplay(
            amountInPaise: totalSpentPaise,
            periodSubtitle: formattedMonth,
            contextualInsight: insightText,
            insightIcon: insightIcon,
            insightColor: insightColor,
            onInsightTap: insightTap,
            budgetProgress: (budget.hasBudget && budget.monthlyLimitInPaise > 0)
                ? (budget.percentageUsed / 100.0)
                : null,
            onPeriodTap: () => _showMonthPicker(context, personalVm),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 2. Compact Navigation Pills (Lending & Debts, Categories, Budget)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                KithChip(
                  label: debtsSummary.debts.isNotEmpty
                      ? '${l10n.personalDebtsTitle} (${debtsSummary.debts.length})'
                      : l10n.personalDebtsTitle,
                  isSelected: false,
                  icon: Icons.swap_horiz_rounded,
                  onTap: () => context.push('/personal/debts'),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (expenses.isNotEmpty) ...[
                  KithChip(
                    label: l10n.categoryTitle,
                    isSelected: false,
                    icon: Icons.category_outlined,
                    onTap: () => context.push('/personal/categories'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                KithChip(
                  label: budget.hasBudget
                      ? '${l10n.personalBudget}: ${CurrencyFormatter.formatPaise(budget.monthlyLimitInPaise, currencyCode: 'INR')}'
                      : l10n.personalBudgetSet,
                  isSelected: false,
                  icon: Icons.tune_rounded,
                  onTap: () => SetBudgetDialog.show(
                    context,
                    currentBudgetPaise: budget.monthlyLimitInPaise,
                    monthYear: personalVm.currentMonthKey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // 3. Section Header & Quick Search/Filter
          KithSectionHeader(
            title: l10n.personalSecExpenses,
            actionLabel: expenses.isNotEmpty ? l10n.personalFilter : null,
            onAction: expenses.isNotEmpty ? () => PersonalExpenseFilterSheet.show(context) : null,
          ),

          const SizedBox(height: AppSpacing.sm),

          // 4. Expenses List or Empty State
          if (expenses.isEmpty)
            KithEmptyState(
              title: l10n.personalEmptyTitle,
              subtitle: l10n.personalEmptySub,
              icon: Icons.receipt_long_outlined,
              actionLabel: l10n.personalAddExpense,
              onAction: () => AddPersonalExpenseSheet.show(context),
            )
          else
            ...expenses.map((e) => _buildExpenseTile(context, e, isDark)),

          const SizedBox(height: 80), // Bottom breathing room for FAB
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context, PersonalExpenseViewModel vm) {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceCard
          : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Period',
                      style: AppTypography.titleMedium(
                        isDark: Theme.of(ctx).brightness == Brightness.dark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.emeraldPrimary),
                  title: const Text('This Month'),
                  onTap: () {
                    vm.setTimeFilter(PersonalTimeFilter.thisMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chevron_left_rounded),
                  title: const Text('Previous Month'),
                  onTap: () {
                    vm.previousMonth();
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range_rounded),
                  title: const Text('Custom Date Range'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: DateTimeRange(
                        start: DateTime(now.year, now.month, 1),
                        end: now,
                      ),
                    );
                    if (picked != null) {
                      vm.setCustomDateRange(picked);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(BuildContext context, PersonalExpense expense, bool isDark) {
    final l10n = context.l10n;
    final dateStr = DateFormatter.isToday(expense.date)
        ? l10n.translate('filter_today')
        : DateFormatter.formatDate(expense.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            PersonalExpenseDetailSheet.show(context, expense: expense);
          },
          borderRadius: AppRadius.mdBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: expense.category.color.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    expense.category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$dateStr · ${expense.category.localizedName(l10n)}',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                          if (expense.id.startsWith('trip_') || (expense.notes?.contains('Trip Spend') ?? false)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.indigoAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.tabTrips,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.indigoAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  CurrencyFormatter.formatPaise(expense.amountInPaise, currencyCode: 'INR'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
}
