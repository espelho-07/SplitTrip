import 'package:flutter/material.dart';

export 'glass_colors.dart';
export 'glass_typography.dart';
export 'glass_radii.dart';
export 'glass_spacing.dart';
export 'glass_motion.dart';

/// Master Design Tokens for Liquid Glass Design System.
abstract final class GlassTokens {
  // --- Optical Blur Levels (Impeller / Skia ImageFilter.blur) ---
  static const double blurSubtle = 8.0;
  static const double blurStandard = 16.0;
  static const double blurDense = 22.0;
  static const double blurModal = 28.0;

  // --- Bevel Border Widths ---
  static const double bevelWidthSubtle = 0.75;
  static const double bevelWidthStandard = 1.0;
  static const double bevelWidthProminent = 1.5;

  // --- Elevation Shadows ---
  static const List<BoxShadow> darkElevatedShadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x1A14B8A6), // Subtle emerald ambient hint
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lightElevatedShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
}
