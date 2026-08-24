import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../viewmodels/auth_viewmodel.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _recoveryKeyController = TextEditingController();
  bool _showRecoveryField = false;

  @override
  void dispose() {
    _nameController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name or nickname to continue')),
      );
      return;
    }

    final authVm = context.read<AuthViewModel>();
    await authVm.createGuestSession(name);
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleRecover() async {
    final key = _recoveryKeyController.text.trim();
    if (key.isEmpty) return;

    final authVm = context.read<AuthViewModel>();
    final user = await authVm.recoverSession(key);
    if (mounted) {
      if (user != null) {
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid recovery key. Please check and try again.')),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withOpacity(0.12),
                  borderRadius: AppRadius.fullBorder,
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
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Share moments.\nNot money stress.',
                style: AppTypography.displayHero(isDark: isDark),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

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
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Darpan or Alex',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      onSubmitted: (_) => _handleStart(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      text: 'Get Started',
                      icon: Icons.arrow_forward_rounded,
                      isFullWidth: true,
                      isLoading: authVm.isLoading,
                      onPressed: _handleStart,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: AppSpacing.lg),

              // Recovery Key Toggle
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showRecoveryField = !_showRecoveryField;
                    });
                  },
                  child: Text(
                    _showRecoveryField ? 'Hide Recovery Option' : 'Have a recovery key? Restore account',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                    children: [
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
