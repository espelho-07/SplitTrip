import 'package:flutter/material.dart';
import '../tokens/glass_tokens.dart';

/// Adaptive quality levels for the Liquid Glass Engine.
enum LiquidGlassQualityTier {
  /// Rich optical blur, gradient specular bevels, micro-tilt response.
  high,

  /// Moderate optical blur, static gradient bevels, optimized for battery life.
  balanced,

  /// Zero blur passes, solid high-contrast tinted surfaces. Guarantees maximum FPS.
  performance,
}

/// The runtime hardware engine managing optical glass rendering, quality levels,
/// and accessibility adaptations across Android and iOS devices.
class LiquidGlassEngine {
  LiquidGlassEngine._();

  static LiquidGlassQualityTier _configuredTier = LiquidGlassQualityTier.high;

  /// Globally sets the active engine quality tier (can be controlled via user settings).
  static void setQualityTier(LiquidGlassQualityTier tier) {
    _configuredTier = tier;
  }

  /// Resolves the effective quality tier for the active build context,
  /// automatically enforcing [LiquidGlassQualityTier.performance] when the OS
  /// requests reduced motion or high contrast.
  static LiquidGlassQualityTier resolveQuality(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final highContrast = mediaQuery?.highContrast ?? false;

    if (reduceMotion || highContrast) {
      return LiquidGlassQualityTier.performance;
    }

    return _configuredTier;
  }

  /// Calculates the effective Gaussian blur sigma based on context and device tier.
  static double getEffectiveBlur(BuildContext context, double targetSigma) {
    final tier = resolveQuality(context);
    switch (tier) {
      case LiquidGlassQualityTier.high:
        return targetSigma;
      case LiquidGlassQualityTier.balanced:
        return (targetSigma * 0.75).clamp(0.0, 14.0);
      case LiquidGlassQualityTier.performance:
        return 0.0;
    }
  }

  /// Returns whether a real-time [BackdropFilter] should be rendered.
  static bool shouldRenderBlur(BuildContext context) {
    return resolveQuality(context) != LiquidGlassQualityTier.performance;
  }

  /// Returns the appropriate surface background color for a given elevation and tier.
  static Color getSurfaceColor(
    BuildContext context, {
    required bool isDark,
    bool isCard = true,
    bool isModal = false,
  }) {
    final tier = resolveQuality(context);

    // In performance tier (or reduced transparency), use crisp opaque surfaces
    if (tier == LiquidGlassQualityTier.performance) {
      if (isDark) {
        return isModal
            ? GlassColors.darkSurfaceElevated
            : (isCard ? GlassColors.darkSurfaceCard : GlassColors.darkSurfaceSubtle);
      } else {
        return isModal
            ? GlassColors.lightSurfaceElevated
            : (isCard ? GlassColors.lightSurfaceCard : GlassColors.lightSurfaceSubtle);
      }
    }

    // In balanced or high tier, use translucent optical tint
    if (isDark) {
      return isModal
          ? GlassColors.darkGlassModal
          : (isCard ? GlassColors.darkGlassCard : GlassColors.darkGlassBackground);
    } else {
      return isModal
          ? GlassColors.lightGlassModal
          : (isCard ? GlassColors.lightGlassCard : GlassColors.lightGlassBackground);
    }
  }

  /// Returns the border decoration for glass bevel edges.
  static Border getBevelBorder({
    required bool isDark,
    double width = GlassTokens.bevelWidthStandard,
  }) {
    return Border.all(
      color: isDark ? GlassColors.darkBorderSubtle : GlassColors.lightBorderSubtle,
      width: width,
    );
  }
}
