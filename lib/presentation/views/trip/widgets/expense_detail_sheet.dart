import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';

class ExpenseDetailSheet extends StatelessWidget {
  final Expense expense;
  final Trip trip;
  final String currentUserId;
  final VoidCallback? onDelete;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    required this.trip,
    required this.currentUserId,
    this.onDelete,
  });

  TripMember? _findMember(String memberId) {
    return trip.members.where((m) => m.id == memberId).firstOrNull;
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payer = _findMember(expense.paidById);
    final payerName = payer?.displayName ?? 'Member';
    final isPayerCurrentUser = payer?.userId == currentUserId;
    final isTripCreator = trip.creatorId == currentUserId;
    final canDelete = (isPayerCurrentUser || isTripCreator) && trip.lifecycleState.allowsExpenses;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: expense.category.displayName.toUpperCase(),
                icon: expense.category.icon,
              ),
              PillBadge(
                label: expense.splitType.name.toUpperCase(),
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            expense.title,
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 4),

          CurrencyDisplay(
            amountInPaise: expense.amountInPaise,
            size: CurrencyDisplaySize.hero,
            colorMode: CurrencyColorMode.neutral,
            currencyCode: trip.currencyCode,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Payer Info Card
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                MemberAvatar(name: payerName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid by ${isPayerCurrentUser ? 'You' : payerName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        _formatTimestamp(expense.createdAt),
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Voice Transcript (if available)
          if (expense.voiceTranscript != null && expense.voiceTranscript!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              backgroundColor: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.08),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 18,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Voice transcript: "${expense.voiceTranscript}"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Split Breakdown Header
          Text(
            'Split Breakdown (${expense.splits.length} participants)',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Splits List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: expense.splits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final split = expense.splits[index];
                final member = _findMember(split.memberId);
                final memberName = member?.displayName ?? 'Member';
                final isCurrentMember = member?.userId == currentUserId;
                final percentage = expense.amountInPaise > 0
                    ? ((split.amountInPaise / expense.amountInPaise) * 100).toStringAsFixed(1)
                    : '0';

                return SurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          MemberAvatar(name: memberName, size: 28),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentMember ? 'You' : memberName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '$percentage% split',
                                style: AppTypography.bodySmall(isDark: isDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(
                          split.amountInPaise,
                          currencyCode: trip.currencyCode,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Actions
          if (canDelete && onDelete != null) ...[
            AppButton(
              text: 'Delete Expense',
              variant: AppButtonVariant.danger,
              icon: Icons.delete_outline_rounded,
              isFullWidth: true,
              onPressed: () {
                HapticHelper.medium();
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          AppButton(
            text: 'Close',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Expense?'),
          content: Text('Are you sure you want to remove "${expense.title}"? This will recalculate all balances.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context); // close sheet
                onDelete?.call();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
