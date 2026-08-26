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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileSheet(
        onSwitchToTrips: onSwitchToTrips,
        onShowRestoreAccount: onShowRestoreAccount,
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isLoading) return;

    HapticHelper.medium();
    final success = await AuthProgressDialog.startGoogleSignIn(context);
    if (success && context.mounted) {
      Navigator.of(context).pop(); // Close profile sheet on successful sign-in
    }
  }

  void _showSignOutDialog(BuildContext context) async {
    final l10n = context.l10n;
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

    if (confirm == true && context.mounted) {
      final authVm = context.read<AuthViewModel>();
      final homeVm = context.read<HomeViewModel>();
      final personalVm = context.read<PersonalExpenseViewModel>();
      final storage = context.read<LocalStorageService>();

      // Close profile sheet first
      Navigator.of(context).pop();

      await authVm.logout();
      await storage.clearAllUserData();
      homeVm.clearData();
      personalVm.clearData();

      if (context.mounted) {
        context.go('/onboarding');
        KithSuccessToast.show(context, l10n.authSignOutSuccess);
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
    final isGoogleLinked = user?.isGoogleLinked ?? false;
    final pendingCount = syncService.pendingCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
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
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Profile Header Card
            Row(
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
                              color: (isGoogleLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isGoogleLinked ? 'Google Connected' : 'Guest Account',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isGoogleLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isGoogleLinked ? (user?.email ?? '') : 'Data on this device',
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

            const SizedBox(height: AppSpacing.lg),

            // SECTION 1: ACCOUNT & IDENTITY
            _buildSectionHeader('ACCOUNT', isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isGoogleLinked ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                        size: 20,
                        color: isGoogleLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGoogleLinked ? 'Connected with Google' : 'Sign in with Google',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              isGoogleLinked
                                  ? (user?.email ?? 'Cloud identity active')
                                  : 'Sign in with Google to sync across devices',
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                      if (isGoogleLinked)
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.emeraldPrimary),
                    ],
                  ),
                  if (!isGoogleLinked) ...[
                    Divider(height: 20, color: isDark ? Colors.white10 : Colors.black12),
                    InkWell(
                      onTap: () => _handleGoogleSignIn(context),
                      borderRadius: AppRadius.smBorder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.g_mobiledata_rounded, size: 28, color: AppColors.emeraldPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Continue with Google',
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
            _buildSectionHeader('CLOUD', isDark),
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
                      'Cloud Sync',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      pendingCount > 0 ? '$pendingCount changes waiting to sync' : '✓ Up to date',
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
                      'Cloud Settings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Sync controls, privacy, and account settings',
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
            _buildSectionHeader('EMERGENCY RECOVERY KEY', isDark),
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
                              'Recovery Key',
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
                        tooltip: 'Copy key',
                        onPressed: () {
                          if (user?.recoveryKey != null) {
                            Clipboard.setData(ClipboardData(text: user!.recoveryKey));
                            HapticHelper.success();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Recovery key copied to clipboard! Save it safely.'),
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
                    'Keep this key safe. You can use it to restore your account on any new phone.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 4: APP EXPERIENCE & MODES
            _buildSectionHeader('APP EXPERIENCE', isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildModeOption(
                    title: 'Trips & Group Splitting Only',
                    subtitle: 'Clean interface focused purely on travel and group ledger',
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
                    title: 'Trips & Personal Expenses',
                    subtitle: 'Full suite with personal tracking, lending/borrowing, & budgets',
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
            _buildSectionHeader('PREFERENCES', isDark),
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
                    title: const Text(
                      'Language',
                      style: TextStyle(
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
                      'Appearance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      themeVm.themeMode == ThemeMode.dark
                          ? 'Dark mode'
                          : (themeVm.themeMode == ThemeMode.light ? 'Light mode' : 'System auto'),
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: DropdownButton<ThemeMode>(
                      value: themeVm.themeMode,
                      underline: const SizedBox.shrink(),
                      dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          themeVm.setThemeMode(mode);
                          HapticHelper.selection();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 6: HELP & SUPPORT
            _buildSectionHeader('HELP & ABOUT', isDark),
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
                      'Help & FAQ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text('Searchable guides & answers for all features', style: AppTypography.bodySmall(isDark: isDark)),
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
                      'Replay Kith Tour',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text('Review the 5-step quick onboarding', style: AppTypography.bodySmall(isDark: isDark)),
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
                    leading: const Icon(Icons.feedback_outlined, size: 20),
                    title: Text(
                      'Send Feedback',
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
            _buildSectionHeader('DANGER ZONE', isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
                subtitle: Text(
                  'Clear credentials from this device',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                onTap: () => _showSignOutDialog(context),
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
                    'by Nirniq',
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
              text: 'Done',
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
