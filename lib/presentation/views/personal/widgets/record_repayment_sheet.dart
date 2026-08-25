import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/models/personal_debt.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';
import '../../../widgets/progress/progress.dart';

class RecordRepaymentSheet extends StatefulWidget {
  final PersonalDebt debt;

  const RecordRepaymentSheet({super.key, required this.debt});

  static Future<bool?> show(BuildContext context, {required PersonalDebt debt}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecordRepaymentSheet(debt: debt),
    );
  }

  @override
  State<RecordRepaymentSheet> createState() => _RecordRepaymentSheetState();
}

class _RecordRepaymentSheetState extends State<RecordRepaymentSheet> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final remainingRupees = (widget.debt.remainingAmountInPaise / 100).toStringAsFixed(
      widget.debt.remainingAmountInPaise % 100 == 0 ? 0 : 2,
    );
    _amountController = TextEditingController(text: remainingRupees);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final amountText = _amountController.text.trim();
    final rupees = double.tryParse(amountText) ?? 0;
    final paise = (rupees * 100).round();

    if (paise <= 0 || paise > widget.debt.remainingAmountInPaise) {
      HapticHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid repayment amount.')),
      );
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    final vm = context.read<PersonalExpenseViewModel>();
    final success = await vm.recordRepayment(
      userId: user.id,
      debtId: widget.debt.id,
      amountInPaise: paise,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
        KithSuccessToast.show(context, 'Payment recorded ✓');
      } else {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record repayment. Please try again.'),
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
    final isLent = widget.debt.debtType == PersonalDebtType.lent;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final statusColor = isLent ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight) : AppColors.emeraldPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + bottomInset,
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Icon(
                  isLent ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLent
                          ? '${widget.debt.personName} Returned Money'
                          : 'Repaid ${widget.debt.personName}',
                      style: AppTypography.titleMedium(isDark: isDark),
                    ),
                    Text(
                      'Outstanding: ${CurrencyFormatter.formatPaise(widget.debt.remainingAmountInPaise, currencyCode: 'INR')}',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Repayment Amount',
            style: AppTypography.titleSmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
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
              hintText: '0.00',
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
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyMedium(isDark: isDark),
            decoration: InputDecoration(
              hintText: 'Note (e.g. GPay, Cash, UPI)',
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.mdBorder,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            text: 'Confirm Repayment',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isSaving,
            isFullWidth: true,
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}
