import 'package:flutter/material.dart';
import '../tokens/glass_colors.dart';
import '../tokens/glass_radii.dart';
import '../tokens/glass_spacing.dart';

/// Reusable navigation controls enforcing the Unified Navigation Standard.
/// Guarantees strict 48x48dp touch targets and unambiguous Back vs Close iconography.
abstract final class LiquidGlassNavigation {
  /// Displays a standardized Back button (←) for hierarchical navigation.
  static Widget backButton({
    required BuildContext context,
    VoidCallback? onPressed,
    Color? iconColor,
    String tooltip = 'Back',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary);

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.maybePop(context),
          borderRadius: GlassRadii.smBorder,
          child: Container(
            constraints: GlassSpacing.touchTargetConstraints,
            alignment: Alignment.center,
            child: Icon(Icons.arrow_back_rounded, size: 22, color: color),
          ),
        ),
      ),
    );
  }

  /// Displays a standardized Close button (✕) for modal flows and dismissible sheets.
  static Widget closeButton({
    required BuildContext context,
    VoidCallback? onPressed,
    Color? iconColor,
    String tooltip = 'Close',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary);

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.maybePop(context),
          borderRadius: GlassRadii.smBorder,
          child: Container(
            constraints: GlassSpacing.touchTargetConstraints,
            alignment: Alignment.center,
            child: Icon(Icons.close_rounded, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
