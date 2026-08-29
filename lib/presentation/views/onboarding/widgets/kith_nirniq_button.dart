import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';

/// Premium Nirniq Ecosystem Sign-In button with custom Nirniq brand mark,
/// tactile press response, spring physics, and inline loading indicator.
class KithNirniqAuthButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const KithNirniqAuthButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<KithNirniqAuthButton> createState() => _KithNirniqAuthButtonState();
}

class _KithNirniqAuthButtonState extends State<KithNirniqAuthButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.onboardingNirniqBtn,
      child: GestureDetector(
        onTapDown: widget.isLoading ? null : (_) => setState(() => _isPressed = true),
        onTapUp: widget.isLoading
            ? null
            : (_) {
                setState(() => _isPressed = false);
                HapticHelper.medium();
                widget.onPressed?.call();
              },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Colors.white, Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: AppRadius.mdBorder,
              border: Border.all(
                color: isDark
                    ? AppColors.emeraldPrimary.withValues(alpha: 0.35)
                    : const Color(0xFF0F766E).withValues(alpha: 0.25),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppColors.emeraldPrimary : const Color(0xFF0F766E))
                      .withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.onboardingSigningInStatus,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CustomPaint(
                            painter: _NirniqBrandEmblemPainter(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.onboardingNirniqBtn,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering the sleek Nirniq Ecosystem Emblem.
class _NirniqBrandEmblemPainter extends CustomPainter {
  const _NirniqBrandEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final r = s * 0.24;

    // Branded Nirniq gradient container
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF047857), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(r),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Glowing Nirniq 'N' / Portal Geometry
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(s * 0.28, s * 0.72);
    path.lineTo(s * 0.28, s * 0.28);
    path.lineTo(s * 0.72, s * 0.72);
    path.lineTo(s * 0.72, s * 0.28);

    canvas.drawPath(path, strokePaint);

    // Orbiting Ecosystem Spark
    final sparkPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(Offset(s * 0.76, s * 0.24), s * 0.08, sparkPaint);
  }

  @override
  bool shouldRepaint(_NirniqBrandEmblemPainter oldDelegate) => false;
}
