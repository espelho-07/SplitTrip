import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';

/// Reusable "Continue with Nirniq" authentication button for Gate 2D.
///
/// Features:
/// - Prominent Nirniq ecosystem branding with underlying Google 'G' badge.
/// - Tactile press animations and haptic feedback.
/// - Integrated loading spinner and accessibility semantics.
/// - Full light / dark theme responsiveness.
class NirniqSignInButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final String? customLabel;

  const NirniqSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.customLabel,
  });

  @override
  State<NirniqSignInButton> createState() => _NirniqSignInButtonState();
}

class _NirniqSignInButtonState extends State<NirniqSignInButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final canTap = widget.isEnabled && !widget.isLoading && widget.onPressed != null;

    final String buttonLabel = widget.customLabel ?? 'Continue with Nirniq';

    return Semantics(
      button: true,
      enabled: canTap,
      label: buttonLabel,
      child: Opacity(
        opacity: widget.isEnabled ? 1.0 : 0.6,
        child: GestureDetector(
          onTapDown: canTap ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: canTap
              ? (_) {
                  setState(() => _isPressed = false);
                  HapticHelper.medium();
                  widget.onPressed?.call();
                }
              : null,
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed && canTap ? 0.98 : 1.0,
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
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFCBD5E1),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF64748B))
                        .withValues(alpha: isDark ? 0.28 : 0.08),
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
                                isDark
                                    ? AppColors.emeraldLight
                                    : AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.onboardingSigningInStatus,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
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
                              painter: _GoogleBrandGLogoPainter(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            buttonLabel,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering the iconic Google 4-color 'G' brand mark.
class _GoogleBrandGLogoPainter extends CustomPainter {
  const _GoogleBrandGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final center = Offset(s / 2, s / 2);
    final radius = s * 0.44;
    final strokeW = s * 0.20;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Red Arc (Top Left & Top Right: 210° to 330°)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -2.6, 1.9, false, redPaint);

    // 2. Yellow Arc (Bottom Left: 140° to 220°)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 2.1, 1.6, false, yellowPaint);

    // 3. Green Arc (Bottom Right & Bottom Left: 30° to 150°)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0.5, 1.8, false, greenPaint);

    // 4. Blue Arc & Crossbar
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -0.6, 1.2, false, bluePaint);

    // Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx - strokeW * 0.2,
      center.dy - strokeW / 2,
      radius + strokeW * 0.6,
      strokeW,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(_GoogleBrandGLogoPainter oldDelegate) => false;
}
