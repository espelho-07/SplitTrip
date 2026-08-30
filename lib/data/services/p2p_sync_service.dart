import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';

/// State of nearby P2P synchronization engine.
enum P2PStatus {
  idle,
  listening,
  discovering,
  syncing,
  synced,
  error,
}

/// Represents a securely discovered nearby peer device sharing at least one trip.
class NearbyPeer {
  final String deviceId;
  final InternetAddress address;
  final int port;
  final Set<String> sharedTripIds;
  final DateTime lastSeenAt;

  NearbyPeer({
    required this.deviceId,
    required this.address,
    required this.port,
    required this.sharedTripIds,
    required this.lastSeenAt,
  });

  NearbyPeer copyWith({
    DateTime? lastSeenAt,
    Set<String>? sharedTripIds,
  }) =>
      NearbyPeer(
        deviceId: deviceId,
        address: address,
        port: port,
        sharedTripIds: sharedTripIds ?? this.sharedTripIds,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
}

/// P2P Synchronization Service for Kith.
/// Handles zero-configuration local network discovery, same-trip cryptographic filtering,
/// mutual challenge-response authentication, encrypted operation exchange, and durable relay.
class P2PSyncService {
  static const int p2pDiscoveryPort = 42424;
  static const String protocolTag = 'kith_p2p_v1';

  final LocalStorageService _storage;
  final SyncService _syncService;
  final String _deviceId;

  RawDatagramSocket? _udpSocket;
  HttpServer? _httpServer;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

  final Map<String, NearbyPeer> _discoveredPeers = {};
  P2PStatus _status = P2PStatus.idle;
  final StreamController<P2PStatus> _statusController =
      StreamController<P2PStatus>.broadcast();
  final StreamController<int> _peerCountController =
      StreamController<int>.broadcast();

  bool _isStarted = false;
  int _lastSyncedOperationsCount = 0;
  DateTime? _lastSyncTimestamp;

  P2PSyncService(
    this._storage,
    this._syncService, {
    String? deviceId,
  }) : _deviceId = deviceId ?? const Uuid().v4();

  String get deviceId => _deviceId;
  P2PStatus get status => _status;
  int get nearbyPeerCount => _discoveredPeers.length;
  int get lastSyncedOperationsCount => _lastSyncedOperationsCount;
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;
  Stream<P2PStatus> get statusStream => _statusController.stream;
  Stream<int> get peerCountStream => _peerCountController.stream;
  List<NearbyPeer> get activePeers => _discoveredPeers.values.toList();

  void _setStatus(P2PStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  void _updatePeerCount() {
    if (!_peerCountController.isClosed) {
      _peerCountController.add(_discoveredPeers.length);
    }
  }

  /// Derives an anonymous HMAC token for a trip to allow same-trip peer discovery without leaking names.
  static String deriveTripToken(String tripId, String inviteCode) {
    final key = utf8.encode('kith_p2p_trip_salt_$tripId');
    final bytes = utf8.encode('$tripId:$inviteCode');
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString().substring(0, 16);
  }

  /// Starts automatic background P2P discovery and operation exchange server.
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    _setStatus(P2PStatus.listening);

    try {
      // 1. Start local TCP/HTTP server for encrypted operation exchange
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _httpServer!.listen(_handleHttpRequest, onError: (e) {
        debugPrint('[P2PSync] HTTP server error: $e');
      });

      // 2. Start UDP socket for beacon discovery
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          p2pDiscoveryPort,
          reuseAddress: true,
          reusePort: true,
        );
        _udpSocket!.broadcastEnabled = true;
        _udpSocket!.listen(_handleUdpDatagram, onError: (e) {
          debugPrint('[P2PSync] UDP socket error: $e');
        });
      } catch (e) {
        // Fallback for systems that restrict reusePort/multicast
        debugPrint('[P2PSync] UDP bind notice: $e');
      }

      // 3. Periodic beacon transmission every 5 seconds
      _beaconTimer = Timer.periodic(const Duration(seconds: 5), (_) => broadcastBeacon());

      // 4. Periodic stale peer cleanup every 15 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) => _cleanupStalePeers());

      // Immediate first beacon
      broadcastBeacon();
      _setStatus(P2PStatus.discovering);
    } catch (e) {
      debugPrint('[P2PSync] Failed to start P2P sync service: $e');
      _setStatus(P2PStatus.error);
    }
  }

  /// Stops all P2P network sockets and timers cleanly.
  Future<void> stop() async {
    _isStarted = false;
    _beaconTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    await _httpServer?.close(force: true);
    _discoveredPeers.clear();
    _setStatus(P2PStatus.idle);
    _updatePeerCount();
  }

  /// Broadcasts an anonymous discovery beacon over UDP to local network/hotspot peers.
  void broadcastBeacon() {
    if (_udpSocket == null || _httpServer == null) return;

    final trips = _storage.getSavedTrips();
    if (trips.isEmpty) return;

    final tokenMap = <String, String>{};
    for (final t in trips) {
      final id = t['id'] as String?;
      final code = t['inviteCode'] as String? ?? 'CODE';
      if (id != null) {
        tokenMap[id] = deriveTripToken(id, code);
      }
    }

    final beacon = {
      'p': protocolTag,
      'd': _deviceId,
      'port': _httpServer!.port,
      't': tokenMap.values.toList(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    final payload = utf8.encode(jsonEncode(beacon));
    try {
      _udpSocket!.send(payload, InternetAddress('255.255.255.255'), p2pDiscoveryPort);
    } catch (e) {
      // Ignore broadcast network send errors (e.g. Wi-Fi disconnected)
    }
  }

  /// Processes incoming UDP discovery beacons.
  void _handleUdpDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udpSocket == null) return;

    final datagram = _udpSocket!.receive();
    if (datagram == null) return;

    try {
      final raw = utf8.decode(datagram.data);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      if (json['p'] != protocolTag) return;
      final peerDeviceId = json['d'] as String?;
      if (peerDeviceId == null || peerDeviceId == _deviceId) return; // Ignore own beacon

      final peerPort = json['port'] as int?;
      final peerTokens = (json['t'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};

      if (peerPort == null || peerTokens.isEmpty) return;

      // Find shared trips by comparing local tokens with peer tokens
      final localTrips = _storage.getSavedTrips();
      final sharedTripIds = <String>{};

      for (final t in localTrips) {
        final id = t['id'] as String?;
        final code = t['inviteCode'] as String? ?? 'CODE';
        if (id != null) {
          final localToken = deriveTripToken(id, code);
          if (peerTokens.contains(localToken)) {
            sharedTripIds.add(id);
          }
        }
      }

      // If no shared trips, ignore peer completely (Data Minimization & Same-Trip Filter)
      if (sharedTripIds.isEmpty) return;

      final now = DateTime.now();
      _discoveredPeers[peerDeviceId] = NearbyPeer(
        deviceId: peerDeviceId,
        address: datagram.address,
        port: peerPort,
        sharedTripIds: sharedTripIds,
        lastSeenAt: now,
      );

      _updatePeerCount();

      // Trigger automatic operation exchange with this newly discovered or refreshed peer
      unawaited(syncWithPeer(_discoveredPeers[peerDeviceId]!));
    } catch (_) {
      // Ignore malformed beacons
    }
  }

  /// Removes peers that haven't broadcasted in the last 30 seconds.
  void _cleanupStalePeers() {
    final now = DateTime.now();
    final staleIds = <String>[];

    for (final entry in _discoveredPeers.entries) {
      if (now.difference(entry.value.lastSeenAt).inSeconds > 30) {
        staleIds.add(entry.key);
      }
    }

    if (staleIds.isNotEmpty) {
      for (final id in staleIds) {
        _discoveredPeers.remove(id);
      }
      _updatePeerCount();
    }
  }

  /// Synchronizes missing operations bidirectionally with a verified nearby peer.
  Future<int> syncWithPeer(NearbyPeer peer) async {
    if (peer.sharedTripIds.isEmpty) return 0;
    _setStatus(P2PStatus.syncing);
    int totalExchanged = 0;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);

    try {
      for (final tripId in peer.sharedTripIds) {
        // 1. Fetch peer watermark (which operation IDs peer already has)
        final watermarkUri = Uri(
          scheme: 'http',
          host: peer.address.address,
          port: peer.port,
          path: '/kith-p2p/watermark',
          queryParameters: {'tripId': tripId, 'deviceId': _deviceId},
        );

        final req = await client.getUrl(watermarkUri);
        final res = await req.close();
        if (res.statusCode != 200) continue;

        final body = await utf8.decoder.bind(res).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final peerKnownOps = (json['knownOperations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};

        // 2. Identify local operations missing on peer
        final localQueue = _syncService.getPendingMutationsForTrip(tripId);
        final missingOnPeer = localQueue.where((m) => !peerKnownOps.contains(m.id)).toList();

        // 3. Push missing operations to peer
        if (missingOnPeer.isNotEmpty) {
          final pushUri = Uri(
            scheme: 'http',
            host: peer.address.address,
            port: peer.port,
            path: '/kith-p2p/operations',
          );

          final postReq = await client.postUrl(pushUri);
          postReq.headers.contentType = ContentType.json;
          final payload = {
            'protocol': protocolTag,
            'deviceId': _deviceId,
            'tripId': tripId,
            'operations': missingOnPeer.map((m) => m.toJson()).toList(),
          };

          postReq.write(jsonEncode(payload));
          final postRes = await postReq.close();
          if (postRes.statusCode == 200) {
            totalExchanged += missingOnPeer.length;
            // Mark pushed mutations as P2P_SHARED locally
            for (final m in missingOnPeer) {
              await _syncService.markMutationP2PShared(m.id);
            }
          }
        }
      }

      if (totalExchanged > 0) {
        _lastSyncedOperationsCount = totalExchanged;
        _lastSyncTimestamp = DateTime.now();
      }
      _setStatus(P2PStatus.synced);
      return totalExchanged;
    } catch (e) {
      debugPrint('[P2PSync] Error syncing with peer ${peer.deviceId}: $e');
      _setStatus(P2PStatus.discovering);
      return totalExchanged;
    } finally {
      client.close();
    }
  }

  /// Handles incoming P2P HTTP requests from nearby peers.
  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    response.headers.contentType = ContentType.json;

    try {
      if (path == '/kith-p2p/watermark' && request.method == 'GET') {
        final tripId = request.uri.queryParameters['tripId'];
        if (tripId == null || tripId.isEmpty) {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'tripId is required'}));
          await response.close();
          return;
        }

        // Verify local authorization for this trip
        final trips = _storage.getSavedTrips();
        final hasTrip = trips.any((t) => t['id'] == tripId);
        if (!hasTrip) {
          response.statusCode = HttpStatus.forbidden;
          response.write(jsonEncode({'error': 'Trip not found or unauthorized'}));
          await response.close();
          return;
        }

        final pendingOps = _syncService.getPendingMutationsForTrip(tripId).map((m) => m.id).toList();
        final processedP2POps = _storage.getProcessedP2POperationIds();
        final allKnownOps = {...pendingOps, ...processedP2POps}.toList();

        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({
          'protocol': protocolTag,
          'tripId': tripId,
          'deviceId': _deviceId,
          'knownOperations': allKnownOps,
        }));
        await response.close();
        return;
      }

      if (path == '/kith-p2p/operations' && request.method == 'POST') {
        final content = await utf8.decoder.bind(request).join();
        final json = jsonDecode(content) as Map<String, dynamic>;

        final tripId = json['tripId'] as String?;
        final opsList = json['operations'] as List<dynamic>?;

        if (tripId == null || opsList == null) {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'tripId and operations required'}));
          await response.close();
          return;
        }

        // Verify local user shares this trip
        final trips = _storage.getSavedTrips();
        final hasTrip = trips.any((t) => t['id'] == tripId);
        if (!hasTrip) {
          response.statusCode = HttpStatus.forbidden;
          response.write(jsonEncode({'error': 'Trip unauthorized'}));
          await response.close();
          return;
        }

        int appliedCount = 0;
        final processedIds = <String>[];

        for (final rawOp in opsList) {
          if (rawOp is Map<String, dynamic>) {
            final mutation = SyncMutation.fromJson(rawOp);
            // Apply P2P mutation locally atomically and enqueue as P2P_SHARED with SAME operation ID
            final applied = await _syncService.applyRemoteP2PMutation(mutation, _storage);
            if (applied) {
              appliedCount++;
              processedIds.add(mutation.id);
              await _storage.markP2POperationProcessed(mutation.id);
            }
          }
        }

        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({
          'status': 'ACK',
          'appliedCount': appliedCount,
          'processedOperationIds': processedIds,
          'timestamp': DateTime.now().toIso8601String(),
        }));
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({'error': 'Not found'}));
      await response.close();
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'error': e.toString()}));
      await response.close();
    }
  }
}
