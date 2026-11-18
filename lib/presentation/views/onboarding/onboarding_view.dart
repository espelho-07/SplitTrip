import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import '../../../core/nirniq/config/nirniq_feature_flags.dart';
import '../../../core/nirniq/services/nirniq_google_auth_service.dart';
import '../../../core/nirniq/services/nirniq_identity_service_impl.dart';
import '../auth/widgets/nirniq_sign_in_button.dart';
import '../language/language_select_sheet.dart';
import 'widgets/guest_setup_sheet.dart';
import 'widgets/kith_nirniq_button.dart';
import 'widgets/kith_hero_scene.dart';
import 'widgets/recovery_key_sheet.dart';

/// Redesigned premium login and welcome experience for Kith.
///
/// Features a cinematic product introduction, layered finance & travel scene,
/// clear Nirniq Account authentication hierarchy, and 100% full localization support.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  bool _isNirniqAuthenticating = false;

  Future<void> _handleNirniqSignIn() async {
    final localeVm = context.read<LocaleViewModel>();
    if (!localeVm.hasSelectedInitialLanguage) {
      context.push('/language-select');
      return;
    }

    if (_isNirniqAuthenticating) return;

    HapticHelper.medium();
    setState(() => _isNirniqAuthenticating = true);

    try {
      final nirniqService = NirniqIdentityServiceImpl();
      final result = await nirniqService.authenticateWithNirniq();

      if (result != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        if (e is! NirniqAuthException || e.code != NirniqAuthErrorCode.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is NirniqAuthException ? e.message : 'Unable to sign in with Nirniq. Please try again.'),
              backgroundColor: AppColors.negativeRedLight,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isNirniqAuthenticating = false);
      }
    }
  }
  Future<void> _handleGoogleSignIn() async {
    final localeVm = context.read<LocaleViewModel>();
    if (!localeVm.hasSelectedInitialLanguage) {
      context.push('/language-select');
      return;
    }

    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();
    final success = await AuthProgressDialog.startGoogleSignIn(context);
    if (success == true && mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleExploreAsGuest() async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    final localeVm = context.read<LocaleViewModel>();
    if (!localeVm.hasSelectedInitialLanguage) {
      await localeVm.markInitialLanguageSelected();
    }

    if (!mounted) return;
    HapticHelper.light();
    GuestSetupSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeVm = context.watch<LocaleViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final bgColor = isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: isDark ? 0.09 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: Top Navigation Bar
                        _buildTopBar(context, localeVm, l10n, isDark)
                            .animate()
                            .fadeIn(duration: reduceMotion ? 1.ms : 350.ms),

                        const SizedBox(height: AppSpacing.md),

                        // SECTION 2: Hero Headline & Subtitle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.onboardingHeroTagline,
                              style: AppTypography.displayHero(isDark: isDark).copyWith(
                                height: 1.12,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.onboardingHeroSub,
                              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: reduceMotion ? 1.ms : 150.ms, duration: reduceMotion ? 1.ms : 400.ms)
                            .slideY(begin: reduceMotion ? 0 : 0.05, end: 0),

                        const SizedBox(height: AppSpacing.lg),

                        // SECTION 3: Visual Composition (Interactive Scene)
                        const KithHeroScene()
                            .animate()
                            .fadeIn(delay: reduceMotion ? 1.ms : 300.ms, duration: reduceMotion ? 1.ms : 450.ms)
                            .scaleXY(begin: reduceMotion ? 1 : 0.96, end: 1),

                        const SizedBox(height: AppSpacing.lg),

                        // SECTION 4: Authentication Action Deck
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Primary: Continue as Guest
                            AppButton(
                              text: l10n.onboardingGuestBtn,
                              variant: AppButtonVariant.primary,
                              isFullWidth: true,
                              isLoading: authVm.isLoading,
                              onPressed: _handleExploreAsGuest,
                            ),

                            const SizedBox(height: 12),

                            // Secondary: Recover using Kith Recovery Key
                            AppButton(
                              text: l10n.onboardingRecoveryLink,
                              variant: AppButtonVariant.secondary,
                              isFullWidth: true,
                              onPressed: () => RecoveryKeySheet.show(context),
                            ),

                            // Preserved for future reactivation: Google Sign-In
                            if (NirniqFeatureFlags.showNirniqSignInButton) ...[
                              const SizedBox(height: 12),
                              NirniqSignInButton(
                                isLoading: _isNirniqAuthenticating,
                                onPressed: _handleNirniqSignIn,
                              ),
                            ],

                            if (AppConfig.enableGoogleAuth) ...[
                              const SizedBox(height: 12),
                              KithGoogleAuthButton(
                                isLoading: authVm.isLoading,
                                onPressed: _handleGoogleSignIn,
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Trust & Privacy Note
                            Text(
                              l10n.onboardingTrustNote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                    .withValues(alpha: 0.8),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: reduceMotion ? 1.ms : 450.ms, duration: reduceMotion ? 1.ms : 400.ms)
                            .slideY(begin: reduceMotion ? 0 : 0.06, end: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    LocaleViewModel localeVm,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Mark + Tag
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KithLogoMark(size: 26, isDark: isDark),
            const SizedBox(width: 8),
            Text(
              'KITH',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),

        const SizedBox(width: 8),

        // Actions: Quick Tour + Language Pill
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Quick Tour
              Flexible(
                child: InkWell(
                  onTap: () {
                    HapticHelper.light();
                    context.push('/walkthrough');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.onboardingQuickTour,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Language Selector Pill
              InkWell(
                onTap: () {
                  HapticHelper.light();
                  LanguageSelectSheet.show(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.28),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 13,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        localeVm.currentLanguage.nativeName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
