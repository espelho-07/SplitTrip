import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';

class TripSyncProgressSheet extends StatefulWidget {
  const TripSyncProgressSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => const TripSyncProgressSheet(),
    );
  }

  @override
  State<TripSyncProgressSheet> createState() => _TripSyncProgressSheetState();
}

class _TripSyncProgressSheetState extends State<TripSyncProgressSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonalExpenseViewModel>();
    final progress = vm.syncProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final isCompleted = progress >= 1.0 && !vm.isSyncingTrips;

    if (isCompleted && _autoCloseTimer == null) {
      _autoCloseTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Circular Progress with percentage & icon
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Track
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
                // Active Animated Progress
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: isCompleted ? 1.0 : progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted
                          ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                          : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
                // Percentage Text or Check Icon
                if (isCompleted)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$percent%",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'SYNCING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            isCompleted ? 'Trips Synced Successfully!' : 'Syncing from Trips',
            style: AppTypography.titleMedium(isDark: isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          Text(
            vm.syncStatusText.isNotEmpty
                ? vm.syncStatusText
                : 'Importing your exact split shares from all active trips into your personal expense dashboard.',
            style: AppTypography.bodySmall(isDark: isDark),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          if (isCompleted)
            AppButton(
              text: 'Done',
              icon: Icons.done_rounded,
              isFullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                borderRadius: AppRadius.mdBorder,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emeraldPrimary),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Reconciling splits and updating monthly budget...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emeraldPrimary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
