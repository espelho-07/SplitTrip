import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_colors.dart';

/// Typography tokens for Liquid Glass Design System.
/// Uses Plus Jakarta Sans with full multi-script fallbacks and strict tabular numeral enforcement.
abstract final class GlassTypography {
  static const List<String> _fontFallbacks = [
    'Noto Sans',
    'Noto Sans Devanagari',
    'Noto Sans Tamil',
    'Noto Sans Telugu',
    'Noto Sans Kannada',
    'Noto Sans Bengali',
    'Noto Sans Gurmukhi',
    'Noto Sans Oriya',
    'Noto Sans Malayalam',
    'Noto Sans SC',
    'Noto Sans JP',
    'Noto Sans KR',
    'Roboto',
    'sans-serif',
  ];

  // --- Display & Hero ---
  static TextStyle displayHero({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.15,
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleLarge({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleMedium({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleSmall({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Body Copy ---
  static TextStyle bodyLarge({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.45,
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodyMedium({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.4,
    color: color ?? (isDark ? GlassColors.darkTextSecondary : GlassColors.lightTextSecondary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodySmall({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.35,
    color: color ?? (isDark ? GlassColors.darkTextMuted : GlassColors.lightTextMuted),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Tabular Financial Numerals (Zero-Jitter Amounts) ---
  static TextStyle moneyHero({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneyLarge({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneyMedium({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneySmall({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? GlassColors.darkTextPrimary : GlassColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Labels & Caps ---
  static TextStyle labelCaps({required bool isDark, Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: color ?? (isDark ? GlassColors.darkTextMuted : GlassColors.lightTextMuted),
  ).copyWith(fontFamilyFallback: _fontFallbacks);
}
