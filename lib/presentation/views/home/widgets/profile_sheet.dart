import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../data/services/sync_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../domain/enums/app_experience_mode.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../viewmodels/personal_expense_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../settings/widgets/beta_feedback_sheet.dart';

class ProfileSheet extends StatelessWidget {
  final VoidCallback? onSwitchToTrips;
  final void Function(BuildContext) onShowLinkAccount;
  final void Function(BuildContext) onShowRestoreAccount;
  final void Function(BuildContext) onShowServerConfig;

  const ProfileSheet({
    super.key,
    this.onSwitchToTrips,
    required this.onShowLinkAccount,
    required this.onShowRestoreAccount,
    required this.onShowServerConfig,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSwitchToTrips,
    required void Function(BuildContext) onShowLinkAccount,
    required void Function(BuildContext) onShowRestoreAccount,
    required void Function(BuildContext) onShowServerConfig,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileSheet(
        onSwitchToTrips: onSwitchToTrips,
        onShowLinkAccount: onShowLinkAccount,
        onShowRestoreAccount: onShowRestoreAccount,
        onShowServerConfig: onShowServerConfig,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final user = authVm.currentUser;

    if (user == null) return const SizedBox.shrink();

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
                MemberAvatar(name: user.displayName, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: AppTypography.titleLarge(isDark: isDark),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (user.isLinkedToAccount ? AppColors.emeraldPrimary : AppColors.indigoAccent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.isLinkedToAccount ? 'Cloud Linked' : 'Guest Account',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: user.isLinkedToAccount ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user.isLinkedToAccount ? (user.email ?? '') : 'Offline Ready',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 1: ACCOUNT
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
                        user.isGoogleLinked ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                        size: 20,
                        color: user.isGoogleLinked ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.isGoogleLinked ? 'Google Account' : 'Guest Account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              user.email != null && user.email!.isNotEmpty
                                  ? user.email!
                                  : 'Not linked to Google yet',
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!user.isGoogleLinked) ...[
                    Divider(height: 20, color: isDark ? Colors.white10 : Colors.black12),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onShowLinkAccount(context);
                      },
                      borderRadius: AppRadius.smBorder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.g_mobiledata_rounded, size: 26, color: AppColors.emeraldPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Sync your Kith account across devices',
                                    style: AppTypography.bodySmall(isDark: isDark),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 2: RECOVERY KEY
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
                              user.recoveryKey,
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
                          Clipboard.setData(ClipboardData(text: user.recoveryKey));
                          HapticHelper.success();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery key copied to clipboard! Save it safely.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
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

            // SECTION 2: EXPERIENCE & MODES
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

            // SECTION 3: PREFERENCES & DATA
            _buildSectionHeader('PREFERENCES & CLOUD', isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  // Theme Mode
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      themeVm.themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : (themeVm.themeMode == ThemeMode.light ? Icons.light_mode_rounded : Icons.brightness_auto_rounded),
                      size: 20,
                    ),
                    title: Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    subtitle: Text(
                      themeVm.themeMode == ThemeMode.dark ? 'Dark mode' : (themeVm.themeMode == ThemeMode.light ? 'Light mode' : 'System auto'),
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
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  // Sync with Cloud
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_sync_rounded, size: 20, color: AppColors.emeraldPrimary),
                    title: Text('Sync All Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    subtitle: Text('Force refresh all trips & personal ledger', style: AppTypography.bodySmall(isDark: isDark)),
                    trailing: const Icon(Icons.refresh_rounded, size: 18),
                    onTap: () async {
                      Navigator.pop(context);
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('⟳ Syncing all data with cloud...'), behavior: SnackBarBehavior.floating),
                      );
                      final apiClient = context.read<ApiClient>();
                      final syncService = context.read<SyncService>();
                      final homeVm = context.read<HomeViewModel>();
                      final personalVm = context.read<PersonalExpenseViewModel>();

                      await syncService.flushQueue(apiClient);
                      await homeVm.loadTrips(user.id);
                      await personalVm.loadData(user.id);
                      await personalVm.syncTripExpenses(user.id);

                      messenger.showSnackBar(
                        const SnackBar(content: Text('🎉 Everything is up to date!'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  // Server Config
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined, size: 20),
                    title: Text('Cloud & Server Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      onShowServerConfig(context);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SECTION 4: SUPPORT & ACCOUNT
            _buildSectionHeader('SUPPORT & SESSION', isDark),
            const SizedBox(height: AppSpacing.xs),
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.feedback_outlined, size: 20),
                    title: Text('Send Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
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
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.key_outlined, size: 20),
                    title: Text('Restore with Recovery Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      onShowRestoreAccount(context);
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                    title: const Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Sign Out?'),
                          content: const Text('Make sure you have saved your Recovery Key or linked with Google so you can restore your data later.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        await authVm.logout();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Column(
                children: [
                  Text(
                    'KITH • v2.2.0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Zero-Confusion Travel & Group Finances',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white24 : Colors.black26,
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
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? Colors.white54 : Colors.black45,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
