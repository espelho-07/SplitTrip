import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
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
import '../../../viewmodels/home_viewmodel.dart';
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
  String _statusMessage = '';
  TripSyncStatus? _syncStatus;
  String? _errorMessage;
  bool _isOffline = false;
  bool _isRequestingConsent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  Future<void> _startVerification() async {
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _stage = VerificationStage.checkingConnectivity;
      _progress = 0.10;
      _statusMessage = l10n.tripCompCheckingConnectivity;
      _errorMessage = null;
      _isOffline = false;
    });

    final tripRepo = context.read<TripRepository>();
    final syncService = Provider.of<SyncService?>(context, listen: false);

    try {
      // Step 1: Connectivity check (10%)
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Step 2: Flush current device local pending changes (25%)
      if (mounted) {
        setState(() {
          _stage = VerificationStage.flushingLocal;
          _progress = 0.25;
          _statusMessage = l10n.tripCompFlushingLocal;
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
          _statusMessage = l10n.tripCompQueryingState;
        });
      }

      TripSyncStatus status = await tripRepo.getTripSyncStatus(widget.tripId);

      if (!mounted) return;
      final authVm = Provider.of<AuthViewModel?>(context, listen: false);
      final currentUid = authVm?.currentUser?.id ?? '';
      final cachedTrip = tripRepo.getCachedTripById(widget.tripId);
      final hasOnlyVirtualPeers = cachedTrip != null && cachedTrip.members.every(
        (m) => m.isVirtual || m.userId == currentUid || m.id == currentUid,
      );

      // Step 4: Realtime sync request if needed
      if (!status.isFullySynced && !hasOnlyVirtualPeers) {
        if (mounted) {
          setState(() {
            _stage = VerificationStage.requestingSync;
            _progress = 0.75;
            _statusMessage = l10n.tripCompCheckingParticipants;
          });
        }

        await tripRepo.requestTripSync(widget.tripId);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        status = await tripRepo.getTripSyncStatus(widget.tripId);
      }

      // Step 5: Final verification evaluation (100%)
      if (mounted) {
        setState(() {
          _stage = VerificationStage.verifying;
          _progress = 0.90;
          _statusMessage = l10n.tripCompCheckingParticipants;
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (mounted) {
        setState(() {
          _syncStatus = status;
          _progress = 1.0;
          if (status.canCompleteNormally) {
            _stage = VerificationStage.readyToComplete;
            _statusMessage = l10n.tripCompReadyDesc;
          } else {
            _stage = VerificationStage.syncBlocked;
            _statusMessage = status.blockReason ?? l10n.tripCompPendingDesc;
          }
        });
        HapticHelper.selection();
      }
    } on NetworkException catch (e) {
      // Mandatory Rule: Trip Owner MUST be online. If offline: block trip completion.
      // Do NOT fall back to local offline completion or mark ready to complete.
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _isOffline = true;
          _errorMessage = e.message.contains('offline')
              ? e.message
              : "You're currently offline. Connect to the internet before completing this trip.";
        });
        HapticHelper.error();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        HapticHelper.error();
      }
    }
  }

  Future<void> _requestConsent(ParticipantSyncInfo p) async {
    final tripRepo = context.read<TripRepository>();
    setState(() => _isRequestingConsent = true);
    try {
      await tripRepo.requestCompletionConsent(widget.tripId, p.memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmation request sent to ${p.displayName}'),
            backgroundColor: AppColors.emeraldPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
        HapticHelper.success();
        await _startVerification();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request confirmation: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.negativeRedLight,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingConsent = false);
      }
    }
  }

  Future<void> _requestAllConsent() async {
    final tripRepo = context.read<TripRepository>();
    setState(() => _isRequestingConsent = true);
    try {
      final reqs = await tripRepo.batchRequestCompletionConsent(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent confirmation requests to ${reqs.length} members'),
            backgroundColor: AppColors.emeraldPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
        HapticHelper.success();
        await _startVerification();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.negativeRedLight,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingConsent = false);
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
        isOwnerOnline: !_isOffline,
      );

      final currentUid = authVm.currentUser?.id ?? '';

      // Update HomeViewModel directly if present in provider tree
      if (mounted) {
        try {
          final homeVm = Provider.of<HomeViewModel?>(context, listen: false);
          homeVm?.refresh(currentUid);
        } catch (_) {}
      }

      await tripDetailVm.refresh(currentUid);

      if (mounted) {
        HapticHelper.success();
        widget.onTripCompleted?.call();
        Navigator.pop(context, true);
      }
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _isOffline = true;
          _errorMessage = e.message;
        });
        HapticHelper.error();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = VerificationStage.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        HapticHelper.error();
      }
    }
  }

  void _promptForcedCompletionConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amberAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.tripCompDialogTitle,
                style: AppTypography.titleMedium(isDark: isDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tripCompDialogDesc,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.tripCompDialogCancel, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
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
            child: Text(l10n.tripCompDialogConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final isVerifying = _stage == VerificationStage.checkingConnectivity ||
        _stage == VerificationStage.flushingLocal ||
        _stage == VerificationStage.queryingTripState ||
        _stage == VerificationStage.requestingSync ||
        _stage == VerificationStage.verifying ||
        _stage == VerificationStage.completing;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                      _getHeaderTitle(l10n),
                      style: AppTypography.titleLarge(isDark: isDark),
                    ),
                    Text(
                      l10n.tripCompSyncSub,
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
          const SizedBox(height: AppSpacing.sm),

          // Scrollable middle section
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Participant Presence & Consent Breakdown Card
                  if (_syncStatus != null && _syncStatus!.participants.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Member Availability & Consent',
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (_hasUnconfirmedMembers())
                          TextButton.icon(
                            icon: _isRequestingConsent
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Ask All', style: TextStyle(fontSize: 12)),
                            onPressed: _isRequestingConsent ? null : _requestAllConsent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                        borderRadius: AppRadius.mdBorder,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _syncStatus!.participants.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                              ),
                            _buildParticipantRow(_syncStatus!.participants[i], isDark, l10n),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Notice Banners
                  if (_stage == VerificationStage.readyToComplete) ...[
                    _buildNoticeBanner(
                      isDark: isDark,
                      color: AppColors.emeraldPrimary,
                      icon: Icons.check_circle_outline,
                      title: l10n.tripCompReadyTitle,
                      description: 'All trip members are accounted for and all balances are settled. You can safely complete the trip.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (_stage == VerificationStage.syncBlocked) ...[
                    _buildNoticeBanner(
                      isDark: isDark,
                      color: _syncStatus?.isCompletionBlocked == true
                          ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
                          : AppColors.amberAccent,
                      icon: Icons.warning_amber_rounded,
                      title: _syncStatus?.isCompletionBlocked == true
                          ? 'Completion Blocked'
                          : l10n.tripCompPendingTitle,
                      description: _syncStatus?.blockReason ??
                          'One or more members are offline and have not confirmed their availability.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (_stage == VerificationStage.error) ...[
                    _buildNoticeBanner(
                      isDark: isDark,
                      color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                      icon: Icons.cloud_off_outlined,
                      title: _isOffline ? "You're Offline" : 'Verification Failed',
                      description: _errorMessage ?? "You're currently offline. Connect to the internet before completing this trip.",
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Action Buttons
          _buildActionButtons(isDark, l10n),
        ],
      ),
    );
  }

  bool _hasUnconfirmedMembers() {
    if (_syncStatus == null) return false;
    return _syncStatus!.participants.any(
      (p) => !p.isVirtual && !p.isCurrentUser && !p.isCreator && p.consentStatus != 'CONFIRMED_AVAILABLE',
    );
  }

  Widget _buildParticipantRow(ParticipantSyncInfo p, bool isDark, AppLocalizations l10n) {
    final isOnline = p.presenceStatus == 'ONLINE' || p.isOnline;
    final isVirtual = p.isVirtual || p.presenceStatus == 'VIRTUAL_ACCOUNTED';
    final isConfirmed = p.consentStatus == 'CONFIRMED_AVAILABLE';
    final isRejected = p.consentStatus == 'UNAVAILABLE';
    final isPending = p.consentStatus == 'PENDING';

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
                    color: isOnline ? AppColors.positiveGreenLight : AppColors.lightTextMuted,
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
                        p.isCurrentUser ? '${p.displayName} (${l10n.translate('balance_you')})' : p.displayName,
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
                          l10n.tripCompHostTag,
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
                  isVirtual
                      ? 'Managed by you • Auto-accounted'
                      : (isConfirmed
                          ? 'Availability confirmed'
                          : (isRejected
                              ? (p.consentResponseNote ?? 'Blocked: has pending expenses')
                              : (isPending
                                  ? 'Awaiting response...'
                                  : (isOnline ? 'Online now' : 'Last active ${p.lastSyncFormatted}')))),
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(
                    color: isRejected
                        ? (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight)
                        : (isConfirmed ? AppColors.positiveGreenLight : null),
                  ),
                ),
              ],
            ),
          ),
          if (!isVirtual && !p.isCurrentUser && !isConfirmed && !isRejected && !isPending && !isOnline)
            IconButton(
              icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.emeraldPrimary),
              tooltip: 'Request Confirmation',
              onPressed: _isRequestingConsent ? null : () => _requestConsent(p),
            )
          else
            _buildPresenceBadge(p, isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildPresenceBadge(ParticipantSyncInfo p, bool isDark, AppLocalizations l10n) {
    if (p.isVirtual || p.presenceStatus == 'VIRTUAL_ACCOUNTED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.indigoAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Virtual', style: TextStyle(color: AppColors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }

    if (p.consentStatus == 'CONFIRMED_AVAILABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.positiveGreenLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 12, color: AppColors.positiveGreenLight),
            SizedBox(width: 4),
            Text('Confirmed', style: TextStyle(color: AppColors.positiveGreenLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (p.consentStatus == 'UNAVAILABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.negativeRedLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 12, color: AppColors.negativeRedLight),
            SizedBox(width: 4),
            Text('Unavailable', style: TextStyle(color: AppColors.negativeRedLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (p.consentStatus == 'PENDING') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.amberAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.amberAccent)),
            SizedBox(width: 4),
            Text('Pending', style: TextStyle(color: AppColors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (p.presenceStatus == 'ONLINE' || p.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.positiveGreenLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Online', style: TextStyle(color: AppColors.positiveGreenLight, fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Offline', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
    );
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

  Widget _buildActionButtons(bool isDark, AppLocalizations l10n) {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: l10n.tripCompKeepOpenBtn,
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: l10n.tripCompTitle,
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
                text: l10n.tripCompKeepOpenBtn,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: l10n.tripCompMarkAnywayBtn,
                variant: AppButtonVariant.outline,
                onPressed: _syncStatus?.isCompletionBlocked == true ? null : _promptForcedCompletionConfirmation,
              ),
            ),
          ],
        );
      case VerificationStage.error:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: l10n.actionCancel,
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                text: l10n.actionRetry,
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
              l10n.tripCompPleaseWait,
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

  String _getHeaderTitle(AppLocalizations l10n) {
    switch (_stage) {
      case VerificationStage.readyToComplete:
        return l10n.tripCompReadyTitle;
      case VerificationStage.syncBlocked:
        return l10n.tripCompPendingTitle;
      case VerificationStage.error:
        return _isOffline ? "You're Offline" : l10n.tripCompOfflineTitle;
      case VerificationStage.completing:
        return l10n.tripCompTitle;
      default:
        return l10n.tripCompPreparing;
    }
  }
}
