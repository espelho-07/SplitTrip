import 'dart:ui';
import 'package:flutter/material.dart';
import '../engine/liquid_glass_engine.dart';
import '../tokens/glass_tokens.dart';

/// Translucent Liquid Glass bottom navigation bar surface.
/// Blurs underlying scrollable list content while keeping tab destinations crisp and legible.
class LiquidGlassNavBar extends StatelessWidget {
  final Widget child;

  const LiquidGlassNavBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBlur = LiquidGlassEngine.getEffectiveBlur(context, GlassTokens.blurStandard);
    final surfaceColor = LiquidGlassEngine.getSurfaceColor(
      context,
      isDark: isDark,
      isCard: false,
    );

    Widget bar = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
            width: 0.75,
          ),
        ),
      ),
      child: child,
    );

    if (effectiveBlur > 0.0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: bar,
        ),
      );
    }

    return bar;
  }
}
