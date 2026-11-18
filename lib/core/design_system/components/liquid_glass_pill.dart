import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/glass_colors.dart';
import '../tokens/glass_radii.dart';
import '../tokens/glass_spacing.dart';
import '../tokens/glass_typography.dart';

/// Tactile Liquid Glass pill chip for category selection, filters, and status tags.
/// Enforces WCAG 2.2 AA minimum touch target sizing and distinct active glow states.
class LiquidGlassPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? leading;
  final String? emoji;
  final String? trailingBadge;
  final Color? activeColor;

  const LiquidGlassPill({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.leading,
    this.emoji,
    this.trailingBadge,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = activeColor ?? GlassColors.brandLight;

    Color bg;
    Border? border;
    List<BoxShadow>? shadow;

    if (isSelected) {
      bg = primaryAccent.withValues(alpha: isDark ? 0.22 : 0.16);
      border = Border.all(color: primaryAccent, width: 1.2);
      shadow = [
        BoxShadow(
          color: primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      bg = isDark ? GlassColors.darkGlassCard : GlassColors.lightGlassCard;
      border = Border.all(
        color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
        width: 0.75,
      );
    }

    final textColor = isSelected
        ? (isDark ? Colors.white : primaryAccent)
        : (isDark ? GlassColors.darkTextSecondary : GlassColors.lightTextSecondary);

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: GlassRadii.pillBorder,
        border: border,
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
          ] else if (leading != null) ...[
            leading!,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GlassTypography.bodySmall(isDark: isDark, color: textColor).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (trailingBadge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryAccent
                    : (isDark ? Colors.white12 : Colors.black12),
                borderRadius: GlassRadii.pillBorder,
              ),
              child: Text(
                trailingBadge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GlassSpacing.minTouchTarget),
        child: Center(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
            borderRadius: GlassRadii.pillBorder,
            child: pill,
          ),
        ),
      );
    }

    return pill;
  }
}
