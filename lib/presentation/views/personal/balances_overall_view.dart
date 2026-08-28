import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/member_avatar.dart';

class BalancesOverallView extends StatefulWidget {
  const BalancesOverallView({super.key});

  @override
  State<BalancesOverallView> createState() => _BalancesOverallViewState();
}

class _BalancesOverallViewState extends State<BalancesOverallView> {
  bool _isOverall = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Balances', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Segmented Tabs: [ Overall | Trip wise ]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isOverall = true),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isOverall ? const Color(0xFF14B8A6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Overall',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isOverall ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isOverall = false),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: !_isOverall ? const Color(0xFF14B8A6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Trip wise',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: !_isOverall ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1418) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are owed', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      const Text('₹ 2,450', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1418) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You owe', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      const Text('₹ 1,230', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            'People',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // People list
          _buildPersonBalanceRow('Rohan', 'Owes you ₹ 1,200', '₹ 1,200', true, isDark),
          _buildPersonBalanceRow('Priya', 'Owes you ₹ 650', '₹ 650', true, isDark),
          _buildPersonBalanceRow('Karan', 'You owe ₹ 600', '₹ 600', false, isDark),
          _buildPersonBalanceRow('Ananya', 'You owe ₹ 630', '₹ 630', false, isDark),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Balances always settle up to zero ✓',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonBalanceRow(String name, String sub, String amount, bool isOwedToYou, bool isDark) {
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
          MemberAvatar(name: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(sub, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isOwedToYou ? const Color(0xFF14B8A6) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
