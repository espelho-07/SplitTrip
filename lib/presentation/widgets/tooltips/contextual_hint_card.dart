import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/local_storage_service.dart';

/// Lightweight dismissible first-use contextual hint card for key screens.
class ContextualHintCard extends StatefulWidget {
  final String hintKey;
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;

  const ContextualHintCard({
    super.key,
    required this.hintKey,
    required this.title,
    required this.description,
    this.icon = Icons.lightbulb_outline_rounded,
    this.iconColor,
  });

  @override
  State<ContextualHintCard> createState() => _ContextualHintCardState();
}

class _ContextualHintCardState extends State<ContextualHintCard> {
  bool _isDismissed = true;

  @override
  void initState() {
    super.initState();
    final storage = context.read<LocalStorageService>();
    _isDismissed = storage.isHintDismissed(widget.hintKey);
  }

  Future<void> _handleDismiss() async {
    HapticHelper.light();
    final storage = context.read<LocalStorageService>();
    await storage.dismissHint(widget.hintKey);
    if (mounted) {
      setState(() => _isDismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final accentColor = widget.iconColor ?? AppColors.emeraldPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? accentColor.withValues(alpha: 0.12)
              : accentColor.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
              ),
              child: Icon(widget.icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _handleDismiss,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.hintGotIt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms),
    );
  }
}
