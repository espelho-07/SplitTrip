import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

class SetBudgetDialog extends StatefulWidget {
  final int currentBudgetPaise;
  final String monthYear;

  const SetBudgetDialog({
    super.key,
    required this.currentBudgetPaise,
    required this.monthYear,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentBudgetPaise,
    required String monthYear,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SetBudgetDialog(
        currentBudgetPaise: currentBudgetPaise,
        monthYear: monthYear,
      ),
    );
  }

  @override
  State<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<SetBudgetDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialRupees = widget.currentBudgetPaise > 0
        ? (widget.currentBudgetPaise / 100).toStringAsFixed(0)
        : '';
    _controller = TextEditingController(text: initialRupees);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final text = _controller.text.trim();
    final rupees = double.tryParse(text) ?? 0;
    final paise = (rupees * 100).round();

    setState(() => _isSaving = true);
    final vm = context.read<PersonalExpenseViewModel>();
    final success = await vm.setMonthlyBudget(paise);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paise > 0 ? 'Monthly budget updated!' : 'Budget removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update budget. Please try again.'),
            backgroundColor: AppColors.negativeRedDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      child: Padding(
        padding: AppSpacing.dialogPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.emeraldPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Monthly Budget',
                    style: AppTypography.titleLarge(isDark: isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set a target spending limit for this month to keep your expenses on track.',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                hintText: '10,000',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (widget.currentBudgetPaise > 0) ...[
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _controller.text = '0';
                            _handleSave();
                          },
                    child: const Text('Clear', style: TextStyle(color: AppColors.negativeRedLight)),
                  ),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                ],
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: 'Save',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
