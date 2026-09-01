import 'package:flutter/material.dart';
import '../../../../data/services/p2p_sync_service.dart';
import '../../../../data/services/sync_service.dart';
import 'trip_sync_sheet.dart';

class NearbySyncBadge extends StatelessWidget {
  final P2PSyncService p2pService;
  final SyncService syncService;
  final String tripId;

  const NearbySyncBadge({
    super.key,
    required this.p2pService,
    required this.syncService,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<P2PStatus>(
      stream: p2pService.statusStream,
      initialData: p2pService.status,
      builder: (context, p2pSnapshot) {
        return StreamBuilder<int>(
          stream: p2pService.peerCountStream,
          initialData: p2pService.nearbyPeerCount,
          builder: (context, peerCountSnapshot) {
            final peerCount = peerCountSnapshot.data ?? 0;
            final p2pStatus = p2pSnapshot.data ?? P2PStatus.idle;
            final pendingMutations = syncService.getPendingMutationsForTrip(tripId);
            final p2pSharedCount = pendingMutations.where((m) => m.syncState == SyncState.p2pShared).length;

            if (peerCount == 0 && pendingMutations.isEmpty) {
              return const SizedBox.shrink();
            }

            String label;
            IconData icon;
            Color color;

            if (p2pStatus == P2PStatus.syncing) {
              label = 'Syncing with $peerCount nearby...';
              icon = Icons.sync_rounded;
              color = const Color(0xFF6366F1);
            } else if (p2pSharedCount > 0) {
              label = '$p2pSharedCount shared nearby';
              icon = Icons.wifi_tethering_rounded;
              color = const Color(0xFF10B981);
            } else if (peerCount > 0) {
              label = '$peerCount friend${peerCount > 1 ? "s" : ""} nearby';
              icon = Icons.wifi_tethering_rounded;
              color = const Color(0xFF3B82F6);
            } else {
              label = '${pendingMutations.length} pending offline';
              icon = Icons.cloud_queue_rounded;
              color = const Color(0xFFF59E0B);
            }

            return GestureDetector(
              onTap: () {
                TripSyncSheet.show(
                  context,
                  tripId: tripId,
                  syncService: syncService,
                  p2pService: p2pService,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
