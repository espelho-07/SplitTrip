import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../../core/services/permission_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import '../language/language_select_sheet.dart';
import 'interactive_tutorial_sheet.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _recoveryKeyController = TextEditingController();
  bool _showRecoveryField = false;
  AppExperienceMode _selectedMode = AppExperienceMode.tripsOnly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestInitialPermissions();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();
    final success = await AuthProgressDialog.startGoogleSignIn(context);
    if (success == true && mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleStart() async {
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;
    if (authVm.isLoading) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrNameRequired)),
      );
      return;
    }

    HapticHelper.medium();
    await authVm.createGuestSession(name, _selectedMode);
    if (mounted) {
      context.go('/home');
      KithSuccessToast.show(context, l10n.onboardingWelcomeToast);
    }
  }

  Future<void> _handleRecover() async {
    final authVm = context.read<AuthViewModel>();
    final l10n = context.l10n;
    if (authVm.isLoading) return;

    final key = _recoveryKeyController.text.trim().toUpperCase();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingErrRecoveryRequired)),
      );
      return;
    }

    HapticHelper.medium();

    final stageNotifier = ValueNotifier<int>(0);
    final stages = [
      ProgressStage(label: l10n.statusRestoring, description: l10n.authRecoveryKey),
      ProgressStage(label: l10n.statusSyncing, description: l10n.authGoogleConnected),
      ProgressStage(label: l10n.statusSaved, description: l10n.tripsBalances),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => ValueListenableBuilder<int>(
        valueListenable: stageNotifier,
        builder: (ctx, activeStage, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: KithStageProgress(
                title: l10n.onboardingRestoringDialog,
                stages: stages,
                currentStageIndex: activeStage,
              ),
            ),
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) stageNotifier.value = 1;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) stageNotifier.value = 2;
    });

    final user = await authVm.recoverSession(key);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

      if (user != null) {
        final homeVm = context.read<HomeViewModel>();
        final personalVm = context.read<PersonalExpenseViewModel>();
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);
        if (mounted) {
          context.go('/home');
          KithSuccessToast.show(context, '${l10n.onboardingWelcomeBack}, ${user.displayName} ✓');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onboardingErrRecoveryFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Header Brand Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.tabTrips,
                          style: AppTypography.badgeText(
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.translate_rounded, size: 14, color: AppColors.emeraldPrimary),
                        label: Text(
                          context.watch<LocaleViewModel>().currentLanguage.nativeName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                        ),
                        onPressed: () => LanguageSelectSheet.show(context),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.help_outline_rounded, size: 14, color: AppColors.emeraldPrimary),
                        label: Text(
                          l10n.onboardingQuickTour,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                        ),
                        onPressed: () => InteractiveTutorialSheet.show(context),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                l10n.onboardingHeroTitle,
                style: AppTypography.displayHero(isDark: isDark),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: 5),

              // Brand credit
              Text(
                l10n.onboardingBrandCredit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                      .withValues(alpha: 0.65),
                ),
              ).animate().fadeIn(delay: 220.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                l10n.onboardingHeroDesc,
                style: AppTypography.bodyLarge(isDark: isDark),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.xxl),

              // Feature Highlights
              _buildFeatureRow(
                icon: Icons.mic_none_rounded,
                title: l10n.onboardingFeatureVoiceTitle,
                subtitle: l10n.onboardingFeatureVoiceSub,
                isDark: isDark,
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.calculate_outlined,
                title: l10n.onboardingFeatureMathTitle,
                subtitle: l10n.onboardingFeatureMathSub,
                isDark: isDark,
              ).animate().fadeIn(delay: 450.ms),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.bolt_outlined,
                title: l10n.onboardingFeatureDebtTitle,
                subtitle: l10n.onboardingFeatureDebtSub,
                isDark: isDark,
              ).animate().fadeIn(delay: 550.ms),

              const SizedBox(height: AppSpacing.xxl),

              // PRIMARY AUTH: Continue with Google Card
              SurfaceCard(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.g_mobiledata_rounded, size: 24, color: AppColors.emeraldPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.onboardingPrimarySignin, style: AppTypography.titleSmall(isDark: isDark)),
                              Text(l10n.onboardingSyncDevices, style: AppTypography.bodySmall(isDark: isDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      text: l10n.onboardingGoogleSignin,
                      icon: Icons.g_mobiledata_rounded,
                      isFullWidth: true,
                      isLoading: authVm.isLoading,
                      onPressed: _handleGoogleSignIn,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: AppSpacing.lg),

              // OR DIVIDER
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.onboardingOrGuest,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Name Input Card
              SurfaceCard(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingGuestName,
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.onboardingGuestDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: l10n.onboardingNameHint,
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      onSubmitted: (_) => _handleStart(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // App Experience Mode Selection
                    Text(
                      l10n.onboardingModeSelect,
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profileSecExperience,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Option 1: Trips & Group Splitting Only
                    InkWell(
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _selectedMode = AppExperienceMode.tripsOnly);
                      },
                      borderRadius: AppRadius.mdBorder,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedMode == AppExperienceMode.tripsOnly
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                          borderRadius: AppRadius.mdBorder,
                          border: Border.all(
                            color: _selectedMode == AppExperienceMode.tripsOnly
                                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                            width: _selectedMode == AppExperienceMode.tripsOnly ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('✈️', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.onboardingModeTripsOnly,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.onboardingModeTripsSub,
                                    style: AppTypography.bodySmall(isDark: isDark),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedMode == AppExperienceMode.tripsOnly)
                              const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Option 2: Both Trips & Personal Expenses
                    InkWell(
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _selectedMode = AppExperienceMode.all);
                      },
                      borderRadius: AppRadius.mdBorder,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedMode == AppExperienceMode.all
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                          borderRadius: AppRadius.mdBorder,
                          border: Border.all(
                            color: _selectedMode == AppExperienceMode.all
                                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                            width: _selectedMode == AppExperienceMode.all ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('💼', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.onboardingModeAll,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.onboardingModeAllSub,
                                    style: AppTypography.bodySmall(isDark: isDark),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedMode == AppExperienceMode.all)
                              const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      text: l10n.onboardingGuestStart,
                      icon: Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.secondary,
                      isFullWidth: true,
                      isLoading: authVm.isLoading,
                      onPressed: _handleStart,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: AppSpacing.lg),

              // FALLBACK: Recovery Key Toggle
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showRecoveryField = !_showRecoveryField;
                    });
                  },
                  icon: const Icon(Icons.key_rounded, size: 16),
                  label: Text(
                    _showRecoveryField ? l10n.onboardingRecoveryHide : l10n.onboardingRecoveryPrompt,
                    style: TextStyle(
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              if (_showRecoveryField) ...[
                const SizedBox(height: AppSpacing.sm),
                SurfaceCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dialogRestoreTitle,
                        style: AppTypography.titleSmall(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.onboardingRecoveryDesc,
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _recoveryKeyController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: l10n.onboardingRecoveryInputHint,
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: l10n.onboardingRestoreBtn,
                        variant: AppButtonVariant.secondary,
                        isFullWidth: true,
                        isLoading: authVm.isLoading,
                        onPressed: _handleRecover,
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
              ],

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            borderRadius: AppRadius.mdBorder,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall(isDark: isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
