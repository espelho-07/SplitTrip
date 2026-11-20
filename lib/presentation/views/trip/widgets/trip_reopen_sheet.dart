import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/repositories/trip_repository.dart';
import '../../../../domain/models/trip_completion_models.dart';

class TripReopenSheet extends StatefulWidget {
  final String tripId;
  final String tripName;
  final bool isOwner;
  final TripReopeningRequest? reviewRequest;
  final VoidCallback? onCompleted;

  const TripReopenSheet({
    super.key,
    required this.tripId,
    required this.tripName,
    this.isOwner = false,
    this.reviewRequest,
    this.onCompleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    required String tripName,
    bool isOwner = false,
    TripReopeningRequest? reviewRequest,
    VoidCallback? onCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) => TripReopenSheet(
        tripId: tripId,
        tripName: tripName,
        isOwner: isOwner,
        reviewRequest: reviewRequest,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<TripReopenSheet> createState() => _TripReopenSheetState();
}

class _TripReopenSheetState extends State<TripReopenSheet> {
  String _selectedCategory = 'MISSING_EXPENSE';
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _reviewNoteController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, String> _categories = {
    'MISSING_EXPENSE': 'Missing Expense',
    'INCORRECT_PAYER': 'Incorrect Payer',
    'WRONG_SPLIT': 'Wrong Split',
    'PAYMENT_DISPUTE': 'Payment Dispute',
    'OTHER': 'Other Reason',
  };

  @override
  void dispose() {
    _noteController.dispose();
    _reviewNoteController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final tripRepo = context.read<TripRepository>();
    setState(() => _isSubmitting = true);

    try {
      await tripRepo.requestTripReopening(
        widget.tripId,
        reasonCategory: _selectedCategory,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      if (mounted) {
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reopening request submitted to trip creator'),
            backgroundColor: AppColors.emeraldPrimary,
          ),
        );
        widget.onCompleted?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.negativeRedLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reviewRequest(String action) async {
    if (widget.reviewRequest == null) return;
    final tripRepo = context.read<TripRepository>();
    setState(() => _isSubmitting = true);

    try {
      await tripRepo.reviewTripReopening(
        widget.tripId,
        widget.reviewRequest!.id,
        action: action,
        reviewNote: _reviewNoteController.text.trim().isNotEmpty ? _reviewNoteController.text.trim() : null,
      );

      if (mounted) {
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'APPROVE'
                ? 'Trip reopened successfully! All members notified.'
                : 'Reopening request rejected.'),
            backgroundColor: action == 'APPROVE' ? AppColors.emeraldPrimary : AppColors.amberAccent,
          ),
        );
        widget.onCompleted?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.negativeRedLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReviewMode = widget.isOwner && widget.reviewRequest != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: AppSpacing.bottomSheetPadding,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amberAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: AppColors.amberAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReviewMode ? 'Review Reopen Request' : 'Request to Reopen Trip',
                          style: AppTypography.titleLarge(isDark: isDark),
                        ),
                        Text(
                          widget.tripName,
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(color: AppColors.emeraldPrimary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (isReviewMode) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    borderRadius: AppRadius.mdBorder,
                    border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.amberAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Reason: ${_categories[widget.reviewRequest!.reasonCategory] ?? widget.reviewRequest!.reasonCategory}',
                            style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (widget.reviewRequest!.note != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.reviewRequest!.note!,
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _reviewNoteController,
                  decoration: InputDecoration(
                    labelText: 'Response Note (Optional)',
                    hintText: 'e.g. Approved, please add the receipt promptly',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_isSubmitting)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Reject Request',
                          variant: AppButtonVariant.outline,
                          onPressed: () => _reviewRequest('REJECT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Approve & Reopen',
                          onPressed: () => _reviewRequest('APPROVE'),
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                Text(
                  'Completed trips are locked to preserve final settlements. If an expense was missed or incorrectly calculated, submit a request to the trip owner.',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  'Select Reason Category',
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.entries.map((entry) {
                    final isSelected = _selectedCategory == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      selectedColor: AppColors.emeraldPrimary.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = entry.key);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Explanation (Optional)',
                    hintText: 'e.g. Forgot to add train return ticket receipt',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (_isSubmitting)
                  const Center(child: CircularProgressIndicator())
                else
                  AppButton(
                    text: 'Send Reopening Request',
                    isFullWidth: true,
                    onPressed: _submitRequest,
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
