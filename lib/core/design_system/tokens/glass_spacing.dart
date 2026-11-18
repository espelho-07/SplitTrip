import 'package:flutter/material.dart';

/// Spacing scale and touch-target constraints for Liquid Glass Design System.
abstract final class GlassSpacing {
  static const double micro = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double section = 40.0;

  // --- Accessibility Touch Targets (WCAG 2.2 AA) ---
  static const double minTouchTarget = 48.0;
  static const BoxConstraints touchTargetConstraints = BoxConstraints(
    minWidth: minTouchTarget,
    minHeight: minTouchTarget,
  );
}
