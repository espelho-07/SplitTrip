import 'package:flutter/material.dart';

/// Predictable 4pt/8pt spacing scale for generous whitespace and breathing room.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double section = 40.0;
  static const double hero = 48.0;

  // Screen padding standard
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 32.0);
}
