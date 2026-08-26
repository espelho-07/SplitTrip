import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';

/// Premium Google Sign-In button with accurate 4-color Google G emblem,
/// tactile press response, spring physics, and inline loading indicator.
class KithGoogleAuthButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const KithGoogleAuthButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<KithGoogleAuthButton> createState() => _KithGoogleAuthButtonState();
}

class _KithGoogleAuthButtonState extends State<KithGoogleAuthButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.onboardingGoogleBtn,
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                  blurRadius: 16,
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
                          width: 22,
                          height: 22,
                          child: CustomPaint(
                            painter: _GoogleGLogoPainter(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.onboardingGoogleBtn,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
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

/// Custom painter rendering the canonical Google 'G' 4-color symbol.
class _GoogleGLogoPainter extends CustomPainter {
  const _GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double center = s / 2;
    final double strokeWidth = s * 0.22;
    final double radius = (s - strokeWidth) / 2;

    final rect = Rect.fromCircle(center: Offset(center, center), radius: radius);

    // 1. Red arc (Top / Top-Left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -3.14159 * 0.75, 3.14159 * 0.55, false, redPaint);

    // 2. Yellow arc (Bottom-Left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 3.14159 * 0.75, 3.14159 * 0.50, false, yellowPaint);

    // 3. Green arc (Bottom / Bottom-Right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 3.14159 * 0.22, 3.14159 * 0.53, false, greenPaint);

    // 4. Blue arc & horizontal bar (Right / Center)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -3.14159 * 0.20, 3.14159 * 0.42, false, bluePaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(center - s * 0.05, center - strokeWidth / 2, s, center + strokeWidth / 2),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
