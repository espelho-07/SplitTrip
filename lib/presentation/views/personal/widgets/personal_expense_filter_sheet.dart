import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/enums/expense_category.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

class PersonalExpenseFilterSheet extends StatelessWidget {
  const PersonalExpenseFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PersonalExpenseFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonalExpenseViewModel>();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: AppColors.emeraldPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Filter & Sort Expenses',
                      style: AppTypography.titleMedium(isDark: isDark),
                    ),
                  ],
                ),
                if (vm.hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      vm.resetAllFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset All', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time Period
            Text('Time Period', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PersonalTimeFilter.values.map((tf) {
                final isSelected = vm.timeFilter == tf;
                return ChoiceChip(
                  label: Text(tf.label),
                  selected: isSelected,
                  onSelected: (_) {
                    if (tf == PersonalTimeFilter.custom) {
                      Navigator.pop(context);
                      showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      ).then((range) {
                        if (range != null) {
                          vm.setCustomDateRange(range);
                        }
                      });
                    } else {
                      vm.setTimeFilter(tf);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Expense Source
            Text('Expense Source', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PersonalExpenseSourceFilter.values.map((sf) {
                final isSelected = vm.sourceFilter == sf;
                return ChoiceChip(
                  label: Text(sf.label),
                  selected: isSelected,
                  onSelected: (_) => vm.setSourceFilter(sf),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Category Filter
            Text('Category', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: vm.selectedCategoryFilter == null,
                  onSelected: (_) => vm.setCategoryFilter(null),
                ),
                ...ExpenseCategory.values.map((cat) {
                  final isSelected = vm.selectedCategoryFilter == cat;
                  return ChoiceChip(
                    avatar: Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                    label: Text(cat.displayName),
                    selected: isSelected,
                    onSelected: (_) => vm.setCategoryFilter(cat),
                  );
                }),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Sort Order
            Text('Sort Order', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PersonalExpenseSortOption.values.map((so) {
                final isSelected = vm.sortOption == so;
                return ChoiceChip(
                  label: Text(so.label),
                  selected: isSelected,
                  onSelected: (_) => vm.setSortOption(so),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            AppButton(
              text: 'Apply & View Expenses',
              icon: Icons.check_rounded,
              isFullWidth: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
