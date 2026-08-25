import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pill_badge.dart';
import '../../../../domain/enums/expense_category.dart';
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
  void _showEditDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialRupees = (widget.expense.amountInPaise / 100).toStringAsFixed(
      widget.expense.amountInPaise % 100 == 0 ? 0 : 2,
    );
    final titleController = TextEditingController(text: widget.expense.title);
    final amountController = TextEditingController(text: initialRupees);
    final notesController = TextEditingController(text: widget.expense.notes ?? '');
    ExpenseCategory selectedCategory = widget.expense.category;
    bool isSavingEdit = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            title: Text('Edit Expense', style: AppTypography.titleLarge(isDark: isDark)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      labelText: 'Amount',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.bodyMedium(isDark: isDark),
                    decoration: InputDecoration(
                      labelText: 'What was this for?',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Category', style: AppTypography.titleSmall(isDark: isDark)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: selectedCategory,
                    dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ExpenseCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text('${cat.emoji} ${cat.displayName}'),
                      );
                    }).toList(),
                    onChanged: (cat) {
                      if (cat != null) {
                        setDialogState(() => selectedCategory = cat);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: notesController,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.bodyMedium(isDark: isDark),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingEdit ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Save Changes',
                isLoading: isSavingEdit,
                onPressed: isSavingEdit
                    ? null
                    : () async {
                        final amtText = amountController.text.trim();
                        final amt = double.tryParse(amtText) ?? 0;
                        final paise = (amt * 100).round();
                        final title = titleController.text.trim();

                        if (paise <= 0 || title.isEmpty) return;

                        setDialogState(() => isSavingEdit = true);
                        final dialogNav = Navigator.of(ctx);
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final vm = context.read<PersonalExpenseViewModel>();
                        final updated = widget.expense.copyWith(
                          title: title,
                          amountInPaise: paise,
                          category: selectedCategory,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );
                        final success = await vm.updateExpense(updated);
                        if (mounted) {
                          setDialogState(() => isSavingEdit = false);
                          if (success) {
                            HapticHelper.success();
                            dialogNav.pop();
                            nav.pop(true);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Expense updated ✓'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            HapticHelper.error();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update expense. Please try again.'),
                                backgroundColor: AppColors.negativeRedDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

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
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
              final vm = context.read<PersonalExpenseViewModel>();
              vm.deleteExpense(widget.expense.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Deleted "${widget.expense.title}"')),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
                  text: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: _showEditDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
