import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../widgets/progress/kith_success_toast.dart';
import 'cloud_sync_sheet.dart';

class CloudSettingsView extends StatelessWidget {
  const CloudSettingsView({super.key});

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM, hh:mm a').format(time);
  }

  void _showSignOutDialog(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: const Text('Sign Out of Kith?'),
        content: const Text(
          'Your active cloud session will be closed on this device. You can restore your data anytime using Google or your Recovery Key.',
        ),
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

    if (confirm == true) {
      AppRouter.router.go('/onboarding');
      await authVm.logout();
      homeVm.clearData();
      personalVm.clearData();

      final rootCtx = AppRouter.navigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        KithSuccessToast.show(rootCtx, 'Signed out successfully ✓');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final syncService = context.watch<SyncService>();
    final user = authVm.currentUser;
    final pendingCount = syncService.pendingCount;
    final lastSync = authVm.lastSyncTime;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Cloud & Account Settings'),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // SECTION 1: ACCOUNT
          _buildSectionHeader('ACCOUNT IDENTITY', isDark),
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
                      user?.isGoogleLinked == true ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                      size: 24,
                      color: user?.isGoogleLinked == true ? AppColors.emeraldPrimary : AppColors.indigoAccent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isGoogleLinked == true ? 'Google Account' : 'Guest Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email != null && user!.email!.isNotEmpty
                                ? user.email!
                                : 'Not connected to Google yet',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                    if (user?.isGoogleLinked == true)
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
                  user?.isGoogleLinked == true
                      ? 'Your account is permanently linked to Google and backed up in Supabase PostgreSQL.'
                      : 'Sign in with Google to sync your trips, expenses, and balances seamlessly across devices.',
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
          _buildSectionHeader('CLOUD SYNCHRONIZATION', isDark),
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
                    'Cloud Sync Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    pendingCount > 0
                        ? '$pendingCount changes waiting to sync'
                        : 'Up to date (Last: ${_formatLastSync(lastSync)})',
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                  trailing: TextButton(
                    onPressed: () => CloudSyncSheet.show(context),
                    child: const Text('View Status'),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: AppColors.emeraldPrimary,
                  activeTrackColor: AppColors.emeraldPrimary.withValues(alpha: 0.5),
                  title: Text(
                    'Auto-sync',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    "Kith syncs changes automatically whenever you're online.",
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
          _buildSectionHeader('EMERGENCY RECOVERY', isDark),
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
                        if (user != null) {
                          Clipboard.setData(ClipboardData(text: user.recoveryKey));
                          HapticHelper.success();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery key copied! Save it in a safe place.'),
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
                  'Your backup way to recover your Kith account and all data if you switch devices or lose access to Google.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // SECTION 4: PRIVACY & DATA BOUNDARIES
          _buildSectionHeader('DATA PRIVACY & STORAGE', isDark),
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
                      'What is synced vs private',
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
                  '• Personal Expenses & Budgets: 100% private to your account.\n'
                  '• Trip Ledgers & Receipts: Shared only with invited members of that trip.\n'
                  '• Offline Cache: Safely encrypted on your device and synced upon reconnection.',
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
          _buildSectionHeader('DANGER ZONE', isDark),
          const SizedBox(height: AppSpacing.xs),
          SurfaceCard(
            backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              title: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent),
              ),
              subtitle: Text(
                'Invalidates active session and clears cached user credentials from this device.',
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
