import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/models/personal_expense.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

class PersonalExpenseDetailSheet extends StatefulWidget {
  final PersonalExpense expense;

  const PersonalExpenseDetailSheet({super.key, required this.expense});

  static Future<bool?> show(BuildContext context, {required PersonalExpense expense}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PersonalExpenseDetailSheet(expense: expense),
    );
  }

  @override
  State<PersonalExpenseDetailSheet> createState() => _PersonalExpenseDetailSheetState();
}

class _PersonalExpenseDetailSheetState extends State<PersonalExpenseDetailSheet> {
  bool _isDeleting = false;

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        title: Text('Delete Expense?', style: AppTypography.titleLarge(isDark: isDark)),
        content: Text(
          'Are you sure you want to delete "${widget.expense.title}"? This cannot be undone.',
          style: AppTypography.bodyMedium(isDark: isDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isDeleting = true);
              final vm = context.read<PersonalExpenseViewModel>();
              final success = await vm.deleteExpense(widget.expense.id);
              if (mounted) {
                setState(() => _isDeleting = false);
                if (success) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense deleted.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = CurrencyFormatter.formatPaise(
      widget.expense.amountInPaise,
      currencyCode: 'INR',
    );

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
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.expense.category.color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Text(
                  widget.expense.category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense.title,
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatDate(widget.expense.date),
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
              Text(
                formattedAmount,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Category: ', style: AppTypography.titleSmall(isDark: isDark)),
              PillBadge(
                label: widget.expense.category.displayName,
                color: widget.expense.category.color,
              ),
            ],
          ),
          if (widget.expense.notes != null && widget.expense.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Notes', style: AppTypography.titleSmall(isDark: isDark)),
            const SizedBox(height: 4),
            Text(widget.expense.notes!, style: AppTypography.bodyMedium(isDark: isDark)),
          ],
          if (widget.expense.voiceTranscript != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.mic_none_rounded, size: 16, color: AppColors.emeraldPrimary),
                const SizedBox(width: 6),
                Text(
                  'Spoken: "${widget.expense.voiceTranscript}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.danger,
                  isLoading: _isDeleting,
                  onPressed: _isDeleting ? null : _confirmDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
