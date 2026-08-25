import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';

class MemberSpendBreakdownSheet extends StatelessWidget {
  final Trip trip;
  final TripMember member;
  final List<Expense> expenses;
  final String currentUserId;

  const MemberSpendBreakdownSheet({
    super.key,
    required this.trip,
    required this.member,
    required this.expenses,
    required this.currentUserId,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required TripMember member,
    required List<Expense> expenses,
    required String currentUserId,
  }) {
    HapticHelper.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemberSpendBreakdownSheet(
        trip: trip,
        member: member,
        expenses: expenses,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelf = member.userId == currentUserId;

    // Filter non-deleted expenses where this member has an allocated split > 0
    final memberItems = <({Expense expense, int memberSharePaise})>[];
    int totalMemberSpentPaise = 0;
    int totalTripSpentPaise = 0;

    for (final exp in expenses) {
      if (exp.isDeleted) continue;
      totalTripSpentPaise += exp.amountInPaise;

      final split = exp.splits.where((s) => s.memberId == member.id).firstOrNull;
      if (split != null && split.amountInPaise > 0) {
        memberItems.add((expense: exp, memberSharePaise: split.amountInPaise));
        totalMemberSpentPaise += split.amountInPaise;
      }
    }

    // Sort newest first
    memberItems.sort((a, b) => b.expense.createdAt.compareTo(a.expense.createdAt));

    final percentage = totalTripSpentPaise > 0
        ? ((totalMemberSpentPaise / totalTripSpentPaise) * 100).round()
        : 0;

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  MemberAvatar(
                    name: member.displayName,
                    isCreator: member.isCreator,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isSelf ? '${member.displayName} (You)' : member.displayName,
                            style: AppTypography.titleMedium(isDark: isDark),
                          ),
                          if (member.isCreator) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CREATOR',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Spent in "${trip.name}"',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Summary Card
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SPENT / CONSUMED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CurrencyDisplay(
                      amountInPaise: totalMemberSpentPaise,
                      size: CurrencyDisplaySize.large,
                      currencyCode: trip.currencyCode,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$percentage% of trip',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${memberItems.length} ${memberItems.length == 1 ? 'expense' : 'expenses'}',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Itemized Expense Breakdown',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.xs),

          // List of Expenses
          if (memberItems.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.emeraldPrimary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No expenses assigned',
                        style: AppTypography.titleMedium(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.displayName} has no allocated shares in this trip yet.',
                        style: AppTypography.bodySmall(isDark: isDark),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: memberItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final item = memberItems[index];
                  final exp = item.expense;
                  final payer = trip.members.where((m) => m.id == exp.paidById).firstOrNull;
                  final payerName = payer != null
                      ? (payer.userId == currentUserId ? 'You' : payer.displayName)
                      : 'Unknown';

                  final dateStr = DateFormatter.formatDate(exp.createdAt);

                  return SurfaceCard(
                    backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Category Icon
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: exp.category.color.withValues(alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            exp.category.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Payer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$dateStr · Paid by $payerName',
                                style: AppTypography.bodySmall(isDark: isDark),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Member Share & Total Bill
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaise(item.memberSharePaise, currencyCode: trip.currencyCode),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total ${CurrencyFormatter.formatPaise(exp.amountInPaise, currencyCode: trip.currencyCode)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
