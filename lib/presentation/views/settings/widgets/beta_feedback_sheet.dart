import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';

enum BetaFeedbackCategory {
  bug('Bug Report', Icons.bug_report_outlined),
  suggestion('Suggestion', Icons.lightbulb_outline_rounded),
  confusing('Confusing UX', Icons.help_outline_rounded),
  performance('Performance', Icons.speed_rounded),
  other('Other Feedback', Icons.chat_bubble_outline_rounded);

  final String label;
  final IconData icon;
  const BetaFeedbackCategory(this.label, this.icon);
}

class BetaFeedbackSheet extends StatefulWidget {
  final String? currentScreenContext;

  const BetaFeedbackSheet({super.key, this.currentScreenContext});

  @override
  State<BetaFeedbackSheet> createState() => _BetaFeedbackSheetState();
}

class _BetaFeedbackSheetState extends State<BetaFeedbackSheet> {
  BetaFeedbackCategory _selectedCategory = BetaFeedbackCategory.bug;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_feedbackController.text.trim().isEmpty || _isSubmitting) return;

    HapticHelper.success();
    setState(() {
      _isSubmitting = true;
      _isSubmitted = true;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: _isSubmitted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 56,
                  color: AppColors.positiveGreenLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Feedback Draft Saved',
                  style: AppTypography.titleMedium(isDark: isDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thank you! Your feedback draft has been logged locally on this device for the alpha development team.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                const SizedBox(height: 32),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alpha Feedback',
                          style: AppTypography.titleLarge(isDark: isDark),
                        ),
                        Text(
                          '${AppConfig.appName} v${AppConfig.appVersion} (${AppConfig.environment})',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Category Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BetaFeedbackCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ChoiceChip(
                      avatar: Icon(
                        category.icon,
                        size: 16,
                        color: isSelected
                            ? (isDark ? AppColors.darkBackground : Colors.white)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      label: Text(category.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          HapticHelper.selection();
                          setState(() => _selectedCategory = category);
                        }
                      },
                      selectedColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Feedback Text Field
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Describe what happened or how we can improve...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                AppButton(
                  text: 'Save Feedback Draft',
                  icon: Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _feedbackController.text.trim().isNotEmpty ? _handleSubmit : null,
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
