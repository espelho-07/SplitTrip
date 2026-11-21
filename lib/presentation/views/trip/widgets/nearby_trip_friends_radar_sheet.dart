import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/services/p2p_sync_service.dart';
import '../../../../data/services/sync_service.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';
import '../../../../core/widgets/member_avatar.dart';

/// Interactive Radar Sheet showing all trip friends and enabling 1-tap mesh sync.
class NearbyTripFriendsRadarSheet extends StatefulWidget {
  final Trip trip;
  final P2PSyncService p2pService;
  final SyncService syncService;
  final VoidCallback? onSyncCompleted;

  const NearbyTripFriendsRadarSheet({
    super.key,
    required this.trip,
    required this.p2pService,
    required this.syncService,
    this.onSyncCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required P2PSyncService p2pService,
    required SyncService syncService,
    VoidCallback? onSyncCompleted,
  }) {
    HapticHelper.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NearbyTripFriendsRadarSheet(
        trip: trip,
        p2pService: p2pService,
        syncService: syncService,
        onSyncCompleted: onSyncCompleted,
      ),
    );
  }

  @override
  State<NearbyTripFriendsRadarSheet> createState() => _NearbyTripFriendsRadarSheetState();
}

class _NearbyTripFriendsRadarSheetState extends State<NearbyTripFriendsRadarSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  StreamSubscription<List<NearbyPeer>>? _peersSub;
  List<NearbyPeer> _peers = [];
  bool _isSyncingAll = false;
  NearbyMeshSyncResult? _meshResult;
  String? _syncingPeerId;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _peers = widget.p2pService.activePeers;
    _peersSub = widget.p2pService.peersStream.listen((updated) {
      if (mounted) {
        setState(() {
          _peers = updated;
        });
      }
    });

    // Start 60-second active discovery session with BLE and Mesh
    widget.p2pService.startDiscoverySession(
      timeout: const Duration(seconds: 60),
      targetTripId: widget.trip.id,
    );
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _radarController.dispose();
    widget.p2pService.stop();
    super.dispose();
  }

  Future<void> _handleSyncAll() async {
    if (_isSyncingAll) return;
    setState(() {
      _isSyncingAll = true;
      _meshResult = null;
    });
    HapticHelper.selection();

    // 1. Opportunistically flush local outbox to cloud if online
    try {
      final apiClient = context.read<ApiClient>();
      await widget.syncService.flushQueue(apiClient, force: true);
      await widget.syncService.syncTripBatchWithServer(apiClient, widget.trip.id);
    } catch (_) {}

    // 2. Perform direct offline P2P mesh synchronization
    final res = await widget.p2pService.syncAllNearbyPeers(targetTripId: widget.trip.id);

    if (mounted) {
      setState(() {
        _isSyncingAll = false;
        _meshResult = res;
      });
      if (res.success) {
        HapticHelper.success();
        widget.onSyncCompleted?.call();
      } else {
        HapticHelper.error();
      }
    }
  }

  Future<void> _handleCloudAndMeshSync() async {
    if (_isSyncingAll) return;
    setState(() {
      _isSyncingAll = true;
      _meshResult = null;
    });
    HapticHelper.selection();

    try {
      final apiClient = context.read<ApiClient>();
      // 1. Flush pending outbox mutations
      await widget.syncService.flushQueue(apiClient, force: true);
      // 2. Authoritative batch sync for this trip from server
      await widget.syncService.syncTripBatchWithServer(apiClient, widget.trip.id);
      // 3. Restart discovery beacon burst for nearby friends
      await widget.p2pService.startDiscoverySession(timeout: const Duration(seconds: 30));
      // 4. Try syncing with any newly detected peers
      final res = await widget.p2pService.syncAllNearbyPeers(targetTripId: widget.trip.id);

      if (mounted) {
        setState(() {
          _isSyncingAll = false;
          _meshResult = res.success && res.totalPeersSynced > 0
              ? res
              : NearbyMeshSyncResult(
                  success: true,
                  totalPeersSynced: 0,
                  operationsSent: 0,
                  operationsReceived: 0,
                  errorMessage: null,
                );
        });
        HapticHelper.success();
        widget.onSyncCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncingAll = false;
          _meshResult = NearbyMeshSyncResult(
            success: false,
            totalPeersSynced: 0,
            operationsSent: 0,
            operationsReceived: 0,
            errorMessage: 'Could not connect to cloud or mesh friends',
          );
        });
        HapticHelper.error();
      }
    }
  }

  Future<void> _handleSyncIndividual(NearbyPeer peer) async {
    if (_syncingPeerId != null) return;
    setState(() => _syncingPeerId = peer.deviceId);
    HapticHelper.selection();

    final res = await widget.p2pService.syncWithPeer(peer, targetTripId: widget.trip.id);

    if (mounted) {
      setState(() => _syncingPeerId = null);
      if (res.success) {
        HapticHelper.success();
        widget.onSyncCompleted?.call();
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

    final currentUserId = widget.p2pService.storage.getSavedUser()?['id']?.toString() ?? '';
    final currentDeviceId = widget.p2pService.deviceId;

    // Partition members: Authoritative local device vs remote peers
    final allEligibleMembers = widget.trip.members.where((m) => !m.isVirtual && m.isClaimed).toList();
    final localMember = allEligibleMembers.where((m) => m.userId == currentUserId).firstOrNull ??
        allEligibleMembers.where((m) => m.role == 'creator' && widget.trip.creatorId == currentUserId).firstOrNull;
    final remoteMembers = allEligibleMembers.where((m) => m != localMember && m.userId != currentUserId).toList();

    // Discovered remote peers for this trip, strictly excluding own device
    final nearbyPeersForTrip = _peers.where(
      (p) => p.sharedTripIds.contains(widget.trip.id) && p.deviceId != currentDeviceId,
    ).toList();

    // Check if user has other devices detected under their own account
    final myOtherDevicePeers = nearbyPeersForTrip.where((p) => p.userId != null && p.userId == currentUserId).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomInset > 0 ? bottomInset + 12 : 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131822) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          size: 22,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Trip Friends',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${widget.trip.name} • ${nearbyPeersForTrip.length} in range',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Visual Sonar Radar Graphic
                    _buildRadarAnimation(isDark, nearbyPeersForTrip.length),

                    const SizedBox(height: 14),

                    // Dedicated Local Device Status Card (Never appears as a remote peer or Not in Range)
                    _buildLocalDeviceCard(isDark, localMember, currentDeviceId),

                    const SizedBox(height: 14),

                    // Results Banner if sync completed
                    if (_meshResult != null) _buildResultBanner(isDark, _meshResult!),

                    const SizedBox(height: 12),

                    // Section Title: Eligible Friends in this Trip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ELIGIBLE TRIP FRIENDS (${remoteMembers.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: nearbyPeersForTrip.isNotEmpty ? Colors.green : Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              nearbyPeersForTrip.isNotEmpty ? 'Mesh & BLE Active' : 'Scanning...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: nearbyPeersForTrip.isNotEmpty ? Colors.green : Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // List of Remote Eligible KITH Friends with status
                    if (remoteMembers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.group_add_rounded, size: 36, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 8),
                              Text(
                                'No other friends joined this trip yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Share your QR or Invite Code (${widget.trip.inviteCode}) so friends can join and sync offline.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: remoteMembers.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 10,
                          thickness: 0.5,
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        ),
                        itemBuilder: (ctx, idx) {
                          final member = remoteMembers[idx];
                          // Match member strictly by authenticated userId identity, excluding own device
                          final matchedPeer = nearbyPeersForTrip.where(
                            (p) => p.userId != null && p.userId == member.userId && p.deviceId != currentDeviceId,
                          ).firstOrNull;

                          return _buildMemberStatusRow(isDark, member, matchedPeer);
                        },
                      ),

                    // If user has other devices under the same account in range
                    if (myOtherDevicePeers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.devices_rounded, size: 14, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'YOUR OTHER DEVICES (${myOtherDevicePeers.length})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...myOtherDevicePeers.map((p) => _buildOtherDeviceRow(isDark, p)),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Action Dock: Sync All
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: !_isSyncingAll
                      ? (nearbyPeersForTrip.isNotEmpty ? _handleSyncAll : _handleCloudAndMeshSync)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: isDark ? const Color(0xFF1E2836) : const Color(0xFFE2E8F0),
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSyncingAll
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              nearbyPeersForTrip.isNotEmpty
                                  ? 'Syncing Mesh with Friends...'
                                  : 'Syncing with Cloud & Friends...',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              nearbyPeersForTrip.isNotEmpty ? Icons.bolt_rounded : Icons.cloud_sync_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              nearbyPeersForTrip.isNotEmpty
                                  ? 'Sync All Nearby Friends (${nearbyPeersForTrip.length})'
                                  : 'Sync Trip with Cloud & Friends',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarAnimation(bool isDark, int nearbyCount) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D121B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
        ),
      ),
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (ctx, child) {
          final val = _radarController.value;
          final primaryColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Radiating Radar Wave 1
              Container(
                width: 50 + (val * 120),
                height: 50 + (val * 120),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: (1.0 - val).clamp(0.0, 0.6)),
                    width: 1.5,
                  ),
                ),
              ),
              // Radiating Radar Wave 2
              Container(
                width: 50 + (((val + 0.5) % 1.0) * 120),
                height: 50 + (((val + 0.5) % 1.0) * 120),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: (1.0 - ((val + 0.5) % 1.0)).clamp(0.0, 0.4)),
                    width: 1,
                  ),
                ),
              ),
              // Center Device Node
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              // Floating Text at bottom of radar
              Positioned(
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white70,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    nearbyCount > 0
                        ? '$nearbyCount friend${nearbyCount > 1 ? "s" : ""} connected on mesh'
                        : 'Broadcasting zero-data mesh beacon (Wi-Fi/Hotspot)...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultBanner(bool isDark, NearbyMeshSyncResult res) {
    final isSuccess = res.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
            : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: isSuccess ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSuccess
                  ? (res.totalChanges > 0
                      ? 'Synced ${res.totalChanges} changes across ${res.totalPeersSynced} friends!'
                      : (res.totalPeersSynced > 0
                          ? 'All nearby friends are already up to date!'
                          : 'Trip synced with Cloud! (Connect to same Wi-Fi or Hotspot for offline P2P mesh)'))
                  : 'Sync failed: ${res.errorMessage ?? "Network issue"}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSuccess
                    ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF166534))
                    : (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalDeviceCard(bool isDark, TripMember? localMember, String deviceId) {
    final name = localMember?.displayName ?? 'You';
    final shortDevId = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              MemberAvatar(name: name, size: 38),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded, size: 10, color: Colors.white),
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
                        '$name (This Device)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LOCAL',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Broadcasting discovery beacon (BLE & Mesh Active) • #$shortDevId',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.emeraldLight.withValues(alpha: 0.9) : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherDeviceRow(bool isDark, NearbyPeer peer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices_rounded, size: 18, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${peer.displayName} (Second Device)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  peer.isBleOnly ? 'Nearby • BLE In Range' : 'Nearby • Mesh Connected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          if (peer.canSyncData)
            IconButton(
              icon: Icon(
                Icons.sync_rounded,
                size: 20,
                color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              ),
              onPressed: () => _handleSyncIndividual(peer),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberStatusRow(bool isDark, TripMember member, NearbyPeer? peer) {
    final isNearby = peer != null;
    final isSyncingThis = peer != null && (_syncingPeerId == peer.deviceId || peer.isSyncing);
    final isBleOnly = peer != null && peer.isBleOnly;
    final canDirectSync = peer != null && peer.canSyncData;

    final String statusText;
    final Color statusColor;
    if (isNearby) {
      if (peer.lastSyncedAt != null) {
        statusText = 'Nearby • Synced';
        statusColor = Colors.green;
      } else if (isBleOnly) {
        final rssiStr = peer.rssi != null ? ' (${peer.rssi} dBm)' : '';
        statusText = 'Nearby • BLE In Range$rssiStr';
        statusColor = const Color(0xFF3B82F6);
      } else {
        statusText = 'Nearby • In Range (Mesh Active)';
        statusColor = isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      }
    } else {
      statusText = 'Not in Range';
      statusColor = Colors.grey.shade400;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          MemberAvatar(name: member.displayName, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isNearby
                            ? statusColor
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        fontWeight: isNearby ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isNearby) ...[
            if (isSyncingThis)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (canDirectSync)
              IconButton(
                icon: Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                ),
                tooltip: 'Sync with ${member.displayName}',
                onPressed: () => _handleSyncIndividual(peer),
              )
            else if (isBleOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_searching_rounded, size: 13, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'BLE Detected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
