import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Master Cinematic Splash Opening Screen.
///
/// Features:
/// 1. Dynamic Official Logo Assembly & Ambient Aura Bloom
/// 2. Iconic 4-Pillar Sequential Animation: "CREATE. SPLIT. TRACK. SETTLE."
/// 3. Polished Wordmark & Creator Signature
/// 4. Resilient session initialization with smooth routing
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  bool _showStatus = false;
  String _statusText = '';

  // Minimum time the splash is shown — ensures user enjoys the full opening animation
  static const _minSplashMs = 2100;
  static const _statusTriggerMs = 1200;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final authVm = context.read<AuthViewModel>();
    final stopwatch = Stopwatch()..start();

    final statusTimer = Future<void>.delayed(
      const Duration(milliseconds: _statusTriggerMs),
    ).then((_) {
      if (mounted && authVm.isLoading) {
        setState(() {
          _showStatus = true;
          _statusText = 'Restoring your account…';
        });
      }
    });

    try {
      await authVm.initSession().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Fallback: proceed to onboarding
    }

    unawaited(statusTimer);

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < _minSplashMs) {
      await Future<void>.delayed(Duration(milliseconds: _minSplashMs - elapsed));
    }

    if (!mounted) return;

    if (_showStatus) setState(() => _showStatus = false);

    try {
      if (authVm.isAuthenticated) {
        context.go('/home');
      } else if (!authVm.hasCompletedOnboarding) {
        context.go('/walkthrough');
      } else {
        context.go('/onboarding');
      }
    } catch (_) {
      // In tests without full router integration, ignore navigation exceptions
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final bgColor = isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC);

    final t = reduceMotion ? 0 : 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bgColor,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bgColor,
            ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // ─── 1. Ambient Background Aura Gradients ─────────────────────
            if (isDark) ...[
              // Teal/Emerald Aura (Top-Left)
              Positioned(
                top: -100,
                left: -80,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: (800 * t).ms, curve: Curves.easeOut)
                  .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.0, 1.0), duration: (1200 * t).ms),

              // Amber/Gold Aura (Bottom-Right)
              Positioned(
                bottom: -80,
                right: -60,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: (200 * t).ms, duration: (900 * t).ms, curve: Curves.easeOut)
                  .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.0, 1.0), duration: (1200 * t).ms),
            ],

            // ─── 2. Center Cinematic Logo & Tagline Assembly ──────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Official Logo Container with Glowing Aura
                  _buildAnimatedHeroLogo(isDark, t),

                  const SizedBox(height: 24),

                  // Brand Wordmark: "Kith"
                  Text(
                    'Kith',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.2,
                      height: 1.0,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (350 * t).ms, duration: (450 * t).ms, curve: Curves.easeOut)
                      .slideY(begin: 0.25, end: 0.0, delay: (350 * t).ms, duration: (450 * t).ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 14),

                  // ─── 3. The Signature 4-Pillar Tagline: CREATE. SPLIT. TRACK. SETTLE. ───
                  _buildAnimatedPillarsTagline(isDark, t),

                  const SizedBox(height: 18),

                  // Creator Credit: "by Nirniq"
                  Text(
                    'by Nirniq',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      height: 1.0,
                      color: isDark
                          ? const Color(0xFF6C7F93).withValues(alpha: 0.85)
                          : const Color(0xFF94A3B8),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (1050 * t).ms, duration: (400 * t).ms, curve: Curves.easeOut),
                ],
              ),
            ),

            // ─── 4. Subtle Status Line (if init takes long) ───────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: AnimatedOpacity(
                opacity: _showStatus ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Center(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the animated official logo with elastic bounce, shimmer, and radial glow aura
  Widget _buildAnimatedHeroLogo(bool isDark, int t) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 36,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 28,
            offset: const Offset(4, -4),
          ),
        ],
      ),
      child: KithLogoMark(
        size: 104,
        isDark: isDark,
        borderRadius: BorderRadius.circular(26),
      ),
    )
        .animate()
        .fadeIn(delay: (100 * t).ms, duration: (600 * t).ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1.0, 1.0),
          delay: (100 * t).ms,
          duration: (750 * t).ms,
          curve: Curves.elasticOut,
        )
        .shimmer(
          delay: (850 * t).ms,
          duration: (1000 * t).ms,
          color: Colors.white.withValues(alpha: 0.4),
        );
  }

  /// Builds the sequential 4-pillar tagline: CREATE. SPLIT. TRACK. SETTLE.
  Widget _buildAnimatedPillarsTagline(bool isDark, int t) {
    final words = [
      _PillarItem(label: 'CREATE.', color: const Color(0xFF14B8A6)),
      _PillarItem(label: 'SPLIT.', color: const Color(0xFF06B6D4)),
      _PillarItem(label: 'TRACK.', color: const Color(0xFFF59E0B)),
      _PillarItem(label: 'SETTLE.', color: const Color(0xFF10B981)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418).withValues(alpha: 0.8) : const Color(0xFFF1F5F9).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < words.length; i++) ...[
            Text(
              words[i].label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? words[i].color : words[i].color.withValues(alpha: 0.95),
              ),
            )
                .animate()
                .fadeIn(
                  delay: ((500 + (i * 120)) * t).ms,
                  duration: (350 * t).ms,
                  curve: Curves.easeOut,
                )
                .slideX(
                  begin: 0.3,
                  end: 0.0,
                  delay: ((500 + (i * 120)) * t).ms,
                  duration: (350 * t).ms,
                  curve: Curves.easeOutCubic,
                ),
            if (i < words.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (450 * t).ms, duration: (400 * t).ms, curve: Curves.easeOut)
        .slideY(begin: 0.2, end: 0.0, delay: (450 * t).ms, duration: (400 * t).ms, curve: Curves.easeOutCubic);
  }
}

class _PillarItem {
  final String label;
  final Color color;

  const _PillarItem({required this.label, required this.color});
}

void unawaited(Future<void> future) {}
