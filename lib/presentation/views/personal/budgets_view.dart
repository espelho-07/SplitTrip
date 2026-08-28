import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import 'widgets/set_budget_dialog.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class BudgetsView extends StatelessWidget {
  const BudgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final budget = personalVm.budget;

    final spentPaise = personalVm.totalSpentInPaise;
    final limitPaise = budget.monthlyLimitInPaise > 0 ? budget.monthlyLimitInPaise : 2500000;
    final progress = (spentPaise / limitPaise).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Monthly Budget', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Header
          Text('May 2024', style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
          const SizedBox(height: 8),

          // Total gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.formatPaise(spentPaise, currencyCode: 'INR')} of ${CurrencyFormatter.formatPaise(limitPaise, currencyCode: 'INR')}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF161D24) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
            ),
          ),

          const SizedBox(height: 32),

          // Categories section
          Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A))),
          const SizedBox(height: 14),

          _buildCategoryBudgetRow('🍕 Food & Drinks', 620000, 800000, 0.78, isDark),
          _buildCategoryBudgetRow('✈️ Travel', 750000, 1000000, 0.75, isDark),
          _buildCategoryBudgetRow('🛍️ Shopping', 210000, 300000, 0.70, isDark),
          _buildCategoryBudgetRow('🎯 Activities', 220000, 400000, 0.55, isDark),

          const SizedBox(height: 40),

          // Add Budget CTA
          GestureDetector(
            onTap: () {
              HapticHelper.light();
              SetBudgetDialog.show(context, currentBudgetPaise: limitPaise, monthYear: personalVm.currentMonthKey);
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('Add Budget', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetRow(String label, int spentPaise, int limitPaise, double pct, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${(pct * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF14B8A6))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF161D24) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
    );
  }
}
