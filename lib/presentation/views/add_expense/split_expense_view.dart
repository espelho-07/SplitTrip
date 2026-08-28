import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/models/trip.dart';

class SplitExpenseView extends StatefulWidget {
  final Trip trip;
  final int totalAmountPaise;

  const SplitExpenseView({super.key, required this.trip, required this.totalAmountPaise});

  @override
  State<SplitExpenseView> createState() => _SplitExpenseViewState();
}

class _SplitExpenseViewState extends State<SplitExpenseView> {
  bool _isEqualSplit = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = widget.trip.members;
    final perPersonPaise = members.isNotEmpty ? (widget.totalAmountPaise / members.length).round() : 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Split Expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Segmented Switcher: [ Equal | Custom ]
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
                      onTap: () => setState(() => _isEqualSplit = true),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: _isEqualSplit ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Equal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isEqualSplit ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isEqualSplit = false),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: !_isEqualSplit ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !_isEqualSplit ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Header summary
            Text(
              'Total Amount: ${CurrencyFormatter.formatPaise(widget.totalAmountPaise, currencyCode: widget.trip.currencyCode)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Split between ${members.length} members',
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
            ),

            const SizedBox(height: 24),

            // Members Breakdown List
            Expanded(
              child: ListView.separated(
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final member = members[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1418) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        MemberAvatar(name: member.displayName, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(perPersonPaise, currencyCode: widget.trip.currencyCode),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Confirm Button
            GestureDetector(
              onTap: () {
                HapticHelper.light();
                Navigator.pop(context);
              },
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Confirm Split',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
