import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../domain/models/trip.dart';

class TripQrSheet extends StatelessWidget {
  final Trip trip;

  const TripQrSheet({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inviteLink = AppConfig.buildInviteLink(trip.inviteCode);

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

          Text(
            'Invite Friends',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge(isDark: isDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Share this code or link with friends to let them join ${trip.name}.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 6-Character Join Code Card
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TRIP CODE', style: AppTypography.bodySmall(isDark: isDark)),
                    const SizedBox(height: 4),
                    Text(
                      trip.inviteCode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    HapticHelper.medium();
                    Clipboard.setData(ClipboardData(text: trip.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Trip code ${trip.inviteCode} copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Deep Link Card
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    inviteLink,
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    HapticHelper.medium();
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite link copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Close button
          AppButton(
            text: 'Done',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
