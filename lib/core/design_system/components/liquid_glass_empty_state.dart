import 'package:flutter/material.dart';
import '../tokens/glass_colors.dart';
import '../tokens/glass_radii.dart';
import '../tokens/glass_typography.dart';
import 'liquid_glass_button.dart';
import 'liquid_glass_card.dart';

/// Standardized Liquid Glass empty state card.
/// Provides friendly, context-specific messaging and clear next-action button.
class LiquidGlassEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? emoji;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const LiquidGlassEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.emoji,
    this.icon,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          borderRadius: GlassRadii.xlBorder,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? GlassColors.darkSurfaceSubtle : GlassColors.lightSurfaceSubtle,
                ),
                alignment: Alignment.center,
                child: emoji != null
                    ? Text(emoji!, style: const TextStyle(fontSize: 30))
                    : Icon(
                        icon ?? Icons.inbox_rounded,
                        size: 32,
                        color: GlassColors.brandLight,
                      ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GlassTypography.titleMedium(isDark: isDark),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GlassTypography.bodyMedium(isDark: isDark),
              ),
              if (actionText != null && onActionPressed != null) ...[
                const SizedBox(height: 22),
                LiquidGlassButton(
                  text: actionText!,
                  onPressed: onActionPressed,
                  variant: LiquidGlassButtonVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
