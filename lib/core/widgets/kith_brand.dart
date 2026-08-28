import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Official Kith brand logo mark.
///
/// Renders the official high-resolution brand logo asset with support for
/// scaling, rounded clip, and smooth fallback rendering.
class KithLogoMark extends StatelessWidget {
  final double size;
  final bool isDark;
  final BorderRadius? borderRadius;

  const KithLogoMark({
    super.key,
    this.size = 72,
    required this.isDark,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.22);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.emeraldLight.withValues(alpha: 0.25),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: size * 0.15,
                  offset: Offset(0, size * 0.04),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return CustomPaint(
              size: Size(size, size),
              painter: _KithMarkPainter(isDark: isDark),
            );
          },
        ),
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
    final double r = s * 0.22;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(r),
    );
    canvas.drawRRect(bgRect, bgPaint);

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

    canvas.drawLine(Offset(left, top), Offset(left, bottom), strokePaint);
    canvas.drawLine(Offset(left, mid), Offset(right, top), strokePaint);
    canvas.drawLine(Offset(left, mid), Offset(right, bottom), strokePaint);
  }

  @override
  bool shouldRepaint(_KithMarkPainter old) => old.isDark != isDark;
}

/// The complete Kith brand lockup: official logo mark + wordmark + creator credit.
class KithBrandLockup extends StatelessWidget {
  final bool isDark;
  final double logoSize;

  const KithBrandLockup({
    super.key,
    required this.isDark,
    this.logoSize = 88,
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
