import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../../core/services/google_auth_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/progress.dart';
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
  void dispose() {
    _nameController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();

    GoogleAuthResult? googleResult;

    try {
      googleResult = await GoogleAuthService.signIn();
      if (googleResult == null) return; // User cancelled — silent no-op
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      switch (e.failure) {
        case GoogleSignInFailure.cancelled:
          return;
        case GoogleSignInFailure.networkError:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        case GoogleSignInFailure.signInFailed:
        case GoogleSignInFailure.supabaseError:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!mounted) return;

    final stageNotifier = ValueNotifier<int>(0);
    final stages = const [
      ProgressStage(label: 'Signing in with Google', description: 'Contacting Google identity provider'),
      ProgressStage(label: 'Verifying account', description: 'Checking canonical ledger profile'),
      ProgressStage(label: 'Syncing your Kith data', description: 'Restoring trips, expenses & balances'),
      ProgressStage(label: 'Account ready', description: 'Preparing your space'),
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
                title: 'Signing in…',
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
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) stageNotifier.value = 3;
    });

    final user = await authVm.signInWithGoogle(
      email: googleResult.email,
      displayName: googleResult.displayName,
      googleId: googleResult.googleId,
      photoUrl: googleResult.avatarUrl,
      supabaseUserId: googleResult.supabaseUserId,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

      if (user != null) {
        final homeVm = context.read<HomeViewModel>();
        await homeVm.loadTrips(user.id);
        if (mounted) {
          context.go('/home');
          KithSuccessToast.show(context, 'Signed in as ${user.displayName} ✓');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authVm.errorMessage ?? 'Could not complete Google Sign-In.')),
        );
      }
    }
  }

  Future<void> _handleStart() async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name or nickname to continue')),
      );
      return;
    }

    HapticHelper.medium();
    await authVm.createGuestSession(name, _selectedMode);
    if (mounted) {
      context.go('/home');
      KithSuccessToast.show(context, 'Welcome to Kith ✓');
    }
  }

  Future<void> _handleRecover() async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    final key = _recoveryKeyController.text.trim().toUpperCase();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your recovery key (e.g. KITH-XXXX-YYYY)')),
      );
      return;
    }

    HapticHelper.medium();

    final stageNotifier = ValueNotifier<int>(0);
    final stages = const [
      ProgressStage(label: 'Checking recovery code', description: 'Validating security key hash'),
      ProgressStage(label: 'Restoring identity', description: 'Resolving canonical user account'),
      ProgressStage(label: 'Syncing cloud data', description: 'Loading all trips & personal finance'),
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
                title: 'Restoring account…',
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
        await homeVm.loadTrips(user.id);
        if (mounted) {
          context.go('/home');
          KithSuccessToast.show(context, 'Welcome back, ${user.displayName} ✓');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not restore session with this key. Please check the code and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();

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
                          'Effortless Group Splitting',
                          style: AppTypography.badgeText(
                            color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 14, color: AppColors.emeraldPrimary),
                    label: const Text(
                      'Quick Tour',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                    ),
                    onPressed: () => InteractiveTutorialSheet.show(context),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Share moments.\nNot money stress.',
                style: AppTypography.displayHero(isDark: isDark),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: 5),

              // Brand credit
              Text(
                'Kith by Nirniq',
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
                'Speak expenses naturally in Hindi or English, let Kith compute deterministic splits, and settle up in one tap.',
                style: AppTypography.bodyLarge(isDark: isDark),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.xxl),

              // Feature Highlights
              _buildFeatureRow(
                icon: Icons.mic_none_rounded,
                title: 'Natural Voice Entry',
                subtitle: '"Maine 6 hazar train ke diye sabke liye"',
                isDark: isDark,
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.calculate_outlined,
                title: 'Deterministic Math Engine',
                subtitle: 'Zero floating-point inaccuracies or penny leaks',
                isDark: isDark,
              ).animate().fadeIn(delay: 450.ms),

              const SizedBox(height: AppSpacing.md),

              _buildFeatureRow(
                icon: Icons.bolt_outlined,
                title: 'Simplified Debt Graph',
                subtitle: 'Minimizes settlement transactions between friends',
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
                              Text('Primary Sign-In', style: AppTypography.titleSmall(isDark: isDark)),
                              Text('Sync your Kith account across devices', style: AppTypography.bodySmall(isDark: isDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      text: 'Continue with Google',
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
                      'OR START AS GUEST',
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
                      'What should your friends call you?',
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No passwords or phone numbers required to start.',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Darpan or Alex',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      onSubmitted: (_) => _handleStart(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // App Experience Mode Selection
                    Text(
                      'What would you like to track?',
                      style: AppTypography.titleSmall(isDark: isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can change or switch this anytime from profile settings.',
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
                                    'Trips & Group Splitting Only',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Group travel costs, shared expenses & instant settlements',
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
                                    'Trips & Personal Expenses',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Full suite: personal finance, lending/borrowing + group trips',
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
                      text: 'Start as Guest',
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
                    _showRecoveryField ? 'Hide Recovery Option' : 'Use Recovery Key',
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
                        'Restore from 12-character Code',
                        style: AppTypography.titleSmall(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your KITH-XXXX-YYYY recovery code to restore your trips on this device.',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _recoveryKeyController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'KITH-XXXX-YYYY',
                          prefixIcon: Icon(Icons.key_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Restore Session',
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
