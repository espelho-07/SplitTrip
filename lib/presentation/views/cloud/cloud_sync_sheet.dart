import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../data/services/sync_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/progress/kith_stage_progress.dart';
import '../../widgets/progress/kith_success_toast.dart';

class CloudSyncSheet extends StatefulWidget {
  const CloudSyncSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloudSyncSheet(),
    );
  }

  @override
  State<CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends State<CloudSyncSheet> {
  bool _isSyncing = false;
  int _activeStage = 0;
  String? _syncError;

  final List<ProgressStage> _stages = const [
    ProgressStage(label: 'Checking account & session', description: 'Verifying encryption tokens'),
    ProgressStage(label: 'Flushing pending changes', description: 'Uploading offline mutations'),
    ProgressStage(label: 'Syncing trips & settlements', description: 'Updating trip ledger & balances'),
    ProgressStage(label: 'Finishing up', description: 'Ledger verified'),
  ];

  Future<void> _performSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _activeStage = 0;
      _syncError = null;
    });

    HapticHelper.medium();

    try {
      final authVm = context.read<AuthViewModel>();
      final homeVm = context.read<HomeViewModel>();
      final apiClient = context.read<ApiClient>();
      final syncService = context.read<SyncService>();
      final user = authVm.currentUser;

      if (user == null) {
        throw StateError('No active user session');
      }

      // Stage 0: Checking account & session
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _activeStage = 1);

      // Stage 1: Flush mutation queue
      await syncService.flushQueue(apiClient);
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _activeStage = 2);

      // Stage 2: Sync trips & settlements
      await homeVm.loadTrips(user.id);
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _activeStage = 3);

      // Stage 3: Finishing up
      await authVm.recordSyncCompleted();
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() => _isSyncing = false);
        KithSuccessToast.show(context, 'Everything is up to date ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncError = 'Could not complete sync. Check connection and retry.';
        });
        HapticHelper.error();
      }
    }
  }

  Future<void> _retryQuarantined() async {
    final syncService = context.read<SyncService>();
    final apiClient = context.read<ApiClient>();
    await syncService.retryQuarantinedMutations(apiClient);
    if (mounted) setState(() {});
  }

  Future<void> _clearAllStuck() async {
    final syncService = context.read<SyncService>();
    if (syncService.quarantinedCount > 0) {
      await syncService.clearQuarantinedMutations();
    } else {
      await syncService.clearAllPendingMutations();
    }
    if (mounted) {
      setState(() {});
      KithSuccessToast.show(context, 'Stuck changes cleared');
    }
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Today at ${DateFormat.jm().format(time)}';
    return DateFormat('MMM d, h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final syncService = context.watch<SyncService>();
    final pendingCount = syncService.pendingCount;
    final quarantinedCount = syncService.quarantinedCount;
    final lastSync = authVm.lastSyncTime;
    final hasStuckIssues = quarantinedCount > 0 ||
        (pendingCount > 0 &&
            (syncService.currentStatus == SyncStatus.error ||
                syncService.lastErrorMessage != null));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppColors.emeraldPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Synchronization',
                        style: AppTypography.titleMedium(isDark: isDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep trips in sync across devices',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Active Sync or Status Card
            if (_isSyncing) ...[
              SurfaceCard(
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: KithStageProgress(
                  title: 'Syncing your Kith data…',
                  stages: _stages,
                  currentStageIndex: _activeStage,
                ),
              ),
            ] else ...[
              SurfaceCard(
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    // Status Badge Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pendingCount > 0
                            ? AppColors.amberAccent.withValues(alpha: 0.15)
                            : AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        pendingCount > 0 ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                        color: pendingCount > 0 ? AppColors.amberAccent : AppColors.emeraldPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount pending ${pendingCount == 1 ? 'change' : 'changes'}'
                          : 'Up to date',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pendingCount > 0
                          ? 'Changes are safely stored locally and will push online'
                          : "You're all caught up across all devices",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last synced:',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                        Text(
                          _formatLastSync(lastSync),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (_syncError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _syncError!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasStuckIssues) ...[
                const SizedBox(height: AppSpacing.md),
                SurfaceCard(
                  backgroundColor: isDark ? const Color(0xFF2B1116) : const Color(0xFFFFF1F2),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            quarantinedCount > 0
                                ? '$quarantinedCount change${quarantinedCount > 1 ? "s" : ""} need review'
                                : '$pendingCount change${pendingCount > 1 ? "s" : ""} could not sync',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF9F1239),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        syncService.lastErrorMessage ??
                            'Some offline changes encountered a server or membership issue and could not be synced.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF881337),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _clearAllStuck,
                            child: const Text('Dismiss', style: TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: quarantinedCount > 0 ? _retryQuarantined : _performSync,
                            child: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.lg),

            // Action Button
            AppButton(
              text: _isSyncing ? 'Syncing…' : 'Sync now',
              icon: Icons.sync_rounded,
              isLoading: _isSyncing,
              isFullWidth: true,
              onPressed: _isSyncing ? null : _performSync,
            ),
          ],
        ),
      ),
    );
  }
}
