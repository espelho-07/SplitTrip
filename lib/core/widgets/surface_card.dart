import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../utils/haptic_feedback_helper.dart';

/// Refined card surface that adapts cleanly between light and layered dark modes.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final bool hasElevation;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.hasElevation = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? AppRadius.lgBorder;

    final bg = backgroundColor ??
        (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);

    final b = border ??
        Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 1,
        );

    final shadows = hasElevation
        ? (isDark ? AppElevation.darkSubtle : AppElevation.lightCard)
        : null;

    Widget card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: b,
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            onTap!();
          },
          borderRadius: r,
          splashFactory: InkSparkle.splashFactory,
          child: card,
        ),
      );
    }

    return card;
  }
}
