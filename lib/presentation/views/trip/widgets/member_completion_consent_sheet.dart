import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/repositories/trip_repository.dart';

class MemberCompletionConsentSheet extends StatefulWidget {
  final String tripId;
  final String tripName;
  final String requestId;
  final String requestedByName;
  final VoidCallback? onResponded;

  const MemberCompletionConsentSheet({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.requestId,
    required this.requestedByName,
    this.onResponded,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    required String tripName,
    required String requestId,
    required String requestedByName,
    VoidCallback? onResponded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) => MemberCompletionConsentSheet(
        tripId: tripId,
        tripName: tripName,
        requestId: requestId,
        requestedByName: requestedByName,
        onResponded: onResponded,
      ),
    );
  }

  @override
  State<MemberCompletionConsentSheet> createState() => _MemberCompletionConsentSheetState();
}

class _MemberCompletionConsentSheetState extends State<MemberCompletionConsentSheet> {
  bool _isSubmitting = false;
  bool _showReasonInput = false;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitResponse(String response) async {
    final tripRepo = context.read<TripRepository>();
    setState(() => _isSubmitting = true);

    try {
      final note = _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null;
      await tripRepo.respondCompletionConsent(
        widget.tripId,
        widget.requestId,
        response,
        note: note,
      );

      if (mounted) {
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response == 'YES'
                ? 'Availability confirmed. Thank you!'
                : 'Trip completion blocked. Owner notified.'),
            backgroundColor: response == 'YES' ? AppColors.emeraldPrimary : AppColors.negativeRedLight,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onResponded?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit response: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.negativeRedLight,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: AppSpacing.bottomSheetPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.emeraldPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Completion Request',
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

            Text(
              '${widget.requestedByName} wants to complete "${widget.tripName}".',
              style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Completing the trip finalizes all expense splitting and locks the balance calculations. Do you have any pending bills, unpaid expenses, or missing receipts?',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_showReasonInput) ...[
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Why are you unavailable or unsettled? (Optional)',
                  hintText: 'e.g., Still need to add lunch receipt',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  AppButton(
                    text: "Yes, I'm Settled (Confirm Availability)",
                    isFullWidth: true,
                    onPressed: () => _submitResponse('YES'),
                  ),
                  const SizedBox(height: 10),
                  if (!_showReasonInput)
                    AppButton(
                      text: "No, I Have Pending Expenses",
                      variant: AppButtonVariant.outline,
                      isFullWidth: true,
                      onPressed: () => setState(() => _showReasonInput = true),
                    )
                  else
                    AppButton(
                      text: "Submit Rejection (Block Completion)",
                      variant: AppButtonVariant.danger,
                      isFullWidth: true,
                      onPressed: () => _submitResponse('NO'),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
