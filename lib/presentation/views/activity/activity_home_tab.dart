import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

class ActivityHomeTab extends StatefulWidget {
  const ActivityHomeTab({super.key});

  @override
  State<ActivityHomeTab> createState() => _ActivityHomeTabState();
}

class _ActivityHomeTabState extends State<ActivityHomeTab> {
  String _selectedFilter = 'All'; // 'All', 'Expenses', 'Settlements'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeVm = context.watch<HomeViewModel>();
    final personalVm = context.watch<PersonalExpenseViewModel>();

    final personalExpenses = personalVm.expenses;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      children: [
        // Top Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Activity',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Activity')),
                    DropdownMenuItem(value: 'Expenses', child: Text('Expenses')),
                    DropdownMenuItem(value: 'Settlements', child: Text('Settlements')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      HapticHelper.selection();
                      setState(() => _selectedFilter = v);
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (personalExpenses.isEmpty && homeVm.trips.isEmpty)
          _buildEmptyActivityState(isDark)
        else ...[
          // Sample chronological activities
          _buildActivityItem(
            avatarName: 'Darpan',
            actionText: 'added an expense',
            itemTitle: 'Lunch at Cafe 🍕',
            amountPaise: 95000,
            timestamp: 'Today, 1:30 PM',
            isPositive: false,
            isDark: isDark,
          ),
          _buildActivityItem(
            avatarName: 'Priya',
            actionText: 'added an expense',
            itemTitle: 'Scooter Rental 🛵',
            amountPaise: 60000,
            timestamp: 'Today, 11:20 AM',
            isPositive: false,
            isDark: isDark,
          ),
          _buildActivityItem(
            avatarName: 'Rohan',
            actionText: 'settled up with you',
            itemTitle: 'UPI Transfer ✓',
            amountPaise: 120000,
            timestamp: 'Yesterday, 5:45 PM',
            isPositive: true,
            isDark: isDark,
          ),
          _buildActivityItem(
            avatarName: 'Karan',
            actionText: 'added an expense',
            itemTitle: 'Hotel Stay 🏨',
            amountPaise: 480000,
            timestamp: 'Yesterday, 2:10 PM',
            isPositive: false,
            isDark: isDark,
          ),
          _buildActivityItem(
            avatarName: 'Darpan',
            actionText: 'added an expense',
            itemTitle: 'Beachside Dinner 🍽️',
            amountPaise: 120000,
            timestamp: 'Yesterday, 1:30 PM',
            isPositive: false,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildActivityItem({
    required String avatarName,
    required String actionText,
    required String itemTitle,
    required int amountPaise,
    required String timestamp,
    required bool isPositive,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(name: avatarName, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    children: [
                      TextSpan(
                        text: '$avatarName ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: actionText,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+ ' : ''}${CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR')}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isPositive ? const Color(0xFF14B8A6) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
            ),
            alignment: Alignment.center,
            child: const Text('📜', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 16),
          Text(
            'No Activity Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your group expenses and settlements will appear here',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
