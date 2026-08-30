import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
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

  static const String _creatorEmail = 'support@kith.app';

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String _getCategoryLabel(BetaFeedbackCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case BetaFeedbackCategory.bug:
        return l10n.feedbackCatBug;
      case BetaFeedbackCategory.suggestion:
        return l10n.feedbackCatSuggestion;
      case BetaFeedbackCategory.confusing:
        return l10n.feedbackCatConfusing;
      case BetaFeedbackCategory.performance:
        return l10n.feedbackCatPerf;
      case BetaFeedbackCategory.other:
        return l10n.feedbackCatOther;
    }
  }

  Future<void> _handleSendEmail() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    HapticHelper.medium();
    final subject = Uri.encodeComponent('[Kith App Feedback] ${_selectedCategory.label} - v${AppConfig.appVersion}');
    final body = Uri.encodeComponent(
      'Feedback Details:\n\n$text\n\n---\nDevice/App Info:\nApp: Kith v${AppConfig.appVersion} (${AppConfig.environment})\nContext: ${widget.currentScreenContext ?? 'App'}\nTimestamp: ${DateTime.now().toIso8601String()}',
    );

    final emailUri = Uri.parse('mailto:$_creatorEmail?subject=$subject&body=$body');

    bool launched = false;
    try {
      launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      // Fallback: Copy to clipboard so user can easily paste in Gmail / Email app
      await Clipboard.setData(ClipboardData(text: 'To: $_creatorEmail\nSubject: [Kith App Feedback] ${_selectedCategory.label}\n\n$text'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email app not found. Feedback copied to clipboard ✓ ($_creatorEmail)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
        _isSubmitted = true;
      });

      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  void _handleSaveDraft() {
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
    final l10n = context.l10n;

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
                  l10n.feedbackSentTitle,
                  style: AppTypography.titleMedium(isDark: isDark),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.feedbackSentDesc(_creatorEmail),
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
                          l10n.feedbackTitle,
                          style: AppTypography.titleLarge(isDark: isDark),
                        ),
                        Text(
                          l10n.feedbackDirectCreator(_creatorEmail),
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(color: const Color(0xFF14B8A6)),
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
                      label: Text(_getCategoryLabel(category, l10n)),
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
                  decoration: InputDecoration(
                    hintText: l10n.feedbackHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _feedbackController.text.trim().isNotEmpty ? _handleSaveDraft : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(l10n.feedbackSaveDraft),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: l10n.feedbackSendEmail,
                        icon: Icons.send_rounded,
                        isLoading: _isSubmitting,
                        onPressed: _feedbackController.text.trim().isNotEmpty ? _handleSendEmail : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
