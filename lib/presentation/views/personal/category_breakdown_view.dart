import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/expense_category.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class CategoryBreakdownView extends StatelessWidget {
  const CategoryBreakdownView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonalExpenseViewModel>();
    final totals = vm.categoryTotalsInPaise;
    final totalSpent = vm.totalSpentInPaise;

    final sortedCategories = ExpenseCategory.values.toList()
      ..sort((a, b) => (totals[b] ?? 0).compareTo(totals[a] ?? 0));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Total Spend Hero
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL SPENT IN PERIOD',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      vm.timeFilter.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emeraldPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatPaise(totalSpent, currencyCode: 'INR'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vm.filteredExpenses.length} transactions across ${sortedCategories.where((c) => (totals[c] ?? 0) > 0).length} active categories',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text('All Categories', style: AppTypography.titleMedium(isDark: isDark)),
          const SizedBox(height: AppSpacing.sm),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCategories.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, i) {
              final cat = sortedCategories[i];
              final amount = totals[cat] ?? 0;
              final count = vm.filteredExpenses.where((e) => e.category == cat).length;
              final percent = totalSpent > 0 ? ((amount / totalSpent) * 100).round() : 0;
              final isSelected = vm.selectedCategoryFilter == cat;

              return InkWell(
                onTap: () {
                  vm.setCategoryFilter(cat);
                  Navigator.pop(context);
                },
                borderRadius: AppRadius.mdBorder,
                child: SurfaceCard(
                  backgroundColor: isSelected
                      ? AppColors.emeraldPrimary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  '$count ${count == 1 ? 'transaction' : 'transactions'} ($percent%)',
                                  style: AppTypography.bodySmall(isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.formatPaise(amount, currencyCode: 'INR'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSelected ? 'Filtered' : 'Filter',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emeraldPrimary),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.emeraldPrimary),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (amount > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (percent / 100).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
