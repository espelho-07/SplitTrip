import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../viewmodels/auth_viewmodel.dart';

class InteractiveTutorialSheet extends StatefulWidget {
  final VoidCallback? onComplete;

  const InteractiveTutorialSheet({super.key, this.onComplete});

  static Future<void> show(BuildContext context, {VoidCallback? onComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InteractiveTutorialSheet(onComplete: onComplete),
    );
  }

  @override
  State<InteractiveTutorialSheet> createState() => _InteractiveTutorialSheetState();
}

class _InteractiveTutorialSheetState extends State<InteractiveTutorialSheet> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Your money, simplified.',
      'subtitle': 'Track everyday spending, categories, and personal budgets without spreadsheets or clutter.',
      'icon': Icons.account_balance_wallet_rounded,
      'color': AppColors.emeraldPrimary,
      'badge': 'PERSONAL FINANCES',
      'highlight': 'Switch between Personal and Trips anytime from the bottom bar.',
    },
    {
      'title': 'Split trips effortlessly.',
      'subtitle': 'Create a trip, invite friends with 6-character codes or QR, and let Kith calculate minimal repayments.',
      'icon': Icons.flight_takeoff_rounded,
      'color': AppColors.indigoAccent,
      'badge': 'GROUP TRAVEL & LEDGERS',
      'highlight': 'Zero-confusion debt simplification algorithm built-in.',
    },
    {
      'title': 'Add expenses your way.',
      'subtitle': 'Type an expense, speak it naturally in English/Hindi, or capture a receipt with instant AI OCR.',
      'icon': Icons.mic_none_rounded,
      'color': AppColors.amberAccent,
      'badge': 'INTELLIGENT INPUT',
      'highlight': 'Voice draft preview lets you confirm amounts before saving.',
    },
    {
      'title': 'Never lose your data.',
      'subtitle': 'Sign in with Google to sync seamlessly across devices, or keep your Recovery Key safe as a backup.',
      'icon': Icons.cloud_sync_rounded,
      'color': AppColors.emeraldPrimary,
      'badge': 'CLOUD & RECOVERY',
      'highlight': 'Works 100% offline and automatically syncs when online.',
    },
    {
      'title': "You're all set!",
      'subtitle': 'Create your first trip or track an expense today with total confidence.',
      'icon': Icons.all_inclusive_rounded,
      'color': AppColors.emeraldPrimary,
      'badge': 'READY TO GO',
      'highlight': 'Tap + to record your first transaction.',
    },
  ];

  Future<void> _finishTutorial() async {
    HapticHelper.success();
    final authVm = context.read<AuthViewModel>();
    await authVm.setOnboardingCompleted(true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete?.call();
    }
  }

  void _nextStep() {
    HapticHelper.selection();
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Top Bar: Step indicator & Skip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (step['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'STEP ${_currentStep + 1} OF ${_steps.length} • ${step['badge']}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: step['color'] as Color,
                    ),
                  ),
                ),
                if (!isLast)
                  TextButton(
                    onPressed: _finishTutorial,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip Tour',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Step Icon Graphic
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (step['color'] as Color).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step['icon'] as IconData,
                  size: 36,
                  color: step['color'] as Color,
                ),
              ),
            ).animate(key: ValueKey(_currentStep)).scale(duration: 300.ms, curve: Curves.easeOutBack),

            const SizedBox(height: AppSpacing.lg),

            // Title & Subtitle
            Text(
              step['title'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ).animate(key: ValueKey('title_$_currentStep')).fadeIn(duration: 250.ms),

            const SizedBox(height: AppSpacing.sm),

            Text(
              step['subtitle'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ).animate(key: ValueKey('sub_$_currentStep')).fadeIn(duration: 250.ms),

            const SizedBox(height: AppSpacing.lg),

            // Interactive Coachmark Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                borderRadius: AppRadius.mdBorder,
                border: Border.all(
                  color: (step['color'] as Color).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: step['color'] as Color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step['highlight'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(key: ValueKey('hl_$_currentStep')).fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: AppSpacing.xl),

            // Progress Dots & Next Button
            Row(
              children: [
                // Dots
                Row(
                  children: List.generate(_steps.length, (index) {
                    final isActive = index == _currentStep;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: isActive ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (step['color'] as Color)
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                // Next / Get Started Button
                AppButton(
                  text: isLast ? 'Get Started' : 'Next',
                  icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  onPressed: _nextStep,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
