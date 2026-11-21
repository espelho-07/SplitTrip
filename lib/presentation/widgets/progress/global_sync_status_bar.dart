import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/sync_service.dart';
import '../../views/sync/offline_synchronization_sheet.dart';

/// Top-level reactive connectivity and synchronization status bar.
///
/// Unobtrusive, elegant, and informative. Renders across Home views only when
/// connectivity is lost, mutations are pending, or synchronization is active.
/// Automatically hides when the device is online and fully synced.
class GlobalSyncStatusBar extends StatefulWidget {
  const GlobalSyncStatusBar({super.key});

  @override
  State<GlobalSyncStatusBar> createState() => _GlobalSyncStatusBarState();
}

class _GlobalSyncStatusBarState extends State<GlobalSyncStatusBar> {
  StreamSubscription<SyncStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final syncService = Provider.of<SyncService?>(context, listen: false);
      if (syncService != null) {
        _statusSub = syncService.statusStream.listen((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncService?>(context);
    if (syncService == null) return const SizedBox.shrink();

    final status = syncService.currentStatus;
    final pendingCount = syncService.pendingMutationCount;
    final quarantinedCount = syncService.quarantinedCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Normal state: fully synced and not offline -> hide completely
    if (status == SyncStatus.synced && pendingCount == 0 && quarantinedCount == 0) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData iconData;
    String message;
    String? actionLabel;
    VoidCallback? onAction;
    bool showSpinner = false;

    switch (status) {
      case SyncStatus.offline:
        if (pendingCount > 0) {
          bgColor = isDark ? const Color(0xFF261D11) : const Color(0xFFFFFBEB);
          borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
          textColor = const Color(0xFFF59E0B);
          iconData = Icons.cloud_off_rounded;
          message = 'Offline • $pendingCount change${pendingCount > 1 ? "s" : ""} saved locally';
          actionLabel = 'View';
          onAction = () {
            HapticHelper.light();
            OfflineSynchronizationSheet.show(context);
          };
        } else {
          bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
          borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
          textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          iconData = Icons.wifi_off_rounded;
          message = "You're offline. Your saved trips and expenses are still available.";
        }
        break;

      case SyncStatus.syncing:
        bgColor = isDark ? const Color(0xFF16192E) : const Color(0xFFEEF2FF);
        borderColor = const Color(0xFF6366F1).withValues(alpha: 0.35);
        textColor = const Color(0xFF6366F1);
        iconData = Icons.sync_rounded;
        message = 'Syncing changes with cloud...';
        showSpinner = true;
        break;

      case SyncStatus.pending:
        bgColor = isDark ? const Color(0xFF0F2321) : const Color(0xFFF0FDF4);
        borderColor = AppColors.emeraldPrimary.withValues(alpha: 0.35);
        textColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
        iconData = Icons.cloud_queue_rounded;
        message = pendingCount > 1
            ? '$pendingCount changes waiting to sync'
            : 'Your changes are waiting to sync.';
        actionLabel = 'Sync now';
        onAction = () async {
          HapticHelper.medium();
          final apiClient = Provider.of<ApiClient?>(context, listen: false);
          if (apiClient != null && !syncService.isProcessing) {
            await syncService.flushQueue(apiClient, force: true);
            if (context.mounted) {
              if (syncService.pendingMutationCount > 0 || syncService.quarantinedCount > 0) {
                OfflineSynchronizationSheet.show(context);
              }
            }
          }
        };
        break;

      case SyncStatus.reconnecting:
        bgColor = isDark ? const Color(0xFF261D11) : const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
        textColor = const Color(0xFFF59E0B);
        iconData = Icons.wifi_protected_setup_rounded;
        message = 'Reconnecting to servers...';
        showSpinner = true;
        break;

      case SyncStatus.error:
        bgColor = isDark ? const Color(0xFF2B1116) : const Color(0xFFFFF1F2);
        borderColor = const Color(0xFFE11D48).withValues(alpha: 0.35);
        textColor = const Color(0xFFE11D48);
        if (syncService.isSessionExpired) {
          iconData = Icons.lock_clock_rounded;
          message = 'Your session has expired. Sign in again to synchronize your changes.';
          actionLabel = 'Sign in';
        } else if (quarantinedCount > 0) {
          iconData = Icons.sync_problem_rounded;
          message = '$quarantinedCount change${quarantinedCount > 1 ? "s" : ""} could not be synced.';
          actionLabel = 'Review';
        } else {
          iconData = Icons.sync_problem_rounded;
          message = syncService.lastErrorMessage ?? 'Unable to sync right now. Your local changes are preserved.';
          actionLabel = 'Review';
        }
        onAction = () {
          HapticHelper.light();
          OfflineSynchronizationSheet.show(context);
        };
        break;

      case SyncStatus.synced:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticHelper.light();
        OfflineSynchronizationSheet.show(context);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          children: [
            if (showSpinner)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else
              Icon(iconData, size: 15, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
