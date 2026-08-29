import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../data/repositories/trip_repository.dart';
import '../../../../data/services/sync_service.dart';
import '../../../../domain/models/trip_sync_status.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/trip_detail_viewmodel.dart';

enum VerificationStage {
  idle,
  checkingConnectivity,
  flushingLocal,
  queryingTripState,
  requestingSync,
  verifying,
  readyToComplete,
  syncBlocked,
  completing,
  error,
}

class TripCompletionVerificationSheet extends StatefulWidget {
  final String tripId;
  final VoidCallback? onTripCompleted;

  const TripCompletionVerificationSheet({
    super.key,
    required this.tripId,
    this.onTripCompleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    VoidCallback? onTripCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.topSheetBorder),
      builder: (ctx) => TripCompletionVerificationSheet(
        tripId: tripId,
        onTripCompleted: onTripCompleted,
      ),
    );
  }

  @override
  State<TripCompletionVerificationSheet> createState() =>
      _TripCompletionVerificationSheetState();
}

class _TripCompletionVerificationSheetState
    extends State<TripCompletionVerificationSheet> {
  VerificationStage _stage = VerificationStage.idle;
  double _progress = 0.0;
  String _statusMessage = 'Preparing your trip...';
  TripSyncStatus? _syncStatus;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification() async {
    if (!mounted) return;
    setState(() {
      _stage = VerificationStage.checkingConnectivity;
      _progress = 0.10;
      _statusMessage = 'Checking server connectivity...';
      _errorMessage = null;
      _isOffline = false;
    });

    final tripRepo = context.read<TripRepository>();
    final syncService = Provider.of<SyncService?>(context, listen: false);

    try {
      // Step 1: Connectivity check (10%)
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Step 2: Flush current device local pending changes (25%)
      if (mounted) {
        setState(() {
          _stage = VerificationStage.flushingLocal;
          _progress = 0.25;
          _statusMessage = 'Flushing local pending changes...';
        });
      }

      if (syncService != null && syncService.hasPendingMutationsForTrip(widget.tripId)) {
        await syncService.flushQueue(tripRepo.apiClient, force: true);
      }

      // Step 3: Query server trip state & participant sync breakdown (50%)
      if (mounted) {
        setState(() {
          _stage = VerificationStage.queryingTripState;
          _progress = 0.50;
          _statusMessage = 'Checking latest trip state on server...';
        });
      }

      TripSyncStatus status = await tripRepo.getTripSyncStatus(widget.tripId);

      // Step 4: If participants are not synced, request realtime sync (75%)
      if (!status.isFullySynced) {
        if (mounted) {
          setState(() {
            _stage = VerificationStage.requestingSync;
            _progress = 0.75;
            _statusMessage = 'Requesting sync from active devices...';
          });
        }

        await tripRepo.requestTripSync(widget.tripId);
        // Grace period for online participants to acknowledge
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // Re-query authoritative status
        status = await tripRepo.getTripSyncStatus(widget.tripId);
      }

      // Step 5: Final verification evaluation (90% -> 100%)
      if (mounted) {
        setState(() {
          _stage = VerificationStage.verifying;
          _progress = 0.90;
          _statusMessage = 'Verifying synchronization acknowledgments...';
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          _syncStatus = status;
          _progress = 1.0;
          if (status.canCompleteNormally) {
            _stage = VerificationStage.readyToComplete;
            _statusMessage = 'Trip is fully synchronized and ready to complete.';
          } else {
            _stage = VerificationStage.syncBlocked;
            _statusMessage = 'Unconfirmed changes detected on one or more devices.';
          }
        });
        HapticHelper.selection();
      }
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _isOffline = true;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _executeCompletion({required bool forced}) async {
    final tripRepo = context.read<TripRepository>();
    final tripDetailVm = context.read<TripDetailViewModel>();
    final authVm = context.read<AuthViewModel>();

    setState(() {
      _stage = VerificationStage.completing;
      _statusMessage = forced
          ? 'Marking trip as completed with pending changes...'
          : 'Finalizing trip completion on server...';
    });

    try {
      final mode = forced ? 'FORCED_WITH_PENDING_SYNC' : 'NORMAL';
      await tripRepo.completeTrip(
        tripId: widget.tripId,
        completionMode: mode,
        expectedRevision: _syncStatus?.currentRevision,
      );

      // Update viewmodel & notify listeners
      await tripDetailVm.loadTrip(widget.tripId, authVm.currentUser?.id ?? '');
      HapticHelper.heavy();

      if (mounted) {
        Navigator.pop(context, true);
        widget.onTripCompleted?.call();
      }
    } on ConflictException catch (_) {
      // Revision changed while finalizing: prompt to re-verify
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip state changed on server while finalizing. Refreshing sync status...'),
            backgroundColor: AppColors.amberAccent,
          ),
        );
        _startVerification();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _promptForcedCompletionConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amberAccent, size: 24),
            const SizedBox(width: 10),
            Text('Complete Anyway?', style: AppTypography.titleMedium(isDark: isDark)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One or more devices still have changes that haven\'t reached the server.\n\n'
              'Marking the trip as completed now means those changes may not be included in the final settlement.\n\n'
              'Note: Pre-existing offline changes will NOT be deleted or discarded.',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Keep Open', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeCompletion(forced: true);
            },
            child: const Text('Complete Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVerifying = _stage == VerificationStage.checkingConnectivity ||
        _stage == VerificationStage.flushingLocal ||
        _stage == VerificationStage.queryingTripState ||
        _stage == VerificationStage.requestingSync ||
        _stage == VerificationStage.verifying ||
        _stage == VerificationStage.completing;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: AppSpacing.bottomSheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getHeaderBadgeColor().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getHeaderBadgeIcon(),
                  color: _getHeaderBadgeColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHeaderTitle(),
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                    Text(
                      'Multi-Participant Final Sync Verification',
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: isVerifying ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress Bar & Status Text
          if (isVerifying || _stage == VerificationStage.readyToComplete || _stage == VerificationStage.syncBlocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _stage == VerificationStage.syncBlocked
                      ? AppColors.amberAccent
                      : AppColors.emeraldPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppTypography.bodySmall(isDark: isDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    color: _stage == VerificationStage.syncBlocked
                        ? AppColors.amberAccent
                        : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Participant Sync Status Breakdown Card
          if (_syncStatus != null && _syncStatus!.participants.isNotEmpty) ...[
            Text(
              'Participant Sync State',
              style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _syncStatus!.participants.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                  itemBuilder: (ctx, idx) {
                    final p = _syncStatus!.participants[idx];
                    return _buildParticipantRow(p, isDark);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Warning / Notice Banners
          if (_stage == VerificationStage.readyToComplete) ...[
            _buildNoticeBanner(
              isDark: isDark,
              color: AppColors.emeraldPrimary,
              icon: Icons.check_circle_outline,
              title: 'Trip is Ready to Complete',
              description: 'All participant devices have acknowledged the latest revisions. Completing now finalizes settlement amounts cleanly.',
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (_stage == VerificationStage.syncBlocked) ...[
            _buildNoticeBanner(
              isDark: isDark,
              color: AppColors.amberAccent,
              icon: Icons.warning_amber_rounded,
              title: 'Unconfirmed Changes Detected',
              description: 'One or more members are offline or haven\'t synced yet. You can keep the trip open or finalize now with pending changes.',
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (_stage == VerificationStage.error) ...[
            _buildNoticeBanner(
              isDark: isDark,
              color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
              icon: Icons.error_outline,
              title: _isOffline ? 'Server Unreachable' : 'Verification Error',
              description: _errorMessage ?? 'Failed to verify synchronization with server.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Action Buttons
          _buildActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(ParticipantSyncInfo p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Stack(
            children: [
              MemberAvatar(
                name: p.displayName,
                avatarUrl: p.avatarUrl,
                size: 34,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.isOnline ? AppColors.positiveGreenLight : AppColors.lightTextMuted,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.isCurrentUser ? '${p.displayName} (You)' : p.displayName,
                        style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                          fontWeight: p.isCurrentUser ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.indigoAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Host',
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(
                            fontSize: 10,
                            color: AppColors.indigoAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  p.isOnline ? 'Online' : 'Last sync: ${p.lastSyncFormatted}',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ],
            ),
          ),
          _buildSyncBadge(p, isDark),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(ParticipantSyncInfo p, bool isDark) {
    switch (p.syncStatus) {
      case ParticipantSyncState.synced:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.positiveGreenLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 14, color: AppColors.positiveGreenLight),
              const SizedBox(width: 4),
              Text(
                'Synced',
                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                  color: AppColors.positiveGreenLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case ParticipantSyncState.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amberAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amberAccent),
              ),
              const SizedBox(width: 5),
              Text(
                'Syncing',
                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                  color: AppColors.amberAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case ParticipantSyncState.offline:
      case ParticipantSyncState.unknown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildNoticeBanner({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Keep Active',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Complete Trip',
                onPressed: () => _executeCompletion(forced: false),
              ),
            ),
          ],
        );
      case VerificationStage.syncBlocked:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Keep Trip Open',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Complete Anyway',
                variant: AppButtonVariant.outline,
                onPressed: _promptForcedCompletionConfirmation,
              ),
            ),
          ],
        );
      case VerificationStage.error:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Cancel',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: 'Retry Sync',
                onPressed: _startVerification,
              ),
            ),
          ],
        );
      case VerificationStage.completing:
      case VerificationStage.idle:
      case VerificationStage.checkingConnectivity:
      case VerificationStage.flushingLocal:
      case VerificationStage.queryingTripState:
      case VerificationStage.requestingSync:
      case VerificationStage.verifying:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Please wait while sync verification finishes...',
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ),
        );
    }
  }

  Color _getHeaderBadgeColor() {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return AppColors.emeraldPrimary;
      case VerificationStage.syncBlocked:
        return AppColors.amberAccent;
      case VerificationStage.error:
        return AppColors.negativeRedLight;
      default:
        return AppColors.indigoAccent;
    }
  }

  IconData _getHeaderBadgeIcon() {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return Icons.check_circle_outline;
      case VerificationStage.syncBlocked:
        return Icons.sync_problem_outlined;
      case VerificationStage.error:
        return Icons.cloud_off_outlined;
      default:
        return Icons.cloud_sync_outlined;
    }
  }

  String _getHeaderTitle() {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return 'Ready to Complete';
      case VerificationStage.syncBlocked:
        return 'Sync Incomplete';
      case VerificationStage.error:
        return 'Sync Check Failed';
      case VerificationStage.completing:
        return 'Completing Trip...';
      default:
        return 'Preparing Your Trip...';
    }
  }
}
