import 'package:flutter/material.dart';

/// Semantic design colors and color tokens for the Kith Design System.
/// Supports true layered dark mode and calm, warm light mode.
class AppColors {
  AppColors._();

  // --- Brand Colors ---
  static const Color emeraldPrimary = Color(0xFF0F766E); // Deep Teal-Emerald
  static const Color emeraldLight = Color(0xFF14B8A6);   // Luminous Mint
  static const Color emeraldDark = Color(0xFF0D534D);    // Deep Forest
  static const Color emeraldContainer = Color(0xFFCCFBF1);
  static const Color emeraldGlow = Color(0x3314B8A6);

  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color amberAccent = Color(0xFFF59E0B);
  static const Color roseAccent = Color(0xFFF43F5E);
  static const Color violetAccent = Color(0xFF8B5CF6);

  // --- Semantic Financial Colors ---
  static const Color positiveGreenLight = Color(0xFF059669);
  static const Color positiveGreenDark = Color(0xFF34D399);
  static const Color negativeRedLight = Color(0xFFDC2626);
  static const Color negativeRedDark = Color(0xFFF87171);
  static const Color neutralPillLight = Color(0xFFF3F4F6);
  static const Color neutralPillDark = Color(0xFF1F2937);

  // --- Light Theme Palette (Calm, Warm, Crisp Off-White Foundation) ---
  static const Color lightBackground = Color(0xFFF7F7F5);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFEFEFEA);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightBorderSubtle = Color(0x0F000000); // 6% black
  static const Color lightBorderStrong = Color(0x1F000000); // 12% black
  static const Color lightTextPrimary = Color(0xFF0F172A);  // Rich Slate Black
  static const Color lightTextSecondary = Color(0xFF475569);// Slate Grey
  static const Color lightTextMuted = Color(0xFF94A3B8);    // Soft Muted

  // --- Dark Theme Palette (Obsidian Graphite Multi-layered Depth) ---
  static const Color darkBackground = Color(0xFF0D0F12);
  static const Color darkSurfaceCard = Color(0xFF16191E);
  static const Color darkSurfaceSubtle = Color(0xFF1E2229);
  static const Color darkSurfaceElevated = Color(0xFF262B34);
  static const Color darkBorderSubtle = Color(0x14FFFFFF);  // 8% white
  static const Color darkBorderStrong = Color(0x24FFFFFF);  // 14% white
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // --- Trip Gradient Palettes ---
  static const List<List<Color>> tripGradients = [
    [Color(0xFF0F766E), Color(0xFF042F2E)], // Emerald Canopy
    [Color(0xFF4338CA), Color(0xFF1E1B4B)], // Midnight Indigo
    [Color(0xFFB45309), Color(0xFF451A03)], // Sunset Amber
    [Color(0xFFBE185D), Color(0xFF500724)], // Velvet Berry
    [Color(0xFF0369A1), Color(0xFF082F49)], // Oceanic Abyss
    [Color(0xFF374151), Color(0xFF111827)], // Graphite Slate
  ];

  static List<Color> getGradient(int index) {
    return tripGradients[index % tripGradients.length];
  }
}
