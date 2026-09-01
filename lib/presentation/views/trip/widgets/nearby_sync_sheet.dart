import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../data/services/p2p_sync_service.dart';
import '../../../../data/services/sync_service.dart';

/// Modal bottom sheet for intentional, battery-safe Offline Nearby P2P Sync.
class NearbySyncSheet extends StatefulWidget {
  final P2PSyncService p2pService;
  final SyncService syncService;
  final String? initialTripId;

  const NearbySyncSheet({
    super.key,
    required this.p2pService,
    required this.syncService,
    this.initialTripId,
  });

  static Future<void> show(
    BuildContext context, {
    required P2PSyncService p2pService,
    required SyncService syncService,
    String? tripId,
  }) {
    HapticHelper.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NearbySyncSheet(
        p2pService: p2pService,
        syncService: syncService,
        initialTripId: tripId,
      ),
    );
  }

  @override
  State<NearbySyncSheet> createState() => _NearbySyncSheetState();
}

class _NearbySyncSheetState extends State<NearbySyncSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  NearbySyncResult? _lastResult;
  NearbyPeer? _selectedPeer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Start battery-safe 45s discovery session
    widget.p2pService.startDiscoverySession(timeout: const Duration(seconds: 45));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.p2pService.stop();
    super.dispose();
  }

  Future<void> _handleSyncWithPeer(NearbyPeer peer) async {
    setState(() {
      _selectedPeer = peer;
      _isSyncing = true;
    });
    HapticHelper.selection();

    final result = await widget.p2pService.syncWithPeer(peer);

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _lastResult = result;
      });
      if (result.success) {
        HapticHelper.success();
      } else {
        HapticHelper.error();
      }
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
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              // Title & Close Button
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
                          Icons.wifi_tethering_rounded,
                          color: AppColors.emeraldPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Nearby Sync',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Peer-to-peer without internet',
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
              const SizedBox(height: 20),

              // Content Body based on state
              if (_isSyncing)
                _buildSyncingView(theme, isDark)
              else if (_lastResult != null)
                _buildResultView(theme, isDark, _lastResult!)
              else
                StreamBuilder<List<NearbyPeer>>(
                  stream: widget.p2pService.peersStream,
                  initialData: widget.p2pService.activePeers,
                  builder: (context, snapshot) {
                    final peers = snapshot.data ?? [];
                    return StreamBuilder<P2PStatus>(
                      stream: widget.p2pService.statusStream,
                      initialData: widget.p2pService.status,
                      builder: (context, statusSnapshot) {
                        final status = statusSnapshot.data ?? P2PStatus.discovering;
                        if (peers.isNotEmpty) {
                          return _buildPeersListView(theme, isDark, peers);
                        }
                        if (status == P2PStatus.timeout) {
                          return _buildTimeoutView(theme, isDark);
                        }
                        return _buildSearchingView(theme, isDark);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (_pulseController.value * 0.12);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.emeraldPrimary.withValues(
                      alpha: 0.2 + (_pulseController.value * 0.3),
                    ),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: AppColors.emeraldPrimary,
                  size: 36,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Searching for nearby Kith friends...',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ensure both phones are on the same Wi-Fi\nor one device has Hotspot turned on.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.emeraldPrimary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'End-to-end encrypted • Only exchanges shared trip data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeersListView(ThemeData theme, bool isDark, List<NearbyPeer> peers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nearby Devices Found (${peers.length})',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...peers.map((peer) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262C3D) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      child: Text(
                        peer.displayName.isNotEmpty
                            ? peer.displayName.substring(0, 1).toUpperCase()
                            : 'K',
                        style: const TextStyle(
                          color: AppColors.emeraldPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peer.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            peer.sharedTripNames.isNotEmpty
                                ? 'Shared: ${peer.sharedTripNames.join(", ")}'
                                : '${peer.sharedTripIds.length} shared trip(s)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Pairing verification badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pairing Code',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      Text(
                        peer.pairingCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 2,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSyncWithPeer(peer),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text(
                      'Verify & Sync Changes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSyncingView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            color: AppColors.emeraldPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Syncing with ${_selectedPeer?.displayName ?? "nearby friend"}...',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Exchanging offline expenses, debts, and settlements securely.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResultView(ThemeData theme, bool isDark, NearbySyncResult result) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: result.success
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFEF4444).withValues(alpha: 0.15),
          ),
          child: Icon(
            result.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: result.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          result.success ? 'Offline Sync Complete 🎉' : 'Sync Incomplete',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.success
              ? '${result.operationsSent} sent • ${result.operationsReceived} received\nRecords will sync to Supabase when internet returns.'
              : result.errorMessage ?? 'Could not complete transfer.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white12 : Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.wifi_find_rounded,
          size: 48,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        const SizedBox(height: 16),
        Text(
          'No nearby Kith devices found',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Make sure both devices have Kith open and are\non the same Wi-Fi network or Hotspot.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              widget.p2pService.startDiscoverySession();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Search Again', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
