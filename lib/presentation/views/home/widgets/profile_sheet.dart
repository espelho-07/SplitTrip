import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../data/services/sync_service.dart';
import '../../../../domain/enums/app_experience_mode.dart';
import '../../../router/app_router.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/locale_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../../widgets/progress/progress.dart';
import '../../cloud/cloud_sync_sheet.dart';
import '../../language/language_select_sheet.dart';
import '../../onboarding/interactive_tutorial_sheet.dart';
import '../../settings/widgets/beta_feedback_sheet.dart';

class ProfileSheet extends StatelessWidget {
  final VoidCallback? onSwitchToTrips;
  final void Function(BuildContext)? onShowRestoreAccount;

  const ProfileSheet({
    super.key,
    this.onSwitchToTrips,
    this.onShowRestoreAccount,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSwitchToTrips,
    void Function(BuildContext)? onShowRestoreAccount,
  }) {
    HapticHelper.light();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileSheet(
        onSwitchToTrips: onSwitchToTrips,
        onShowRestoreAccount: onShowRestoreAccount,
      ),
    );
  }

  Future<void> _handleNirniqSignIn(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();
    final success = await AuthProgressDialog.startNirniqSignIn(context);
    if (success && context.mounted) {
      Navigator.of(context).pop(); // Close profile sheet on successful sign-in
    }
  }

  void _showSignOutDialog(BuildContext context) async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final storage = context.read<LocalStorageService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.authSignOutTitle),
        content: Text(l10n.authSignOutDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.authSignOutConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Dismiss profile sheet and navigate to onboarding immediately
      nav.pop();
      AppRouter.router.go('/onboarding');

      await authVm.logout();
      await storage.clearAllUserData();
      homeVm.clearData();
      personalVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, l10n.authSignOutSuccess);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final storage = context.read<LocalStorageService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.profileDeleteDialogTitle),
        content: Text(l10n.profileDeleteDialogDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negativeRedDark),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.profileDeleteConfirmBtn),
          ),
        ],
      ),
    );

    if (confirm == true) {
      nav.pop();
      AppRouter.router.go('/onboarding');

      await authVm.deleteAccount();
      await storage.clearAllUserData();
      homeVm.clearData();
      personalVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, l10n.profileDeleteSuccess);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final localeVm = context.watch<LocaleViewModel>();
    final syncService = context.watch<SyncService>();
    final l10n = context.l10n;
    final user = authVm.currentUser;
    final displayName = user?.displayName ?? 'Traveler';
    final isNirniqLinked = user?.isNirniqLinked ?? false;
    final pendingCount = syncService.pendingCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 1.2,
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorderSubtle : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                borderRadius: AppRadius.lgBorder,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  MemberAvatar(name: displayName, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTypography.titleLarge(isDark: isDark),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isNirniqLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isNirniqLinked ? l10n.profileNirniqConnected : l10n.profileGuestAccount,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isNirniqLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isNirniqLinked ? (user?.email ?? '') : l10n.profileLocalData,
                                style: AppTypography.bodySmall(isDark: isDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 1: ACCOUNT & IDENTITY
            _buildSectionHeader(l10n.profileSecAccount, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isNirniqLinked ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                        size: 20,
                        color: isNirniqLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNirniqLinked ? l10n.profileNirniqConnected : l10n.profileConnectNirniq,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              isNirniqLinked
                                  ? (user?.email ?? l10n.profileNirniqConnected)
                                  : l10n.profileConnectNirniqDesc,
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                      if (isNirniqLinked)
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.emeraldPrimary),
                    ],
                  ),
                  if (!isNirniqLinked) ...[
                    Divider(height: 20, color: isDark ? Colors.white10 : Colors.black12),
                    InkWell(
                      onTap: () => _handleNirniqSignIn(context),
                      borderRadius: AppRadius.smBorder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 22, color: AppColors.emeraldPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.profileConnectNirniq,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.emeraldPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 2: CLOUD & SYNCHRONIZATION
            _buildSectionHeader(l10n.profileSecCloud, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_sync_rounded, size: 20, color: AppColors.emeraldPrimary),
                    title: Text(
                      l10n.authCloudSync,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      pendingCount > 0 ? '$pendingCount ${l10n.statusPending}' : '✓ ${l10n.authSyncStatusSynced}',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      CloudSyncSheet.show(context);
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined, size: 20),
                    title: Text(
                      l10n.settingsTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      l10n.profileCloudSyncDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/cloud-settings');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 3: RECOVERY KEY
            _buildSectionHeader(l10n.profileSecRecovery, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 18, color: AppColors.emeraldPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.authRecoveryKey,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              user?.recoveryKey ?? 'N/A',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          if (user?.recoveryKey != null) {
                            Clipboard.setData(ClipboardData(text: user!.recoveryKey));
                            HapticHelper.success();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.profileRecoveryCopied),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.profileRecoverySafe,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 4: APP EXPERIENCE & MODES
            _buildSectionHeader(l10n.profileSecExperience, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildModeOption(
                    title: l10n.onboardingModeTripsOnly,
                    subtitle: l10n.onboardingModeTripsSub,
                    emoji: '✈️',
                    isSelected: authVm.appExperienceMode == AppExperienceMode.tripsOnly,
                    isDark: isDark,
                    onTap: () async {
                      HapticHelper.selection();
                      await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
                      onSwitchToTrips?.call();
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  _buildModeOption(
                    title: l10n.onboardingModeAll,
                    subtitle: l10n.onboardingModeAllSub,
                    emoji: '💼',
                    isSelected: authVm.appExperienceMode == AppExperienceMode.all,
                    isDark: isDark,
                    onTap: () async {
                      HapticHelper.selection();
                      await authVm.setAppExperienceMode(AppExperienceMode.all);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 5: PREFERENCES
            _buildSectionHeader(l10n.profileSecPreferences, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.translate_rounded, size: 20, color: AppColors.emeraldPrimary),
                    title: Text(
                      l10n.profileLanguage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${localeVm.currentLanguage.flagEmoji} ${localeVm.currentLanguage.nativeName} (${localeVm.currentLanguage.englishName})',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      LanguageSelectSheet.show(context);
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      themeVm.themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : (themeVm.themeMode == ThemeMode.light
                              ? Icons.light_mode_rounded
                              : Icons.brightness_auto_rounded),
                      size: 20,
                    ),
                    title: Text(
                      l10n.profileAppearance,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      themeVm.themeMode == ThemeMode.dark
                          ? l10n.profileThemeDark
                          : (themeVm.themeMode == ThemeMode.light ? l10n.profileThemeLight : l10n.profileThemeSystem),
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: DropdownButton<ThemeMode>(
                      value: themeVm.themeMode,
                      underline: const SizedBox.shrink(),
                      dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      items: [
                        DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.profileThemeSystem, style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.profileThemeLight, style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.profileThemeDark, style: const TextStyle(fontSize: 12))),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          themeVm.setThemeMode(mode);
                          HapticHelper.selection();
                        }
                      },
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.widgets_outlined, size: 20, color: AppColors.emeraldPrimary),
                    title: Text(
                      l10n.profileWidgets,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l10n.profileWidgetsDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/widgets');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 6: HELP & SUPPORT
            _buildSectionHeader(l10n.profileSecHelp, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.emeraldPrimary),
                    title: Text(
                      l10n.guideTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(l10n.guideSubtitle, style: AppTypography.bodySmall(isDark: isDark)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/guide');
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_center_outlined, size: 20, color: AppColors.tealAccent),
                    title: Text(
                      l10n.profileFaq,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(l10n.profileFaqDesc, style: AppTypography.bodySmall(isDark: isDark)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/help');
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_stories_outlined, size: 20, color: AppColors.indigoAccent),
                    title: Text(
                      l10n.profileTour,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(l10n.profileTourDesc, style: AppTypography.bodySmall(isDark: isDark)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      InteractiveTutorialSheet.show(context);
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined, size: 20, color: AppColors.emeraldPrimary),
                    title: Text(
                      l10n.profilePrivacyPolicy,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(l10n.profilePrivacyPolicyDesc, style: AppTypography.bodySmall(isDark: isDark)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/privacy-policy');
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.feedback_outlined, size: 20),
                    title: Text(
                      l10n.profileFeedback,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const BetaFeedbackSheet(currentScreenContext: 'Profile Surface'),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 7: DANGER ZONE
            _buildSectionHeader(l10n.profileSecDanger, isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                    title: Text(
                      l10n.profileSignOutTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                    subtitle: Text(
                      l10n.profileSignOutDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () => _showSignOutDialog(context),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_rounded, size: 20, color: AppColors.negativeRedDark),
                    title: Text(
                      l10n.profileDeleteAccountTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.negativeRedDark),
                    ),
                    subtitle: Text(
                      l10n.profileDeleteAccountDesc,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Column(
                children: [
                  Text(
                    'Kith',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.onboardingBrandCredit,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v2.2.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Done Button
            AppButton(
              text: l10n.actionDone,
              isFullWidth: true,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required String emoji,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
