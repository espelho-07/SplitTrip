import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../viewmodels/version_viewmodel.dart';

/// Dedicated blocking full-screen view for mandatory/breaking updates.
/// Clearly communicates requirement, guarantees zero local data loss, and offers direct store update action.
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final versionVm = context.watch<VersionViewModel>();

    return PopScope(
      canPop: false, // Strict block: cannot back-navigate out of mandatory update
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Shield Graphic
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.emeraldLight.withValues(alpha: 0.2),
                          AppColors.amberAccent.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emeraldLight.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      size: 42,
                      color: AppColors.emeraldLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.negativeRedDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.negativeRedDark.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      l10n.versionUpdateRequiredTitle.toUpperCase(),
                      style: AppTypography.badgeText(color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    l10n.versionUpdateKithBtn,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge(isDark: isDark).copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle
                  Text(
                    l10n.versionUpdateRequiredDesc,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Version Comparison Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'INSTALLED',
                              style: AppTypography.badgeText(
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ).copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v${versionVm.currentVersionString}',
                              style: AppTypography.titleMedium(isDark: isDark).copyWith(
                                fontSize: 16,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        ),
                        Column(
                          children: [
                            Text(
                              'MINIMUM REQUIRED',
                              style: AppTypography.badgeText(
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ).copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v${versionVm.minVersionString}',
                              style: AppTypography.titleMedium(isDark: isDark).copyWith(
                                fontSize: 16,
                                color: AppColors.emeraldLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Data Safety & Offline Notice Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.emeraldLight.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: AppColors.emeraldLight,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Data is 100% Safe',
                                style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                versionVm.unsyncedCount > 0
                                    ? 'You have ${versionVm.unsyncedCount} pending offline changes. All local trips and expenses are preserved safely on your device and will sync immediately after update.'
                                    : 'All your local trips, expenses, settlements, and recovery keys remain completely intact and will sync upon updating.',
                                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Offline Connectivity Warning (if offline)
                  if (versionVm.isOffline) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.amberAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.amberAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 18,
                            color: AppColors.amberAccent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Internet connection required to download update from Google Play / App Store.',
                              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                color: AppColors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // What's New / Release Notes
                  if (versionVm.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WHAT'S NEW",
                            style: AppTypography.badgeText(color: AppColors.emeraldLight).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            versionVm.releaseNotes,
                            style: AppTypography.bodySmall(isDark: isDark).copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Primary Update Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticHelper.heavy();
                        versionVm.openStore();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldLight,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_circle_up_rounded,
                            size: 22,
                            color: Colors.black,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.versionUpdateKithBtn,
                            style: AppTypography.buttonText(color: Colors.black).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
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
