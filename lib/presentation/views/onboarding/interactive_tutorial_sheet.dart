import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
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

  List<Map<String, dynamic>> _buildSteps(BuildContext context) {
    final l10n = context.l10n;

    return [
      {
        'title': l10n.tutorialSlide1Title,
        'subtitle': l10n.tutorialSlide1Desc,
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.emeraldPrimary,
        'badge': l10n.tutorialBadge1,
        'highlight': l10n.tutorialSlide1Desc,
      },
      {
        'title': l10n.tutorialSlide2Title,
        'subtitle': l10n.tutorialSlide2Desc,
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.emeraldPrimary,
        'badge': l10n.tutorialBadge2,
        'highlight': l10n.tutorialSlide2Desc,
      },
      {
        'title': l10n.tutorialSlide3Title,
        'subtitle': l10n.tutorialSlide3Desc,
        'icon': Icons.flight_takeoff_rounded,
        'color': AppColors.indigoAccent,
        'badge': l10n.tutorialBadge3,
        'highlight': l10n.tutorialSlide3Desc,
      },
      {
        'title': l10n.tutorialSlide4Title,
        'subtitle': l10n.tutorialSlide4Desc,
        'icon': Icons.mic_none_rounded,
        'color': AppColors.amberAccent,
        'badge': l10n.tutorialBadge4,
        'highlight': l10n.tutorialSlide4Desc,
      },
      {
        'title': l10n.tutorialSlide5Title,
        'subtitle': l10n.tutorialSlide5Desc,
        'icon': Icons.cloud_sync_rounded,
        'color': AppColors.emeraldPrimary,
        'badge': l10n.tutorialBadge5,
        'highlight': l10n.tutorialSlide5Desc,
      },
      {
        'title': l10n.tutorialSlide6Title,
        'subtitle': l10n.tutorialSlide6Desc,
        'icon': Icons.all_inclusive_rounded,
        'color': AppColors.emeraldPrimary,
        'badge': l10n.tutorialBadge6,
        'highlight': l10n.tutorialSlide6Desc,
      },
    ];
  }

  Future<void> _finishTutorial() async {
    HapticHelper.success();
    final authVm = context.read<AuthViewModel>();
    await authVm.setOnboardingCompleted(true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete?.call();
    }
  }

  void _nextStep(int maxSteps) {
    HapticHelper.selection();
    if (_currentStep < maxSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final steps = _buildSteps(context);
    final step = steps[_currentStep];
    final isLast = _currentStep == steps.length - 1;

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
                    'STEP ${_currentStep + 1} OF ${steps.length} • ${step['badge']}',
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
                      l10n.actionSkip,
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
                  children: List.generate(steps.length, (index) {
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
                  text: isLast ? l10n.tutorialBtnGetStarted : l10n.tutorialBtnNext,
                  icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  onPressed: () => _nextStep(steps.length),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
