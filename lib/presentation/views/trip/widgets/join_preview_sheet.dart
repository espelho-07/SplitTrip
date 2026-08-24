import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/trip_preview.dart';

class JoinPreviewSheet extends StatelessWidget {
  final TripPreview preview;
  final bool isJoining;
  final VoidCallback onConfirmJoin;
  final VoidCallback onCancel;

  const JoinPreviewSheet({
    super.key,
    required this.preview,
    required this.isJoining,
    required this.onConfirmJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: AppRadius.topSheetBorder,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Trip Icon & Title Header
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                borderRadius: AppRadius.lgBorder,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                preview.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            preview.name,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 4),

          Text(
            'Created by ${preview.creatorName}',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(isDark: isDark).copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info Card
          SurfaceCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.people_outline,
                  label: 'Members',
                  value: '${preview.memberCount}',
                  isDark: isDark,
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Currency',
                  value: preview.currencyCode,
                  isDark: isDark,
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.tag,
                  label: 'Code',
                  value: preview.inviteCode,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Actions
          AppButton(
            text: 'Join Trip',
            isLoading: isJoining,
            isFullWidth: true,
            icon: Icons.check,
            onPressed: () {
              HapticHelper.medium();
              onConfirmJoin();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            text: 'Cancel',
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () {
              HapticHelper.light();
              onCancel();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.titleMedium(isDark: isDark),
        ),
      ],
    );
  }
}
