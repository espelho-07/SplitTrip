import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/kith_brand.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';

/// Full-screen Language Selection screen presented on first-time launch.
class LanguageSelectView extends StatefulWidget {
  final bool isFromSettings;

  const LanguageSelectView({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<LanguageSelectView> createState() => _LanguageSelectViewState();
}

class _LanguageSelectViewState extends State<LanguageSelectView> {
  late AppLanguage _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = context.read<LocaleViewModel>().currentLanguage;
  }

  void _onLanguageSelected(AppLanguage lang) {
    HapticHelper.selection();
    setState(() {
      _selectedLanguage = lang;
    });
    // Immediately update the app's reactive locale so preview updates live
    context.read<LocaleViewModel>().setLanguage(lang);
  }

  Future<void> _handleContinue() async {
    HapticHelper.medium();
    final localeVm = context.read<LocaleViewModel>();
    final authVm = context.read<AuthViewModel>();

    await localeVm.setLanguage(_selectedLanguage);
    await localeVm.markInitialLanguageSelected();

    if (!mounted) return;

    if (widget.isFromSettings) {
      Navigator.of(context).pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      if (authVm.isAuthenticated) {
        context.go('/home');
      } else {
        await authVm.createGuestSession('Traveler');
        if (mounted) context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Brand logo & Back button (if from settings)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KithLogoMark(size: 36, isDark: isDark),
                  if (widget.isFromSettings)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Header Title
              Text(
                l10n.languageSelectTitle,
                style: AppTypography.titleLarge(isDark: isDark).copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: AppSpacing.xs),

              // Subtitle
              Text(
                l10n.languageSelectSubtitle,
                style: AppTypography.bodyLarge(isDark: isDark).copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

              const SizedBox(height: AppSpacing.xxl),

              // Language Cards List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: AppLanguage.values.map((lang) {
                    final isSelected = _selectedLanguage == lang;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: InkWell(
                        onTap: () => _onLanguageSelected(lang),
                        borderRadius: AppRadius.mdBorder,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.emeraldPrimary.withValues(alpha: 0.15)
                                    : AppColors.emeraldPrimary.withValues(alpha: 0.08))
                                : (isDark
                                    ? AppColors.darkSurfaceCard
                                    : AppColors.lightSurfaceCard),
                            borderRadius: AppRadius.mdBorder,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.emeraldPrimary
                                  : (isDark ? Colors.white10 : Colors.black12),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              // Flag / Icon Badge
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                ),
                                child: Center(
                                  child: Text(
                                    lang.flagEmoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),

                              // Language Names
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.nativeName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.englishName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Checkmark indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.emeraldPrimary : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.emeraldPrimary
                                        : (isDark ? Colors.white24 : Colors.black26),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Bottom Action Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: AppButton(
                  text: l10n.languageContinue,
                  isFullWidth: true,
                  variant: AppButtonVariant.primary,
                  onPressed: _handleContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
