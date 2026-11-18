import 'package:flutter/material.dart';

/// Animation motion curves and durations for Liquid Glass Design System.
/// Supports automated zero-duration reduction when reduced-motion is requested.
abstract final class GlassMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 380);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.elasticOut;
  static const Curve decelerateCurve = Curves.decelerate;

  /// Returns effective duration respecting reduced-motion accessibility preference.
  static Duration responsive(Duration duration, {required bool reduceMotion}) {
    return reduceMotion ? Duration.zero : duration;
  }
}
