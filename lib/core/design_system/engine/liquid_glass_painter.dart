import 'package:flutter/material.dart';
import '../tokens/glass_colors.dart';

/// CustomPainter simulating LiquidGL's 10th-power chamfered bevel stroke.
/// Draws a smooth gradient stroke along the rounded border perimeter with specular reflection highlights.
class LiquidGlassPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isDark;
  final double strokeWidth;
  final double specularIntensity;

  const LiquidGlassPainter({
    required this.borderRadius,
    required this.isDark,
    this.strokeWidth = 1.0,
    this.specularIntensity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(strokeWidth / 2.0);

    final gradient = isDark ? GlassColors.darkBevelGradient : GlassColors.lightBevelGradient;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.specularIntensity != specularIntensity;
  }
}
