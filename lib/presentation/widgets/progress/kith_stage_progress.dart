import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'kith_inline_progress.dart';

class ProgressStage {
  final String label;
  final String? description;

  const ProgressStage({
    required this.label,
    this.description,
  });
}

/// Stage-based contextual progress component for operations with discrete steps.
/// Strictly avoids fake percentages.
class KithStageProgress extends StatelessWidget {
  final String title;
  final List<ProgressStage> stages;
  final int currentStageIndex;
  final bool isCompleted;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const KithStageProgress({
    super.key,
    required this.title,
    required this.stages,
    required this.currentStageIndex,
    this.isCompleted = false,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<ProgressStage> stages,
    required ValueNotifier<int> currentStageNotifier,
    required Future<T> Function() action,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return ValueListenableBuilder<int>(
          valueListenable: currentStageNotifier,
          builder: (ctx, activeIdx, _) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: KithStageProgress(
                  title: title,
                  stages: stages,
                  currentStageIndex: activeIdx,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          title,
          style: AppTypography.titleLarge(isDark: isDark),
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(stages.length, (index) {
          final stage = stages[index];
          final isDone = isCompleted || index < currentStageIndex;
          final isCurrent = !isCompleted && index == currentStageIndex && errorMessage == null;
          final isPending = index > currentStageIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildStageIcon(isDone, isCurrent, isPending, isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.w700 : (isDone ? FontWeight.w600 : FontWeight.w500),
                          color: isDone
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                              : isCurrent
                                  ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                      if (stage.description != null && (isCurrent || isDone)) ...[
                        const SizedBox(height: 1),
                        Text(
                          stage.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.negativeRedDark.withValues(alpha: 0.12),
              borderRadius: AppRadius.smBorder,
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.negativeRedDark, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.negativeRedDark, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              if (onRetry != null)
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
  }

  Widget _buildStageIcon(bool isDone, bool isCurrent, bool isPending, bool isDark) {
    if (isDone) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.emeraldPrimary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
    }

    if (isCurrent) {
      return const KithInlineProgress(size: 20, strokeWidth: 2.2);
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black26,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black26,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
