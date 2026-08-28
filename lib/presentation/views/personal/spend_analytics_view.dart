import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class SpendAnalyticsView extends StatelessWidget {
  const SpendAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personalVm = context.watch<PersonalExpenseViewModel>();
    final totalSpentPaise = personalVm.totalSpentInPaise;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Total Spend Hero
          Text('Total Expenses', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                CurrencyFormatter.formatPaise(totalSpentPaise > 0 ? totalSpentPaise : 1845000, currencyCode: 'INR'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('+12% vs last month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6))),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Donut Chart Container
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF14B8A6), width: 14),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('By Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Category List
          _buildAnalyticsRow('🍕 Food & Drinks', '₹ 6,200', const Color(0xFF14B8A6), isDark),
          _buildAnalyticsRow('✈️ Travel', '₹ 7,500', const Color(0xFF06B6D4), isDark),
          _buildAnalyticsRow('🛍️ Shopping', '₹ 2,100', const Color(0xFFF59E0B), isDark),
          _buildAnalyticsRow('🎯 Activities', '₹ 2,200', const Color(0xFF8B5CF6), isDark),
          _buildAnalyticsRow('📦 Others', '₹ 450', const Color(0xFF64748B), isDark),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String title, String amount, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
