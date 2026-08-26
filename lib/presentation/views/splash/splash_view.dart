import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  bool _showStatus = false;
  String _statusText = '';

  // Minimum time the splash is shown — guarantees brand impression
  // even when initSession() resolves instantly.
  static const _minSplashMs = 1400;

  // If init takes longer than this, surface a subtle status line
  static const _statusTriggerMs = 600;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final authVm = context.read<AuthViewModel>();
    final stopwatch = Stopwatch()..start();

    // Surface a subtle "Restoring account…" hint after 600 ms —
    // only if init hasn't resolved yet.
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

    // Init — reads only local cache, should be near-instant.
    // 4-second hard timeout so a corrupted pref file can't hang the app.
    try {
      await authVm.initSession().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Fallback: proceed to onboarding with whatever cached state exists
    }

    // Ignore status future — fire-and-forget
    unawaited(statusTimer);

    // Honour minimum splash duration so brand actually registers
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < _minSplashMs) {
      await Future<void>.delayed(Duration(milliseconds: _minSplashMs - elapsed));
    }

    if (!mounted) return;

    // Dismiss any lingering status
    if (_showStatus) setState(() => _showStatus = false);

    // Small fade-out buffer before routing
    // Prompt essential permissions on launch
    try {
      await PermissionService.requestInitialPermissions();
    } catch (_) {}

    if (!mounted) return;

    final localeVm = context.read<LocaleViewModel>();

    if (!localeVm.hasSelectedInitialLanguage) {
      context.go('/language-select');
    } else if (authVm.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    // Timings — scaled to zero when system prefers reduced motion
    final t = reduceMotion ? 0 : 1;
    final logoDelay     = (150 * t).ms;
    final logoFade      = (420 * t + (reduceMotion ? 0 : 1)).ms;
    final wordmarkDelay = (380 * t).ms;
    final wordmarkFade  = (380 * t + (reduceMotion ? 0 : 1)).ms;
    final bylineDelay   = (620 * t).ms;
    final bylineFade    = (340 * t + (reduceMotion ? 0 : 1)).ms;

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
        body: SafeArea(
          child: Stack(
            children: [
              // ─── Main brand lockup ───────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo mark
                    KithLogoMark(size: 76, isDark: isDark)
                        .animate()
                        .fadeIn(delay: logoDelay, duration: logoFade, curve: Curves.easeOut)
                        .scale(
                          delay: logoDelay,
                          duration: logoFade,
                          begin: const Offset(0.88, 0.88),
                          end: const Offset(1.0, 1.0),
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 22),

                    // "Kith" wordmark
                    _WordmarkText(isDark: isDark)
                        .animate()
                        .fadeIn(delay: wordmarkDelay, duration: wordmarkFade, curve: Curves.easeOut)
                        .slideY(
                          delay: wordmarkDelay,
                          duration: wordmarkFade,
                          begin: 0.18,
                          end: 0.0,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 8),

                    // "by Nirniq" creator credit
                    _BylineText(isDark: isDark)
                        .animate()
                        .fadeIn(delay: bylineDelay, duration: bylineFade, curve: Curves.easeOut),
                  ],
                ),
              ),

              // ─── Subtle status line ──────────────────────────────────────
              // Only appears if init takes noticeably long (> 600 ms).
              // Positioned near the bottom so it doesn't interfere with brand.
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
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets — isolated so they can be const-constructed
// ─────────────────────────────────────────────────────────────────────────────

class _WordmarkText extends StatelessWidget {
  final bool isDark;
  const _WordmarkText({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Kith',
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        package: 'google_fonts',
        fontSize: 46,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
        height: 1.0,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }
}

class _BylineText extends StatelessWidget {
  final bool isDark;
  const _BylineText({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      'by Nirniq',
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        package: 'google_fonts',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        height: 1.0,
        color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
            .withValues(alpha: 0.72),
      ),
    );
  }
}

// Silence linter for fire-and-forget future
void unawaited(Future<void> future) {}