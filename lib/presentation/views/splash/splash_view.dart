import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final authVm = context.read<AuthViewModel>();
    await authVm.initSession();

    // Short graceful pause for animation fluidity
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    if (authVm.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo Mark
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    AppColors.emeraldLight,
                    AppColors.emeraldDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.all_inclusive_rounded,
                size: 44,
                color: Colors.white,
              ),
            )
            .animate()
            .scale(duration: 600.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Product Name
            Text(
              'Kith',
              style: AppTypography.displayHero(isDark: isDark),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Effortless group money for trips & friends',
              style: AppTypography.bodyMedium(isDark: isDark),
            )
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
