import 'dart:async';

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
import '../../../data/services/p2p_sync_service.dart';
import '../../../data/services/sync_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';

/// Comprehensive, production-grade Offline Synchronization Bottom Sheet.
/// Implements Phase 6 of Kith's Offline-First Architecture:
/// - Real-time connectivity diagnostics (Cloud, Wi-Fi Hotspot, BLE Nearby)
/// - Smart method recommendations (Internet, P2P Nearby, Wi-Fi Hotspot, No Devices)
/// - Live progress stage updates without fake percentage metrics
/// - Interactive manual controls (Sync Now, Find Nearby, Retry, View Pending)
class OfflineSynchronizationSheet extends StatefulWidget {
  final String? tripId;

  const OfflineSynchronizationSheet({super.key, this.tripId});

  static Future<void> show(BuildContext context, {String? tripId}) {
    HapticHelper.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineSynchronizationSheet(tripId: tripId),
    );
  }

  @override
  State<OfflineSynchronizationSheet> createState() => _OfflineSynchronizationSheetState();
}

class _OfflineSynchronizationSheetState extends State<OfflineSynchronizationSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<P2PStatus>? _p2pStatusSub;
  StreamSubscription<SyncStatus>? _syncStatusSub;

  bool _isSyncing = false;
  bool _isSearchingPeers = false;
  String? _activeProgressMessage;
  String? _lastError;
  bool _showPendingChanges = false;
  bool _showHotspotInstructions = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final syncService = context.read<SyncService?>();
      final p2pService = context.read<P2PSyncService?>();

      if (syncService != null) {
        _syncStatusSub = syncService.statusStream.listen((_) {
          if (mounted) setState(() {});
        });
      }
      if (p2pService != null) {
        _p2pStatusSub = p2pService.statusStream.listen((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _syncStatusSub?.cancel();
    _p2pStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _performInternetSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _activeProgressMessage = 'Connecting to Kith Cloud...';
      _lastError = null;
    });
    HapticHelper.medium();

    try {
      final syncService = context.read<SyncService>();
      final apiClient = context.read<ApiClient>();
      final authVm = context.read<AuthViewModel>();
      final homeVm = context.read<HomeViewModel>();

      setState(() => _activeProgressMessage = 'Uploading offline mutations...');
      await syncService.flushQueue(apiClient, force: true);

      final user = authVm.currentUser;
      if (user != null) {
        setState(() => _activeProgressMessage = 'Updating trip ledgers & balances...');
        await homeVm.loadTrips(user.id);
      }

      setState(() => _activeProgressMessage = 'Synchronization completed!');
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _activeProgressMessage = null;
        });
      }
    }
  }

  Future<void> _performNearbyP2PSync() async {
    if (_isSyncing) return;
    final p2pService = context.read<P2PSyncService?>();
    if (p2pService == null) return;

    setState(() {
      _isSyncing = true;
      _isSearchingPeers = true;
      _activeProgressMessage = 'Discovering nearby Kith devices...';
      _lastError = null;
    });
    HapticHelper.medium();

    try {
      await p2pService.start();
      setState(() => _activeProgressMessage = 'Checking nearby peer authorization...');
      await Future.delayed(const Duration(milliseconds: 1200));

      final peers = p2pService.activePeers;
      if (peers.isEmpty) {
        setState(() {
          _activeProgressMessage = 'No authorized devices found nearby.';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        return;
      }

      setState(() => _activeProgressMessage = 'Comparing pending changes with ${peers.length} peer${peers.length > 1 ? "s" : ""}...');
      final result = await p2pService.syncAllNearbyPeers(targetTripId: widget.tripId);

      if (result.success) {
        setState(() {
          _activeProgressMessage = 'Synced ${result.operationsSent} sent, ${result.operationsReceived} received!';
        });
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        setState(() => _lastError = 'P2P Sync partial or interrupted');
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isSearchingPeers = false;
          _activeProgressMessage = null;
        });
      }
    }
  }

  Future<void> _retryFailedChanges() async {
    final syncService = context.read<SyncService?>();
    final apiClient = context.read<ApiClient?>();
    if (syncService == null || apiClient == null) return;

    HapticHelper.medium();
    setState(() {
      _isSyncing = true;
      _activeProgressMessage = 'Re-queueing failed mutations...';
      _lastError = null;
    });

    try {
      await syncService.retryQuarantinedMutations(apiClient);
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _activeProgressMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final syncService = context.watch<SyncService?>();
    final p2pService = context.watch<P2PSyncService?>();

    final pendingMutations = widget.tripId != null
        ? (syncService?.getPendingMutationsForTrip(widget.tripId!) ?? [])
        : (syncService?.getPendingMutations(includeQuarantined: false) ?? []);
    final pendingCount = pendingMutations.length;
    final quarantinedCount = syncService?.quarantinedCount ?? 0;
    final syncStatus = syncService?.currentStatus ?? SyncStatus.offline;
    final nearbyPeers = p2pService?.activePeers ?? [];
    final nearbyCount = nearbyPeers.length;

    final isCloudOnline = syncStatus != SyncStatus.offline && syncStatus != SyncStatus.reconnecting;
    final isP2PAvailable = nearbyCount > 0;

    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13181E) : Colors.white,
        borderRadius: AppRadius.topSheetBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.20 : 0.10),
                    shape: BoxShape.circle,
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
                        'Offline Synchronization',
                        style: AppTypography.titleMedium(isDark: isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep your trip members in sync, even without internet.',
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: isDark ? Colors.white54 : secondaryTextColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Live Progress Banner (if active)
                if (_isSyncing && _activeProgressMessage != null)
                  _buildLiveProgressBanner(isDark),

                // Error Banner (if any)
                if (_lastError != null)
                  _buildErrorBanner(isDark),

                // 1. Status Overview Card
                _buildStatusOverviewCard(
                  isDark: isDark,
                  pendingCount: pendingCount,
                  quarantinedCount: quarantinedCount,
                  nearbyCount: nearbyCount,
                  isCloudOnline: isCloudOnline,
                  lastSyncTime: p2pService?.lastSyncTimestamp,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 2. Smart Recommendation Section Header
                Text(
                  'RECOMMENDED SYNCHRONIZATION METHOD',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : secondaryTextColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Smart Recommendation Cards
                if (isCloudOnline)
                  _buildMethod1InternetCard(isDark, pendingCount)
                else if (isP2PAvailable)
                  _buildMethod2NearbyCard(isDark, nearbyPeers, pendingCount)
                else
                  _buildMethod4NoNearbyDevicesCard(isDark),

                const SizedBox(height: AppSpacing.md),

                // Method 3: Wi-Fi Hotspot Option (Always expandable)
                _buildMethod3HotspotCard(isDark),

                const SizedBox(height: AppSpacing.lg),

                // 3. Pending Operations Preview (Expandable)
                if (pendingCount > 0)
                  _buildPendingOperationsSection(isDark, pendingMutations),

                const SizedBox(height: AppSpacing.lg),

                // 4. Manual Controls
                _buildManualControlsSection(
                  isDark: isDark,
                  isCloudOnline: isCloudOnline,
                  quarantinedCount: quarantinedCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveProgressBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _activeProgressMessage!,
              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _lastError!,
              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                color: const Color(0xFFE11D48),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFE11D48)),
            onPressed: () => setState(() => _lastError = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverviewCard({
    required bool isDark,
    required int pendingCount,
    required int quarantinedCount,
    required int nearbyCount,
    required bool isCloudOnline,
    required DateTime? lastSyncTime,
  }) {
    final statusColor = pendingCount > 0
        ? const Color(0xFFF59E0B)
        : (quarantinedCount > 0 ? const Color(0xFFE11D48) : AppColors.emeraldPrimary);
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCloudOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCloudOnline ? 'Internet Online' : 'Offline Mode',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                lastSyncTime != null
                    ? 'Last synced ${DateFormat('h:mm a').format(lastSyncTime)}'
                    : 'Synced locally',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildOverviewMetric(
                label: 'Pending Changes',
                value: '$pendingCount',
                color: pendingCount > 0 ? const Color(0xFFF59E0B) : AppColors.emeraldPrimary,
                isDark: isDark,
              ),
              Container(width: 1, height: 32, color: isDark ? Colors.white12 : Colors.black12),
              _buildOverviewMetric(
                label: 'Nearby Peers',
                value: '$nearbyCount',
                color: nearbyCount > 0 ? const Color(0xFF3B82F6) : secondaryTextColor,
                isDark: isDark,
              ),
              Container(width: 1, height: 32, color: isDark ? Colors.white12 : Colors.black12),
              _buildOverviewMetric(
                label: 'Failed / Blocked',
                value: '$quarantinedCount',
                color: quarantinedCount > 0 ? const Color(0xFFE11D48) : AppColors.emeraldPrimary,
                isDark: isDark,
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your changes are safely stored on this device in SQLite WAL storage. They will be shared as soon as an authorized peer or cloud connection is established.',
              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                fontSize: 11,
                color: secondaryTextColor,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewMetric({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMethod1InternetCard(bool isDark, int pendingCount) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: AppColors.emeraldPrimary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Internet Available',
                      style: AppTypography.titleSmall(isDark: isDark).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Your changes will synchronize securely with Kith\'s cloud.',
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: _isSyncing ? 'Syncing...' : 'Sync Now',
            onPressed: _isSyncing ? null : _performInternetSync,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMethod2NearbyCard(bool isDark, List<NearbyPeer> peers, int pendingCount) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync with Nearby Trip Members',
                      style: AppTypography.titleSmall(isDark: isDark).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${peers.length} authorized member${peers.length > 1 ? "s" : ""} discovered nearby.',
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Discovered peers list
          ...peers.map((peer) => Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      child: Text(
                        peer.displayName.isNotEmpty ? peer.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peer.displayName,
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (peer.isBleOnly ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        peer.transport.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: peer.isBleOnly ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: _isSyncing ? 'Syncing...' : 'Sync with Nearby Peers',
            onPressed: _isSyncing ? null : _performNearbyP2PSync,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMethod3HotspotCard(bool isDark) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showHotspotInstructions = !_showHotspotInstructions),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.wifi_rounded, color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync using a Local Wi-Fi Connection',
                        style: AppTypography.titleSmall(isDark: isDark).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Connect via portable hotspot or shared local network without internet.',
                        style: TextStyle(fontSize: 11, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showHotspotInstructions ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: isDark ? Colors.white54 : secondaryTextColor,
                ),
              ],
            ),
          ),
          if (_showHotspotInstructions) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _buildHotspotStep('1', 'Enable your mobile hotspot or connect both phones to the same local Wi-Fi router.'),
            _buildHotspotStep('2', 'Ask other trip members to join the same network.'),
            _buildHotspotStep('3', 'Keep Kith open on both devices.'),
            _buildHotspotStep('4', 'Select "Find Nearby Devices" to discover peers on the local subnet.'),
            _buildHotspotStep('5', 'Once mutual authentication completes, your ledger updates instantly.'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Note: Direct communication works even if the Wi-Fi network has no external internet connection. However, if AP client isolation is enabled on corporate routers, mobile hotspot is recommended.',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : secondaryTextColor,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHotspotStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethod4NoNearbyDevicesCard(bool isDark) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bluetooth_searching_rounded,
                  color: isDark ? Colors.white70 : secondaryTextColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Nearby Devices Found',
                      style: AppTypography.titleSmall(isDark: isDark).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Ask other members to open Kith nearby to start P2P sync.',
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '• Keep phones within 10 meters of each other.\n• Ensure Bluetooth and Nearby permissions are enabled.\n• Alternatively, connect both devices to a mobile hotspot.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            text: _isSearchingPeers ? 'Searching...' : 'Find Nearby Devices',
            onPressed: _isSearchingPeers ? null : _performNearbyP2PSync,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOperationsSection(bool isDark, List<SyncMutation> mutations) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showPendingChanges = !_showPendingChanges),
            child: Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Changes (${mutations.length})',
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Icon(
                  _showPendingChanges ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isDark ? Colors.white54 : secondaryTextColor,
                ),
              ],
            ),
          ),
          if (_showPendingChanges) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            ...mutations.take(15).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatMutationTitle(m),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(m.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _formatMutationTitle(SyncMutation m) {
    switch (m.type) {
      case MutationType.addExpense:
        return 'Add expense: ${m.payload['title'] ?? 'Expense'}';
      case MutationType.updateExpense:
        return 'Edit expense: ${m.payload['title'] ?? 'Expense'}';
      case MutationType.deleteExpense:
        return 'Delete expense ${m.payload['expenseId'] ?? m.payload['id'] ?? ''}';
      case MutationType.createTrip:
        return 'Create trip: ${m.payload['name'] ?? 'Trip'}';
      case MutationType.joinTrip:
        return 'Join trip';
      case MutationType.addMember:
        return 'Add member: ${m.payload['displayName'] ?? 'Member'}';
      case MutationType.updateTripLifecycle:
        return 'Update trip lifecycle: ${m.payload['lifecycleState'] ?? ''}';
      case MutationType.recordTripSettlement:
        return 'Record settlement';
      default:
        return m.type.name;
    }
  }

  Widget _buildManualControlsSection({
    required bool isDark,
    required bool isCloudOnline,
    required int quarantinedCount,
  }) {
    return Column(
      children: [
        if (quarantinedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Retry $quarantinedCount Failed Changes'),
              onPressed: _isSyncing ? null : _retryFailedChanges,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE11D48),
                side: const BorderSide(color: Color(0xFFE11D48)),
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Find Nearby'),
                onPressed: _isSyncing ? null : _performNearbyP2PSync,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                label: const Text('Sync Now'),
                onPressed: _isSyncing ? null : _performInternetSync,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
