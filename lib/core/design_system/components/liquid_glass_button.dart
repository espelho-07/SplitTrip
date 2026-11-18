import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/glass_colors.dart';
import '../tokens/glass_radii.dart';
import '../tokens/glass_spacing.dart';
import '../tokens/glass_typography.dart';

enum LiquidGlassButtonVariant {
  primary,
  secondary,
  glass,
  destructive,
}

/// Tactile, optical Liquid Glass button.
/// Guarantees WCAG 2.2 AA minimum 48x48dp interactive touch target sizing,
/// haptic feedback, responsive loading indicators, and crisp disabled states.
class LiquidGlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LiquidGlassButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = LiquidGlassButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case LiquidGlassButtonVariant.primary:
        bg = isEnabled ? GlassColors.brandLight : (isDark ? const Color(0xFF163832) : const Color(0xFF99F6E4));
        fg = isEnabled ? Colors.white : Colors.white54;
        shadow = isEnabled
            ? [
                BoxShadow(
                  color: GlassColors.brandLight.withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null;
        break;

      case LiquidGlassButtonVariant.secondary:
        bg = isDark ? GlassColors.darkSurfaceSubtle : GlassColors.lightSurfaceSubtle;
        fg = isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary;
        border = Border.all(
          color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
        );
        break;

      case LiquidGlassButtonVariant.glass:
        bg = isDark ? GlassColors.darkGlassCard : GlassColors.lightGlassCard;
        fg = isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary;
        border = Border.all(
          color: isDark ? GlassColors.darkBorderStrong : GlassColors.lightBorderStrong,
        );
        break;

      case LiquidGlassButtonVariant.destructive:
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        fg = isDark ? GlassColors.negativeRedDark : GlassColors.negativeRedLight;
        border = Border.all(
          color: GlassColors.negativeRedDark.withValues(alpha: 0.3),
        );
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: GlassTypography.titleSmall(isDark: isDark, color: fg).copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: isFullWidth ? double.infinity : GlassSpacing.minTouchTarget,
        minHeight: GlassSpacing.minTouchTarget,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                }
              : null,
          borderRadius: GlassRadii.mdBorder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: GlassRadii.mdBorder,
              border: border,
              boxShadow: shadow,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
