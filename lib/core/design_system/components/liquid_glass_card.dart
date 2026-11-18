import 'dart:ui';
import 'package:flutter/material.dart';
import '../engine/liquid_glass_engine.dart';
import '../engine/liquid_glass_painter.dart';
import '../tokens/glass_tokens.dart';

/// Tactile, optical Liquid Glass card container.
/// Features hardware-accelerated BackdropFilter blur, 10th-power chamfered gradient bevel,
/// ambient elevation shadows, and a gentle micro-scale press interaction via Flutter's
/// built-in AnimatedScale (immune to ticker lifecycle/element reconciliation crashes).
class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final bool enableBlur;
  final bool showBevel;
  final double blurSigma;
  final List<BoxShadow>? customShadow;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.borderRadius = GlassRadii.lgBorder,
    this.backgroundColor,
    this.backgroundGradient,
    this.enableBlur = false, // Disabled by default for 120 FPS high-refresh scrolling performance
    this.showBevel = true,
    this.blurSigma = GlassTokens.blurStandard,
    this.customShadow,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (mounted) setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (mounted) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (mounted) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBlur = widget.enableBlur
        ? LiquidGlassEngine.getEffectiveBlur(context, widget.blurSigma)
        : 0.0;
    final surfaceColor = widget.backgroundColor ??
        LiquidGlassEngine.getSurfaceColor(context, isDark: isDark, isCard: true);

    final shadows = widget.customShadow ??
        (isDark ? GlassTokens.darkElevatedShadow : GlassTokens.lightElevatedShadow);

    Widget cardContent = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundGradient == null ? surfaceColor : null,
        gradient: widget.backgroundGradient,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );

    // Apply optical blur if enabled and supported by device quality tier
    if (effectiveBlur > 0.0) {
      cardContent = ClipRRect(
        borderRadius: widget.borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: cardContent,
        ),
      );
    } else {
      cardContent = ClipRRect(
        borderRadius: widget.borderRadius,
        child: cardContent,
      );
    }

    // Apply 10th-power bevel gradient stroke overlay
    if (widget.showBevel) {
      cardContent = CustomPaint(
        foregroundPainter: LiquidGlassPainter(
          borderRadius: widget.borderRadius,
          isDark: isDark,
          strokeWidth: GlassTokens.bevelWidthStandard,
        ),
        child: cardContent,
      );
    }

    // Apply outer ambient shadow
    cardContent = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: shadows,
      ),
      child: cardContent,
    );

    // Cache raster representation to keep scrolling at buttery-smooth 60/120fps
    cardContent = RepaintBoundary(child: cardContent);

    // Wrap with tap gesture and scale interaction if interactive
    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
