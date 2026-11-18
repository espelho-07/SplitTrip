import 'package:flutter/material.dart';

/// Semantic colors and optical glass tokens for the Liquid Glass Design System.
/// Preserves existing brand identity (Deep Teal-Emerald) while adding layered optical depth.
abstract final class GlassColors {
  // --- Brand Colors ---
  static const Color brandPrimary = Color(0xFF0F766E); // Deep Teal-Emerald
  static const Color brandLight = Color(0xFF14B8A6);   // Luminous Mint
  static const Color brandDark = Color(0xFF0D534D);    // Deep Forest
  static const Color brandContainer = Color(0xFFCCFBF1);
  static const Color brandGlow = Color(0x3314B8A6);
  static const Color brandGlowStrong = Color(0x6614B8A6);

  // --- Semantic Accents ---
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentIce = Color(0xFF38BDF8);

  // --- Financial Directional Semantics ---
  static const Color positiveGreenLight = Color(0xFF059669);
  static const Color positiveGreenDark = Color(0xFF34D399);
  static const Color negativeRedLight = Color(0xFFDC2626);
  static const Color negativeRedDark = Color(0xFFF87171);

  static Color positive(bool isDark) => isDark ? positiveGreenDark : positiveGreenLight;
  static Color negative(bool isDark) => isDark ? negativeRedDark : negativeRedLight;

  // --- Solid Canvas Foundations ---
  static const Color darkCanvas = Color(0xFF080C0E);        // True Deep Obsidian Canvas
  static const Color darkSurfaceCard = Color(0xFF0F1418);   // Deep Graphite Surface Card
  static const Color darkSurfaceSubtle = Color(0xFF161D24); // Tactile Inner Container
  static const Color darkSurfaceElevated = Color(0xFF1E2630);// Elevated Modals & Sheets

  static const Color lightCanvas = Color(0xFFF7F7F5);       // Crisp Off-White Foundation
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);  // Pure White Card
  static const Color lightSurfaceSubtle = Color(0xFFEFEFEA);// Soft Inner Container
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  // --- Liquid Glass Surface Tints ---
  static const Color darkGlassBackground = Color(0x26111827); // 15% opacity Slate-900
  static const Color darkGlassCard = Color(0x331F2937);       // 20% opacity Gray-800
  static const Color darkGlassFloating = Color(0x4D1E293B);   // 30% opacity Slate-800
  static const Color darkGlassModal = Color(0xE60F172A);      // 90% opacity Slate-900

  static const Color lightGlassBackground = Color(0x66FFFFFF); // 40% opacity White
  static const Color lightGlassCard = Color(0x80FFFFFF);       // 50% opacity White
  static const Color lightGlassFloating = Color(0xB3FFFFFF);   // 70% opacity White
  static const Color lightGlassModal = Color(0xF2FFFFFF);      // 95% opacity White

  // --- Specular Bevel Gradients (10th-Power Bevel Simulation) ---
  static const LinearGradient darkBevelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x4DFFFFFF), // 30% white specular sheen (top-left)
      Color(0x14FFFFFF), // 8% white mid-tone
      Color(0x05FFFFFF), // 2% shadow transition
      Color(0x1A000000), // 10% black bottom-right
    ],
    stops: [0.0, 0.35, 0.75, 1.0],
  );

  static const LinearGradient lightBevelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x99FFFFFF), // 60% white specular sheen
      Color(0x33FFFFFF), // 20% white mid-tone
      Color(0x1A000000), // 10% black shadow
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // --- Border Highlights ---
  static const Color darkBorderSubtle = Color(0x1FFFFFFF);  // 12% White
  static const Color darkBorderStrong = Color(0x33FFFFFF);  // 20% White
  static const Color lightBorderSubtle = Color(0x0F000000); // 6% Black
  static const Color lightBorderStrong = Color(0x1F000000); // 12% Black

  // --- Typography Colors ---
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9EADC0);
  static const Color darkTextMuted = Color(0xFF6C7F93);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}
