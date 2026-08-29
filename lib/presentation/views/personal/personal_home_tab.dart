import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
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

/// Redesigned Master Kith Expenses Page.
/// Clean, premium, typography-first, fast and intuitive.
class PersonalHomeTab extends StatefulWidget {
  const PersonalHomeTab({super.key});

  @override
  State<PersonalHomeTab> createState() => _PersonalHomeTabState();
}

class _PersonalHomeTabState extends State<PersonalHomeTab> {
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;
    final user = authVm.currentUser;

    final totalSpentPaise = personalVm.totalSpentInPaise;
    final avgPerDayPaise = personalVm.averageSpentPerDayInPaise;
    var expenses = personalVm.filteredExpenses;
    final debtsSummary = personalVm.debtsSummary;
    final budget = personalVm.budget;

    // Apply inline search filter if active
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      expenses = expenses.where((e) {
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchNotes = e.notes?.toLowerCase().contains(q) ?? false;
        final matchCat = e.category.localizedName(l10n).toLowerCase().contains(q);
        return matchTitle || matchNotes || matchCat;
      }).toList();
    }

    // Determine one high-priority contextual debt/budget insight
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
      insightText = '${uncollected.personName} owes you ${CurrencyFormatter.formatPaise(uncollected.remainingAmountInPaise, currencyCode: 'INR')}';
      insightIcon = Icons.arrow_downward_rounded;
      insightColor = isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight;
      insightTap = () => RecordRepaymentSheet.show(context, debt: uncollected);
    } else if (unpayed != null) {
      insightText = 'You owe ${unpayed.personName} ${CurrencyFormatter.formatPaise(unpayed.remainingAmountInPaise, currencyCode: 'INR')}';
      insightIcon = Icons.arrow_upward_rounded;
      insightColor = AppColors.emeraldPrimary;
      insightTap = () => RecordRepaymentSheet.show(context, debt: unpayed);
    } else if (budget.hasBudget && budget.monthlyLimitInPaise > 0) {
      if (budget.remainingInPaise < 0) {
        insightText = '${CurrencyFormatter.formatPaise(budget.remainingInPaise.abs(), currencyCode: 'INR')} over budget';
        insightIcon = Icons.warning_amber_rounded;
        insightColor = isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight;
      } else {
        insightText = '${CurrencyFormatter.formatPaise(budget.remainingInPaise, currencyCode: 'INR')} remaining in budget';
        insightIcon = Icons.pie_chart_outline_rounded;
        insightColor = AppColors.emeraldPrimary;
      }
      insightTap = () => SetBudgetDialog.show(
            context,
            currentBudgetPaise: budget.monthlyLimitInPaise,
            monthYear: personalVm.currentMonthKey,
          );
    } else if (avgPerDayPaise > 0) {
      insightText = '${CurrencyFormatter.formatPaise(avgPerDayPaise, currencyCode: 'INR')} / day average';
      insightIcon = Icons.trending_up_rounded;
      insightColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    }

    final monthFormat = DateFormat('MMMM yyyy');
    final formattedMonth = monthFormat.format(personalVm.selectedMonth);

    // Group expenses by day
    final groupedExpenses = <String, List<PersonalExpense>>{};
    for (final exp in expenses) {
      final key = DateFormatter.isToday(exp.date)
          ? 'Today'
          : (DateFormatter.isYesterday(exp.date)
              ? 'Yesterday'
              : DateFormat('dd MMM yyyy').format(exp.date));
      groupedExpenses.putIfAbsent(key, () => []).add(exp);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticHelper.light();
          AddPersonalExpenseSheet.show(context);
        },
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) {
            await personalVm.loadData(user.id);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // 1. Top Bar: [ Expenses ]      [ + Add ] [ 🔍 ]
            _buildTopBar(context, isDark, personalVm),

            if (_isSearchOpen) ...[
              const SizedBox(height: 12),
              _buildSearchBar(isDark),
            ],

            const SizedBox(height: 20),

            // 2. Hero Spending Card (Monthly summary + budget + quick pill links)
            _buildSpendingHeroCard(
              context: context,
              totalSpentPaise: totalSpentPaise,
              formattedMonth: formattedMonth,
              budget: budget,
              debtsSummary: debtsSummary,
              insightText: insightText,
              insightIcon: insightIcon,
              insightColor: insightColor,
              insightTap: insightTap,
              personalVm: personalVm,
              isDark: isDark,
              l10n: l10n,
            ),

            const SizedBox(height: 20),

            // 3. Category & Filter Pills Bar
            _buildFilterChipsRow(context, personalVm, isDark, l10n),

            const SizedBox(height: 24),

            // 4. Section Header: RECENT EXPENSES
            _buildSectionHeader(
              title: 'RECENT EXPENSES',
              count: expenses.length,
              isDark: isDark,
              personalVm: personalVm,
            ),

            const SizedBox(height: 12),

            // 5. Grouped Chronological Expense Feed or Empty States
            if (expenses.isEmpty)
              _buildEmptyState(context, isDark, personalVm.hasActiveFilters || _searchQuery.isNotEmpty)
            else
              ...groupedExpenses.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F1418) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: entry.value.asMap().entries.map((item) {
                          final idx = item.key;
                          final expense = item.value;
                          final isLast = idx == entry.value.length - 1;
                          return _buildExpenseTile(context, expense, isDark, isLast, l10n, personalVm);
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, PersonalExpenseViewModel personalVm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Personal spends, categories & budget',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Search Toggle Button
            GestureDetector(
              onTap: () {
                HapticHelper.selection();
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSearchOpen
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9)),
                  border: Border.all(
                    color: _isSearchOpen
                        ? const Color(0xFF14B8A6)
                        : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                  size: 19,
                  color: _isSearchOpen
                      ? const Color(0xFF14B8A6)
                      : (isDark ? AppColors.darkTextPrimary : const Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // + Add Expense Button
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                AddPersonalExpenseSheet.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: KithInputDecoration.borderless(
          hintText: 'Search by title, notes, or category…',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF14B8A6)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSpendingHeroCard({
    required BuildContext context,
    required int totalSpentPaise,
    required String formattedMonth,
    required dynamic budget,
    required dynamic debtsSummary,
    required String? insightText,
    required IconData? insightIcon,
    required Color? insightColor,
    required VoidCallback? insightTap,
    required PersonalExpenseViewModel personalVm,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH\'S SPEND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () => _showMonthPicker(context, personalVm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        formattedMonth,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Total Spent Typography Hero
          Text(
            CurrencyFormatter.formatPaise(totalSpentPaise, currencyCode: 'INR'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),

          if (insightText != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: insightTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (insightIcon != null) ...[
                    Icon(insightIcon, size: 14, color: insightColor ?? const Color(0xFF14B8A6)),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      insightText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: insightColor ?? (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Budget Progress Bar if budget is active
          if (budget.hasBudget && budget.monthlyLimitInPaise > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (budget.percentageUsed / 100.0).clamp(0.0, 1.0),
                backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  budget.remainingInPaise < 0
                      ? const Color(0xFFEF4444)
                      : (budget.percentageUsed > 80 ? const Color(0xFFF59E0B) : const Color(0xFF14B8A6)),
                ),
                minHeight: 5,
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0x14000000)),
          const SizedBox(height: 14),

          // 3 Quick Navigation Analytics Pills
          Row(
            children: [
              Expanded(
                child: _buildHeroPill(
                  icon: Icons.swap_horiz_rounded,
                  label: debtsSummary.debts.isNotEmpty
                      ? 'Lending (${debtsSummary.debts.length})'
                      : 'Lending',
                  isDark: isDark,
                  onTap: () => context.push('/personal/debts'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeroPill(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Categories',
                  isDark: isDark,
                  onTap: () => context.push('/personal/categories'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeroPill(
                  icon: Icons.tune_rounded,
                  label: budget.hasBudget ? 'Budget' : 'Set Budget',
                  isDark: isDark,
                  onTap: () => SetBudgetDialog.show(
                    context,
                    currentBudgetPaise: budget.monthlyLimitInPaise,
                    monthYear: personalVm.currentMonthKey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF14B8A6)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow(
    BuildContext context,
    PersonalExpenseViewModel vm,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All Chip
          _buildFilterChip(
            label: 'All',
            isSelected: vm.selectedCategoryFilter == null,
            isDark: isDark,
            onTap: () => vm.setCategoryFilter(null),
          ),
          const SizedBox(width: 8),

          // Categories Chips
          ...ExpenseCategory.values.map((cat) {
            final isSelected = vm.selectedCategoryFilter == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildFilterChip(
                label: '${cat.emoji} ${cat.localizedName(l10n)}',
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => vm.setCategoryFilter(isSelected ? null : cat),
              ),
            );
          }),

          // Advanced Filter Button
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              PersonalExpenseFilterSheet.show(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: vm.hasActiveFilters
                    ? const Color(0xFF14B8A6).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: vm.hasActiveFilters
                      ? const Color(0xFF14B8A6)
                      : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: vm.hasActiveFilters
                        ? const Color(0xFF14B8A6)
                        : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'More Filters',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: vm.hasActiveFilters
                          ? const Color(0xFF14B8A6)
                          : (isDark ? AppColors.darkTextPrimary : const Color(0xFF334155)),
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF14B8A6)
              : (isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF14B8A6)
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int? count,
    required bool isDark,
    required PersonalExpenseViewModel personalVm,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
              ),
            ),
          ),
        ],
        const Spacer(),
        if (personalVm.hasActiveFilters || _searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () {
              HapticHelper.selection();
              personalVm.resetAllFilters();
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
            child: const Text(
              'Clear Filter',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
            ),
          ),
      ],
    );
  }

  Widget _buildExpenseTile(
    BuildContext context,
    PersonalExpense expense,
    bool isDark,
    bool isLast,
    AppLocalizations l10n,
    PersonalExpenseViewModel personalVm,
  ) {
    final timeStr = DateFormat('h:mm a').format(expense.date);

    return InkWell(
      onTap: () {
        HapticHelper.light();
        PersonalExpenseDetailSheet.show(context, expense: expense);
      },
      borderRadius: BorderRadius.vertical(
        top: isLast ? Radius.zero : const Radius.circular(20),
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            // Category Icon Emoji Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: expense.category.color.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(expense.category.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),

            // Title & Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '$timeStr • ${expense.category.localizedName(l10n)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                      if (expense.id.startsWith('trip_') || (expense.notes?.contains('Trip Spend') ?? false)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Trip',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF14B8A6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount Display
            Text(
              CurrencyFormatter.formatPaise(expense.amountInPaise, currencyCode: 'INR'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool isFiltered) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
            ),
            alignment: Alignment.center,
            child: Icon(
              isFiltered ? Icons.search_off_rounded : Icons.receipt_long_outlined,
              size: 26,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered ? 'No matching expenses' : 'No expenses logged yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFiltered
                ? 'Try adjusting your search query or active filter chips'
                : 'Log personal purchases, meals and daily bills easily',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              if (isFiltered) {
                context.read<PersonalExpenseViewModel>().resetAllFilters();
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              } else {
                AddPersonalExpenseSheet.show(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isFiltered ? 'Reset Filters' : '+ Add First Expense',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
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
}
