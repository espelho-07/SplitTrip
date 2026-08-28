import 'package:flutter/material.dart';

/// Layered surface shadows and refined elevation without heavy murky artifacts.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> lightSubtle = [
    BoxShadow(
      color: const Color(0x0A000000), // 4% opacity
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> lightCard = [
    BoxShadow(
      color: const Color(0x08000000), // 3% opacity
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0x05000000), // 2% opacity
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lightFloating = [
    BoxShadow(
      color: const Color(0x12000000), // 7% opacity
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0x08000000), // 3% opacity
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> darkSubtle = [
    BoxShadow(
      color: const Color(0x33000000), // 20% deep black shadow
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> darkCard = [
    BoxShadow(
      color: const Color(0x4D000000), // 30% crisp shadow
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> darkFloating = [
    BoxShadow(
      color: const Color(0x80000000), // 50% deep float shadow
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];
}
