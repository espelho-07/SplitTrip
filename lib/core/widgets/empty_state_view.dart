import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class EmptyStateView extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData? buttonIcon;

  const EmptyStateView({
    super.key,
    this.emoji = '🏖️',
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.buttonIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              ),
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium(isDark: isDark),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(isDark: isDark),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: buttonText!,
                icon: buttonIcon,
                onPressed: onButtonPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
