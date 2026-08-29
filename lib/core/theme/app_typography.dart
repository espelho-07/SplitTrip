import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Refined typographic hierarchy for Kith.
/// Uses Plus Jakarta Sans geometric sans for crisp modern reading and
/// monospaced/tabular numerals for financial precision.
class AppTypography {
  AppTypography._();

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
  static TextStyle displayHero({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.15,
    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleLarge({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.25,
    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleMedium({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle titleSmall({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Body Copy ---
  static TextStyle bodyLarge({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.5,
    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodyMedium({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.45,
    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodySmall({required bool isDark}) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Financial Figures & Tabular Amounts ---
  static TextStyle moneyHero({required bool isDark, Color? overrideColor}) => GoogleFonts.plusJakartaSans(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: overrideColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneyLarge({required bool isDark, Color? overrideColor}) => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: overrideColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneyMedium({required bool isDark, Color? overrideColor}) => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: overrideColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle moneySmall({required bool isDark, Color? overrideColor}) => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: overrideColor ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  // --- Badges, Buttons & Labels ---
  static TextStyle buttonText({Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: color ?? Colors.white,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle badgeText({Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: color ?? AppColors.emeraldPrimary,
  ).copyWith(fontFamilyFallback: _fontFallbacks);
}
