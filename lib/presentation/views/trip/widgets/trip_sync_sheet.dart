import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../data/services/p2p_sync_service.dart';
import '../../../../data/services/sync_service.dart';

/// Interactive, production-grade bottom sheet for Trip Synchronization.
/// Shows real-time multi-source transparency across Kith Cloud (Supabase) and nearby P2P friends.
class TripSyncSheet extends StatefulWidget {
  final String tripId;
  final SyncService syncService;
  final P2PSyncService p2pService;
  final ApiClient? apiClient;
  final VoidCallback? onSyncCompleted;

  const TripSyncSheet({
    super.key,
    required this.tripId,
    required this.syncService,
    required this.p2pService,
    this.apiClient,
    this.onSyncCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required SyncService syncService,
    required P2PSyncService p2pService,
    ApiClient? apiClient,
    VoidCallback? onSyncCompleted,
  }) {
    HapticHelper.light();
    ApiClient? resolvedApiClient = apiClient;
    if (resolvedApiClient == null) {
      try {
        resolvedApiClient = context.read<ApiClient>();
      } catch (_) {}
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripSyncSheet(
        tripId: tripId,
        syncService: syncService,
        p2pService: p2pService,
        apiClient: resolvedApiClient,
        onSyncCompleted: onSyncCompleted,
      ),
    );
  }

  @override
  State<TripSyncSheet> createState() => _TripSyncSheetState();
}

class _TripSyncSheetState extends State<TripSyncSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  TripSyncReport? _syncReport;
  bool _isReconciling = false;
  String? _syncingSourceName;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Automatically trigger initial multi-source reconciliation
    _performFullTripSync();
  }

  @override
  void dispose() {
    _radarController.dispose();
    widget.p2pService.stop();
    super.dispose();
  }

  Future<void> _performFullTripSync() async {
    setState(() {
      _isReconciling = true;
      _syncingSourceName = 'Kith Cloud & Nearby';
    });

    // Start 45s battery-safe discovery session for nearby peers
    widget.p2pService.startDiscoverySession(timeout: const Duration(seconds: 45));

    final report = await widget.syncService.reconcileTripWithAllSources(
      tripId: widget.tripId,
      apiClient: widget.apiClient,
      p2pService: widget.p2pService,
    );

    if (mounted) {
      setState(() {
        _isReconciling = false;
        _syncReport = report;
        _syncingSourceName = null;
      });

      if (report.isFullySynced) {
        HapticHelper.success();
      } else if (report.sources.any((s) => s.isSuccess)) {
        HapticHelper.medium();
      } else {
        HapticHelper.error();
      }

      widget.onSyncCompleted?.call();
    }
  }

  Future<void> _syncWithSpecificPeer(NearbyPeer peer) async {
    setState(() {
      _isReconciling = true;
      _syncingSourceName = peer.displayName;
    });
    HapticHelper.selection();

    final result = await widget.p2pService.syncWithPeer(peer);

    // Refresh overall report
    final updatedReport = await widget.syncService.reconcileTripWithAllSources(
      tripId: widget.tripId,
      apiClient: widget.apiClient,
      p2pService: widget.p2pService,
    );

    if (mounted) {
      setState(() {
        _isReconciling = false;
        _syncReport = updatedReport;
        _syncingSourceName = null;
      });

      if (result.success) {
        HapticHelper.success();
      } else {
        HapticHelper.error();
      }

      widget.onSyncCompleted?.call();
    }
  }

  Future<void> _retryCloudSync() async {
    setState(() {
      _isReconciling = true;
      _syncingSourceName = 'Kith Cloud (Supabase)';
    });
    HapticHelper.selection();

    final updatedReport = await widget.syncService.reconcileTripWithAllSources(
      tripId: widget.tripId,
      apiClient: widget.apiClient,
      p2pService: widget.p2pService,
    );

    if (mounted) {
      setState(() {
        _isReconciling = false;
        _syncReport = updatedReport;
        _syncingSourceName = null;
      });
      widget.onSyncCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomInset > 0 ? bottomInset + 12 : 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row & Live Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          color: AppColors.emeraldPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Synchronization',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Cloud & Offline Nearby Sources',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 20,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Active Loading / Reconciling Banner
              if (_isReconciling)
                _buildSyncingBanner(theme, isDark)
              else if (_syncReport != null)
                _buildSummaryBadge(theme, isDark, _syncReport!),

              const SizedBox(height: 16),

              // Sources Section Header
              Text(
                'SYNCHRONIZATION SOURCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 10),

              // 1. Cloud (Supabase / Server) Source Tile
              _buildCloudSourceTile(theme, isDark),
              const SizedBox(height: 12),

              // 2. Nearby Friends P2P Discovery Tiles
              _buildNearbyPeersSection(theme, isDark),

              const SizedBox(height: 18),

              // Action Buttons: Done / Retry All
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isReconciling ? null : _performFullTripSync,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Sync All Again', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncingBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.emeraldPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Reconciling changes with ${_syncingSourceName ?? "sources"}...',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(ThemeData theme, bool isDark, TripSyncReport report) {
    final isAllOffline = report.sources.isNotEmpty && report.sources.every((s) => s.status == 'offline');
    final isFullySynced = report.isFullySynced;

    Color color;
    IconData icon;
    String title;
    String subtitle;

    if (isAllOffline) {
      color = const Color(0xFFF59E0B);
      icon = Icons.cloud_off_rounded;
      title = 'Offline Mode • Changes Queued';
      subtitle = '${report.pendingChangesCount} changes queued locally • Auto-syncs when online or near friends';
    } else if (isFullySynced) {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
      title = 'All Sources Synchronized 🎉';
      subtitle = '${report.totalChangesSent} sent • ${report.totalChangesReceived} received • 0 pending';
    } else if (report.sources.any((s) => s.isSuccess)) {
      color = AppColors.emeraldPrimary;
      icon = Icons.cloud_done_rounded;
      title = 'Synchronized with Available Sources';
      subtitle = '${report.totalChangesSent} sent • ${report.totalChangesReceived} received • ${report.pendingChangesCount} waiting';
    } else {
      color = const Color(0xFFEF4444);
      icon = Icons.warning_amber_rounded;
      title = 'Sync Incomplete';
      subtitle = report.errorMessage ?? 'Please check connection and retry';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSourceTile(ThemeData theme, bool isDark) {
    final cloudResult = _syncReport?.sources.where((s) => s.type == SyncSourceType.cloud).firstOrNull;
    final isOffline = cloudResult?.status == 'offline';
    final isFailed = cloudResult != null && !cloudResult.isSuccess && !isOffline;
    final isSuccess = cloudResult != null && cloudResult.isSuccess;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262C3D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_done_rounded, size: 18, color: AppColors.emeraldPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kith Cloud (Supabase)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  isSuccess
                      ? '${cloudResult.changesSent} sent • ${cloudResult.changesReceived} received'
                      : (isOffline ? 'Offline • Device not connected to internet' : (cloudResult?.errorMessage ?? 'Ready to connect')),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isFailed
                        ? const Color(0xFFEF4444)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          if (isFailed || isOffline)
            TextButton(
              onPressed: _retryCloudSync,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            )
          else if (isSuccess)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
        ],
      ),
    );
  }

  Widget _buildNearbyPeersSection(ThemeData theme, bool isDark) {
    return StreamBuilder<List<NearbyPeer>>(
      stream: widget.p2pService.peersStream,
      initialData: widget.p2pService.activePeers,
      builder: (context, snapshot) {
        final peers = snapshot.data ?? [];
        final tripPeers = peers.where((p) => p.sharedTripIds.contains(widget.tripId)).toList();
        final otherPeers = peers.where((p) => !p.sharedTripIds.contains(widget.tripId)).toList();

        if (peers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262C3D).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_radarController.value * 0.15),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                            ),
                            child: const Icon(Icons.wifi_tethering_rounded, size: 18, color: AppColors.emeraldPrimary),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Searching for Nearby Friends...',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Turn on Wi-Fi / Hotspot & Bluetooth to pair.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticHelper.light();
                      await PermissionService.requestNearbyPermissions();
                      widget.p2pService.startDiscoverySession(timeout: const Duration(seconds: 60));
                      _performFullTripSync();
                    },
                    icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                    label: const Text('Search Nearby / Bluetooth Devices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            ...tripPeers.map((peer) => _buildPeerTile(peer, isDark, isTripPeer: true)),
            ...otherPeers.map((peer) => _buildPeerTile(peer, isDark, isTripPeer: false)),
          ],
        );
      },
    );
  }

  Widget _buildPeerTile(NearbyPeer peer, bool isDark, {required bool isTripPeer}) {
    final peerResult = _syncReport?.sources.where((s) => s.name == peer.displayName).firstOrNull;
    final isPeerSuccess = peerResult != null && peerResult.isSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262C3D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
            child: Text(
              peer.displayName.isNotEmpty ? peer.displayName.substring(0, 1).toUpperCase() : 'F',
              style: const TextStyle(color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  isPeerSuccess
                      ? '${peerResult.changesSent} sent • ${peerResult.changesReceived} received'
                      : (isTripPeer ? 'Pairing Code: ${peer.pairingCode}' : 'Nearby Device • Tap to Pair & Sync'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isPeerSuccess
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontWeight: isPeerSuccess ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isReconciling ? null : () => _syncWithSpecificPeer(peer),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(isTripPeer ? 'Sync' : 'Pair & Sync', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
