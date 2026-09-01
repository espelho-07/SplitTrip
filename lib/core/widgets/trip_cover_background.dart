import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Metadata for selectable trip cover background themes.
class TripBackgroundTheme {
  final int id;
  final String name;
  final String emoji;
  final String description;
  final List<Color> gradientColors;

  const TripBackgroundTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.gradientColors,
  });
}

/// All available scenic artwork themes for trip hero cards and banners.
class TripBackgroundThemes {
  static const List<TripBackgroundTheme> themes = [
    TripBackgroundTheme(
      id: 0,
      name: 'Mountains',
      emoji: '🏔️',
      description: 'Alpine peaks & starlit dusk',
      gradientColors: [Color(0xFF0F766E), Color(0xFF134E4A), Color(0xFF042F2E)],
    ),
    TripBackgroundTheme(
      id: 1,
      name: 'Beach & Waves',
      emoji: '🏖️',
      description: 'Tropical sunset & ocean waves',
      gradientColors: [Color(0xFFF97316), Color(0xFFC2410C), Color(0xFF4C1D95)],
    ),
    TripBackgroundTheme(
      id: 2,
      name: 'Misty Forest',
      emoji: '🌲',
      description: 'Evergreen pines & moonlight',
      gradientColors: [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
    ),
    TripBackgroundTheme(
      id: 3,
      name: 'City Skyline',
      emoji: '🏙️',
      description: 'Modern skyscrapers & neon glow',
      gradientColors: [Color(0xFF4F46E5), Color(0xFF3730A3), Color(0xFF1E1B4B)],
    ),
    TripBackgroundTheme(
      id: 4,
      name: 'Desert Dunes',
      emoji: '🏜️',
      description: 'Warm sand dunes & roadtrip horizon',
      gradientColors: [Color(0xFFEA580C), Color(0xFF9A3412), Color(0xFF431407)],
    ),
    TripBackgroundTheme(
      id: 5,
      name: 'Cosmic Aurora',
      emoji: '🌌',
      description: 'Northern lights & constellations',
      gradientColors: [Color(0xFF7C3AED), Color(0xFF5B21B6), Color(0xFF047857)],
    ),
    TripBackgroundTheme(
      id: 6,
      name: 'Clean Minimal',
      emoji: '🎨',
      description: 'Vibrant modern mesh gradient',
      gradientColors: [Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF1E293B)],
    ),
  ];

  static TripBackgroundTheme getTheme(int index) {
    if (index < 0 || index >= themes.length) return themes.first;
    return themes[index];
  }
}

/// Dynamic, vector-drawn scenic background for Trip hero cards.
/// Renders crisp Mountains, Waves, Pines, Skylines, Dunes, and Aurora.
class TripCoverBackground extends StatelessWidget {
  final int themeIndex;
  final Widget? child;
  final double borderRadius;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const TripCoverBackground({
    super.key,
    required this.themeIndex,
    this.child,
    this.borderRadius = 18.0,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = TripBackgroundThemes.getTheme(themeIndex);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Custom vector scenic artwork painter
            Positioned.fill(
              child: CustomPaint(
                painter: _ScenicArtworkPainter(themeId: theme.id),
              ),
            ),

            // Content layer
            ?child,
          ],
        ),
      ),
    );
  }
}

class _ScenicArtworkPainter extends CustomPainter {
  final int themeId;

  _ScenicArtworkPainter({required this.themeId});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    switch (themeId) {
      case 0:
        _paintMountains(canvas, size);
        break;
      case 1:
        _paintBeachWaves(canvas, size);
        break;
      case 2:
        _paintForest(canvas, size);
        break;
      case 3:
        _paintCitySkyline(canvas, size);
        break;
      case 4:
        _paintDesertDunes(canvas, size);
        break;
      case 5:
        _paintAurora(canvas, size);
        break;
      case 6:
      default:
        _paintMinimalMesh(canvas, size);
        break;
    }
  }

  /// Theme 0: 🏔️ Mountains & Alpine Peaks
  void _paintMountains(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing Moon / Sun in sky
    final moonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.82, h * 0.28), 24, moonPaint);

    final moonCore = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.82, h * 0.28), 15, moonCore);

    // Distant soft mountains (Layer 1)
    final distantMountain = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.52)
      ..lineTo(w * 0.25, h * 0.32)
      ..lineTo(w * 0.52, h * 0.58)
      ..lineTo(w * 0.78, h * 0.26)
      ..lineTo(w, h * 0.48)
      ..lineTo(w, h)
      ..close();

    final distantPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(distantMountain, distantPaint);

    // Snow caps on distant peaks
    final distantCap = Path()
      ..moveTo(w * 0.78, h * 0.26)
      ..lineTo(w * 0.74, h * 0.34)
      ..lineTo(w * 0.78, h * 0.32)
      ..lineTo(w * 0.82, h * 0.35)
      ..close();
    final snowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(distantCap, snowPaint);

    // Foreground bold mountain ridges (Layer 2)
    final foregroundMountain = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.65)
      ..lineTo(w * 0.36, h * 0.38)
      ..lineTo(w * 0.62, h * 0.72)
      ..lineTo(w * 0.88, h * 0.44)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..close();

    final fgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foregroundMountain, fgPaint);

    // Foreground snow peak
    final fgCap = Path()
      ..moveTo(w * 0.36, h * 0.38)
      ..lineTo(w * 0.32, h * 0.48)
      ..lineTo(w * 0.36, h * 0.45)
      ..lineTo(w * 0.41, h * 0.50)
      ..close();
    canvas.drawPath(fgCap, snowPaint);

    // Ambient stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(w * 0.15, h * 0.20), 1.5, starPaint);
    canvas.drawCircle(Offset(w * 0.45, h * 0.15), 1.2, starPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.22), 1.6, starPaint);
    canvas.drawCircle(Offset(w * 0.92, h * 0.12), 1.4, starPaint);
  }

  /// Theme 1: 🏖️ Beach & Waves
  void _paintBeachWaves(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sunset Sun
    final sunPaint = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.78, h * 0.35), 28, sunPaint);

    // Wave 1: Back smooth ocean swell
    final wave1 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.58)
      ..cubicTo(w * 0.3, h * 0.45, w * 0.6, h * 0.68, w, h * 0.50)
      ..lineTo(w, h)
      ..close();
    final wave1Paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1, wave1Paint);

    // Wave 2: Middle crest
    final wave2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.72)
      ..cubicTo(w * 0.25, h * 0.60, w * 0.55, h * 0.82, w, h * 0.64)
      ..lineTo(w, h)
      ..close();
    final wave2Paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2, wave2Paint);

    // Wave 3: Foreground foam curve
    final wave3 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.84)
      ..cubicTo(w * 0.4, h * 0.74, w * 0.7, h * 0.90, w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    final wave3Paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave3, wave3Paint);

    // Foam highlights
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(wave3, foamPaint);
  }

  /// Theme 2: 🌲 Misty Pine Forest
  void _paintForest(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant misty ridge
    final ridge = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.60)
      ..cubicTo(w * 0.3, h * 0.48, w * 0.7, h * 0.65, w, h * 0.52)
      ..lineTo(w, h)
      ..close();
    final ridgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(ridge, ridgePaint);

    // Draw stylized pine trees across the horizon
    final treePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    for (double x = 10; x < w + 20; x += 22) {
      final treeHeight = (h * 0.32) + (math.sin(x) * 8);
      final treeBaseY = h * 0.95;
      final treeTopY = treeBaseY - treeHeight;

      final treePath = Path()
        ..moveTo(x, treeTopY)
        ..lineTo(x - 8, treeTopY + (treeHeight * 0.35))
        ..lineTo(x - 5, treeTopY + (treeHeight * 0.35))
        ..lineTo(x - 10, treeTopY + (treeHeight * 0.70))
        ..lineTo(x - 6, treeTopY + (treeHeight * 0.70))
        ..lineTo(x - 12, treeBaseY)
        ..lineTo(x + 12, treeBaseY)
        ..lineTo(x + 6, treeTopY + (treeHeight * 0.70))
        ..lineTo(x + 10, treeTopY + (treeHeight * 0.70))
        ..lineTo(x + 5, treeTopY + (treeHeight * 0.35))
        ..lineTo(x + 8, treeTopY + (treeHeight * 0.35))
        ..close();
      canvas.drawPath(treePath, treePaint);
    }
  }

  /// Theme 3: 🏙️ City Skyline
  void _paintCitySkyline(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant buildings
    final bldPaint1 = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(w * 0.10, h * 0.40, w * 0.12, h * 0.60), bldPaint1);
    canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.30, w * 0.14, h * 0.70), bldPaint1);
    canvas.drawRect(Rect.fromLTWH(w * 0.50, h * 0.35, w * 0.10, h * 0.65), bldPaint1);
    canvas.drawRect(Rect.fromLTWH(w * 0.70, h * 0.25, w * 0.16, h * 0.75), bldPaint1);

    // Foreground skyscrapers
    final bldPaint2 = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(w * 0.02, h * 0.55, w * 0.14, h * 0.45), bldPaint2);
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.42, w * 0.12, h * 0.58), bldPaint2);
    canvas.drawRect(Rect.fromLTWH(w * 0.38, h * 0.22, w * 0.15, h * 0.78), bldPaint2);
    // Antenna tower
    canvas.drawLine(
      Offset(w * 0.455, h * 0.22),
      Offset(w * 0.455, h * 0.12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 2,
    );

    canvas.drawRect(Rect.fromLTWH(w * 0.58, h * 0.48, w * 0.14, h * 0.52), bldPaint2);
    canvas.drawRect(Rect.fromLTWH(w * 0.82, h * 0.38, w * 0.15, h * 0.62), bldPaint2);

    // Glowing window dots
    final winPaint = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.4);
    canvas.drawRect(Rect.fromLTWH(w * 0.41, h * 0.30, 3, 3), winPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.36, 3, 3), winPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.43, h * 0.44, 3, 3), winPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.85, h * 0.46, 3, 3), winPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.90, h * 0.52, 3, 3), winPaint);
  }

  /// Theme 4: 🏜️ Desert Dunes
  void _paintDesertDunes(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant Dune
    final dune1 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.50)
      ..cubicTo(w * 0.35, h * 0.38, w * 0.65, h * 0.62, w, h * 0.42)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(dune1, Paint()..color = Colors.black.withValues(alpha: 0.22));

    // Mid Dune
    final dune2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.68)
      ..cubicTo(w * 0.45, h * 0.52, w * 0.75, h * 0.78, w, h * 0.58)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(dune2, Paint()..color = Colors.black.withValues(alpha: 0.35));

    // Foreground Ridge & Winding Road
    final dune3 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82)
      ..cubicTo(w * 0.40, h * 0.70, w * 0.70, h * 0.90, w, h * 0.74)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(dune3, Paint()..color = Colors.black.withValues(alpha: 0.48));
  }

  /// Theme 5: 🌌 Aurora
  void _paintAurora(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cosmic Aurora Ribbon 1
    final ribbon1 = Path()
      ..moveTo(0, h * 0.15)
      ..cubicTo(w * 0.30, h * 0.45, w * 0.70, h * 0.05, w, h * 0.35)
      ..lineTo(w, h * 0.65)
      ..cubicTo(w * 0.70, h * 0.35, w * 0.30, h * 0.75, 0, h * 0.45)
      ..close();

    final auroraPaint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF34D399).withValues(alpha: 0.35),
          const Color(0xFFA78BFA).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(ribbon1, auroraPaint1);

    // Mountain silhouettes in foreground
    _paintMountains(canvas, size);
  }

  /// Theme 6: 🎨 Clean Minimal Mesh
  void _paintMinimalMesh(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Smooth subtle ambient circle accents
    final orbPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.85, h * 0.30), 45, orbPaint);
    canvas.drawCircle(Offset(w * 0.20, h * 0.80), 35, orbPaint);
  }

  @override
  bool shouldRepaint(covariant _ScenicArtworkPainter oldDelegate) =>
      oldDelegate.themeId != themeId;
}
