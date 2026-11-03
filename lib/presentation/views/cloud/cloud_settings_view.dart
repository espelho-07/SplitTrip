import '../../../core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../data/services/sync_service.dart';
import '../../router/app_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/kith_success_toast.dart';
import 'cloud_sync_sheet.dart';

class CloudSettingsView extends StatelessWidget {
  const CloudSettingsView({super.key});

  String _formatLastSync(DateTime? time, AppLocalizations l10n) {
    if (time == null) return l10n.cloudSyncNever;
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return l10n.cloudSyncJustNow;
    if (diff.inMinutes < 60) return l10n.cloudSyncMinsAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.cloudSyncHoursAgo(diff.inHours);
    return DateFormat('dd MMM, hh:mm a').format(time);
  }

  void _showSignOutDialog(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final l10n = context.l10n;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.profileSignOutTitle),
        content: Text(l10n.profileSignOutDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.profileSignOutConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppRouter.router.go('/onboarding');
      await authVm.logout();
      homeVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, l10n.profileSignOutSuccess);
      }
    }
  }


  void _showRotateKeyDialog(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: const Text('Rotate Recovery Key?'),
        content: const Text(
          'This will invalidate your old Recovery Key and generate a new one. Your cloud account and trips will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.emeraldPrimary),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Generate New Key'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newKey = await authVm.rotateRecoveryKey();
      if (context.mounted && newKey != null) {
        Clipboard.setData(ClipboardData(text: newKey));
        KithSuccessToast.show(context, 'New Recovery Key generated and copied!');
      }
    }
  }

  void _syncNow(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    final syncService = context.read<SyncService>();
    final apiClient = context.read<ApiClient>();
    final user = authVm.currentUser;
    if (user == null) return;

    HapticHelper.medium();
    final report = await syncService.reconcileWithCloud(user.effectiveAccountId, apiClient: apiClient);
    if (context.mounted) {
      if (report.isFullySynced) {
        KithSuccessToast.show(context, 'All trips & expenses fully synced ✓');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.errorMessage ?? 'Sync completed with updates'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final syncService = context.watch<SyncService>();
    final l10n = context.l10n;
    final user = authVm.currentUser;
    final pendingCount = syncService.pendingCount;
    final lastSync = authVm.lastSyncTime;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(l10n.cloudTitle),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // SECTION 1: ACCOUNT
          _buildSectionHeader(l10n.cloudSecAccount, isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      user?.isGoogleLinked == true && AppConfig.enableGoogleAuth
                          ? Icons.verified_user_rounded
                          : Icons.shield_rounded,
                      size: 24,
                      color: user?.isGoogleLinked == true && AppConfig.enableGoogleAuth
                          ? AppColors.emeraldPrimary
                          : AppColors.emeraldPrimary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isGoogleLinked == true && AppConfig.enableGoogleAuth
                                ? 'Google Account'
                                : 'Kith Local-First Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.isGoogleLinked == true && AppConfig.enableGoogleAuth
                                ? (user?.email ?? '')
                                : 'Protected by Master Recovery Key',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                    if (user?.isGoogleLinked == true && AppConfig.enableGoogleAuth)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  user?.isGoogleLinked == true && AppConfig.enableGoogleAuth
                      ? 'Your account is permanently linked to Google and backed up in Supabase PostgreSQL.'
                      : 'Your ledger and financial records are secured locally and backed up across devices using your Recovery Key.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // SECTION 2: SYNC
          _buildSectionHeader(l10n.cloudSecSync, isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.cloud_done_rounded, size: 22, color: AppColors.emeraldPrimary),
                  title: Text(
                    l10n.authCloudSync,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    pendingCount > 0
                        ? '$pendingCount ${l10n.statusPending}'
                        : 'Up to date (Last: ${_formatLastSync(lastSync, l10n)})',
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _syncNow(context),
                        child: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.queue_rounded, size: 18),
                        tooltip: l10n.cloudFlushQueue,
                        onPressed: () => CloudSyncSheet.show(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: AppColors.emeraldPrimary,
                  activeTrackColor: AppColors.emeraldPrimary.withValues(alpha: 0.5),
                  title: Text(
                    l10n.cloudAutoSync,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    l10n.cloudAutoSyncDesc,
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                  value: authVm.isAutoSyncEnabled,
                  onChanged: (val) {
                    HapticHelper.selection();
                    authVm.setAutoSyncEnabled(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // SECTION 3: RECOVERY
          _buildSectionHeader(l10n.authRecoveryKey, isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key_rounded, size: 20, color: AppColors.emeraldPrimary),
                    const SizedBox(width: AppSpacing.md),
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
                      tooltip: l10n.cloudCopyKey,
                      onPressed: () {
                        if (user != null) {
                          Clipboard.setData(ClipboardData(text: user.recoveryKey));
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
                  l10n.cloudRecoveryCardDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Rotate Key', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showRotateKeyDialog(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // SECTION 4: PRIVACY & DATA BOUNDARIES
          _buildSectionHeader(l10n.settingsSecData, isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.emeraldPrimary),
                    const SizedBox(width: 10),
                    Text(
                      l10n.profilePrivacyPolicy,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.profilePrivacySub,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // DANGER ZONE: SIGN OUT
          _buildSectionHeader(l10n.profileSecDangerTitle, isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              title: Text(
                l10n.profileLogoutBtn,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent),
              ),
              subtitle: Text(
                l10n.profileSignOutDesc,
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
              onTap: () => _showSignOutDialog(context),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
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
}
