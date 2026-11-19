import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../viewmodels/version_viewmodel.dart';

/// Premium non-intrusive bottom banner signaling that an optional update is available.
class UpdateAvailableBanner extends StatelessWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final versionVm = Provider.of<VersionViewModel?>(context);
    if (versionVm == null || !versionVm.shouldShowBanner) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.emeraldLight.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Pill & Version
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: AppColors.emeraldLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.versionUpdateAvailableTitle.toUpperCase(),
                              style: AppTypography.badgeText(color: AppColors.emeraldLight).copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'v${versionVm.latestVersionString}',
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Headline
                  Text(
                    l10n.versionUpdateAvailableDesc,
                    style: AppTypography.titleSmall(isDark: isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Includes performance enhancements and sync improvements.',
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  // Expandable "What's New" section
                  if (versionVm.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () {
                        HapticHelper.selection();
                        versionVm.toggleReleaseNotesExpanded();
                      },
                      child: Row(
                        children: [
                          Text(
                            versionVm.isReleaseNotesExpanded ? "Hide What's New" : "See What's New",
                            style: AppTypography.bodySmall(isDark: isDark).copyWith(
                              color: AppColors.emeraldLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            versionVm.isReleaseNotesExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.emeraldLight,
                          ),
                        ],
                      ),
                    ),
                    if (versionVm.isReleaseNotesExpanded) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          versionVm.releaseNotes,
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Action Buttons: [ Later ] and [ Update ]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          HapticHelper.selection();
                          versionVm.dismissBanner();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          l10n.versionLaterBtn,
                          style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: versionVm.isPlayUpdateDownloading
                            ? null
                            : () {
                                HapticHelper.medium();
                                versionVm.triggerUpdate();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldLight,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: versionVm.isPlayUpdateDownloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                versionVm.isPlayUpdateDownloaded
                                    ? 'Restart & Install'
                                    : l10n.versionUpdateBtn,
                                style: AppTypography.buttonText(color: Colors.black).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
