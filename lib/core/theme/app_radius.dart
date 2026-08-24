import 'package:flutter/material.dart';

/// Controlled radius tokens for modern, refined UI surfaces.
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 18.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlBorder = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullBorder = BorderRadius.all(Radius.circular(full));

  static const BorderRadius topSheetBorder = BorderRadius.vertical(top: Radius.circular(28.0));
}
