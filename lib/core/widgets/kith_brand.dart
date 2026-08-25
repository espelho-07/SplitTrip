import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Kith brand logo mark — a custom geometric emblem.
///
/// Renders a precise, minimal mark: two overlapping rounded squares in
/// complementary tones, forming a subtle "K" rhythm.
/// Pure Flutter — no external assets, scales perfectly on all densities.
class KithLogoMark extends StatelessWidget {
  final double size;
  final bool isDark;

  const KithLogoMark({super.key, this.size = 72, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KithMarkPainter(isDark: isDark),
      ),
    );
  }
}

class _KithMarkPainter extends CustomPainter {
  final bool isDark;
  _KithMarkPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double r = s * 0.22; // Corner radius

    // Background square — full size, primary emerald
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.emeraldPrimary, AppColors.emeraldDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(r),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Accent square — upper-right quadrant, lighter teal, offset inward
    final accentPaint = Paint()
      ..color = AppColors.emeraldLight.withValues(alpha: 0.28)
      ..blendMode = BlendMode.screen;

    final accentSize = s * 0.55;
    final accentRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s - accentSize - s * 0.04, s * 0.04, accentSize, accentSize),
      Radius.circular(r * 0.7),
    );
    canvas.drawRRect(accentRect, accentPaint);

    // "K" lettermark — drawn as two strokes for maximum sharpness
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = s * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final left = s * 0.30;
    final top = s * 0.22;
    final bottom = s * 0.78;
    final mid = (top + bottom) / 2;
    final right = s * 0.72;

    // Vertical stem of K
    canvas.drawLine(Offset(left, top), Offset(left, bottom), strokePaint);

    // Upper diagonal of K (mid → top-right)
    canvas.drawLine(Offset(left, mid), Offset(right, top), strokePaint);

    // Lower diagonal of K (mid → bottom-right)
    canvas.drawLine(Offset(left, mid), Offset(right, bottom), strokePaint);
  }

  @override
  bool shouldRepaint(_KithMarkPainter old) => old.isDark != isDark;
}

/// The complete Kith brand lockup: logo mark + wordmark + creator credit.
///
/// Hierarchy:
///   [Logo mark]
///   Kith          ← visual hero, 40sp Bold
///   by Nirniq     ← refined creator signature, 12sp, muted
class KithBrandLockup extends StatelessWidget {
  final bool isDark;
  final double logoSize;

  const KithBrandLockup({
    super.key,
    required this.isDark,
    this.logoSize = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KithLogoMark(size: logoSize, isDark: isDark),
        const SizedBox(height: 20),
        Text(
          'Kith',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.0,
            height: 1.0,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'by Nirniq',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            height: 1.0,
            color: isDark
                ? AppColors.darkTextMuted.withValues(alpha: 0.7)
                : AppColors.lightTextMuted.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}