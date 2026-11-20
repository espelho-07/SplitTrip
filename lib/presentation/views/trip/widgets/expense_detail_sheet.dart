import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/currency_display.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';

/// Master Redesigned Expense Detail Sheet for Kith.
class ExpenseDetailSheet extends StatelessWidget {
  final Expense expense;
  final Trip trip;
  final String currentUserId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    required this.trip,
    required this.currentUserId,
    this.onEdit,
    this.onDelete,
  });

  TripMember? _findMember(String memberId) {
    if (memberId.isEmpty) return null;
    final direct = trip.members.where((m) => m.id == memberId).firstOrNull;
    if (direct != null) return direct;
    final byUserId = trip.members.where((m) => m.userId.isNotEmpty && m.userId == memberId).firstOrNull;
    if (byUserId != null) return byUserId;
    return trip.members.where((m) => m.mergedIntoMemberId == memberId).firstOrNull;
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
        color: isDark ? const Color(0xFF11161B) : Colors.white,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(expense.category.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      expense.category.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF182028) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${expense.splitType.name.toUpperCase()} SPLIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Amount
          Text(
            expense.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          CurrencyDisplay(
            amountInPaise: expense.amountInPaise,
            size: CurrencyDisplaySize.hero,
            colorMode: CurrencyColorMode.neutral,
            currencyCode: trip.currencyCode,
          ),
          const SizedBox(height: 16),

          // Payer Info Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161E26) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                MemberAvatar(name: payerName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid by ${isPayerCurrentUser ? "You" : payerName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        DateFormatter.formatRelative(expense.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Voice Transcript (if available)
          if (expense.voiceTranscript != null && expense.voiceTranscript!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, size: 18, color: Color(0xFF3B82F6)),
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

          // Receipt Attachment (if available)
          if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                final path = expense.receiptUrl!;
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog.fullscreen(
                    backgroundColor: Colors.black,
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.5,
                            child: File(path).existsSync()
                                ? Image.file(File(path), fit: BoxFit.contain)
                                : (path.startsWith('http')
                                    ? Image.network(path, fit: BoxFit.contain)
                                    : const Center(
                                        child: Text('Receipt image unavailable', style: TextStyle(color: Colors.white)),
                                      )),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 36,
                        height: 36,
                        color: Colors.black12,
                        child: File(expense.receiptUrl!).existsSync()
                            ? Image.file(File(expense.receiptUrl!), fit: BoxFit.cover)
                            : const Icon(Icons.receipt_long_rounded, color: Color(0xFF14B8A6), size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Attached 🧾',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
                          ),
                          Text(
                            'Tap to view receipt image in full screen',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded, size: 20, color: Color(0xFF14B8A6)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Split Breakdown Header
          Text(
            'SPLIT BREAKDOWN (${expense.splits.length} PARTICIPANTS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Splits List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: expense.splits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final split = expense.splits[index];
                final member = _findMember(split.memberId);
                final memberName = member?.displayName ?? 'Member';
                final isCurrentMember = member?.userId == currentUserId;
                final percentage = expense.amountInPaise > 0
                    ? ((split.amountInPaise / expense.amountInPaise) * 100).toStringAsFixed(1)
                    : '0';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161E26) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          MemberAvatar(name: memberName, size: 26),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentMember ? 'You' : memberName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '$percentage% split',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Actions
          if (canDelete) ...[
            if (onEdit != null) ...[
              AppButton(
                text: 'Edit Expense',
                variant: AppButtonVariant.secondary,
                icon: Icons.edit_note_rounded,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
              const SizedBox(height: 8),
            ],
            if (onDelete != null) ...[
              AppButton(
                text: 'Delete Expense',
                variant: AppButtonVariant.danger,
                icon: Icons.delete_outline_rounded,
                isFullWidth: true,
                onPressed: () {
                  HapticHelper.warning();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF161E26) : Colors.white,
                      title: const Text('Delete Expense?'),
                      content: const Text('Are you sure you want to delete this expense? This action will adjust all member balances immediately.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            onDelete?.call();
                          },
                          child: const Text('Delete', style: TextStyle(color: AppColors.negativeRedDark, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
