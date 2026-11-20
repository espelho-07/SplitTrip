import 'dart:async';



import 'dart:convert';



import 'dart:io';



import 'package:crypto/crypto.dart';



import 'package:flutter/foundation.dart';



import 'package:uuid/uuid.dart';



import 'local_storage_service.dart';



import 'sync_service.dart';



import '../../core/services/recovery_key_service.dart';



/// State of nearby P2P synchronization engine.



enum P2PStatus {

  idle,



  listening,



  discovering,



  pairing,



  syncing,



  synced,



  timeout,



  error,

}



/// Result of a completed P2P sync session.



class NearbySyncResult {

  final bool success;



  final int operationsSent;



  final int operationsReceived;



  final List<String> sharedTripIds;



  final String? errorMessage;



  final DateTime timestamp;



  NearbySyncResult({

    required this.success,



    this.operationsSent = 0,



    this.operationsReceived = 0,



    this.sharedTripIds = const [],



    this.errorMessage,



    DateTime? timestamp,

  }) : timestamp = timestamp ?? DateTime.now();



  int get totalChanges => operationsSent + operationsReceived;

}



/// Result of a multi-peer mesh synchronization session.



class NearbyMeshSyncResult {

  final bool success;



  final int totalPeersSynced;



  final int operationsSent;



  final int operationsReceived;



  final List<String> syncedPeerNames;



  final List<String> sharedTripIds;



  final String? errorMessage;



  final DateTime timestamp;



  NearbyMeshSyncResult({

    required this.success,



    this.totalPeersSynced = 0,



    this.operationsSent = 0,



    this.operationsReceived = 0,



    this.syncedPeerNames = const [],



    this.sharedTripIds = const [],



    this.errorMessage,



    DateTime? timestamp,

  }) : timestamp = timestamp ?? DateTime.now();



  int get totalChanges => operationsSent + operationsReceived;

}



/// Represents a securely discovered nearby peer device sharing at least one trip.



class NearbyPeer {

  final String deviceId;



  final String displayName;



  final String? userId;



  final InternetAddress address;



  final int port;



  final Set<String> sharedTripIds;



  final List<String> sharedTripNames;



  final String pairingCode;



  final DateTime lastSeenAt;



  final DateTime? lastSyncedAt;



  final int lastSyncedChanges;



  final bool isSyncing;



  final bool isAuthenticated;



  NearbyPeer({

    required this.deviceId,



    required this.displayName,



    this.userId,



    required this.address,



    required this.port,



    required this.sharedTripIds,



    this.sharedTripNames = const [],



    required this.pairingCode,



    required this.lastSeenAt,



    this.lastSyncedAt,



    this.lastSyncedChanges = 0,



    this.isSyncing = false,



    this.isAuthenticated = false,

  });



  NearbyPeer copyWith({

    String? displayName,



    String? userId,



    DateTime? lastSeenAt,



    Set<String>? sharedTripIds,



    List<String>? sharedTripNames,



    DateTime? lastSyncedAt,



    int? lastSyncedChanges,



    bool? isSyncing,



    bool? isAuthenticated,

  }) => NearbyPeer(

    deviceId: deviceId,



    displayName: displayName ?? this.displayName,



    userId: userId ?? this.userId,



    address: address,



    port: port,



    sharedTripIds: sharedTripIds ?? this.sharedTripIds,



    sharedTripNames: sharedTripNames ?? this.sharedTripNames,



    pairingCode: pairingCode,



    lastSeenAt: lastSeenAt ?? this.lastSeenAt,



    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,



    lastSyncedChanges: lastSyncedChanges ?? this.lastSyncedChanges,



    isSyncing: isSyncing ?? this.isSyncing,



    isAuthenticated: isAuthenticated ?? this.isAuthenticated,

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



  Timer? _sessionTimeoutTimer;



  final Map<String, NearbyPeer> _discoveredPeers = {};



  P2PStatus _status = P2PStatus.idle;



  final StreamController<P2PStatus> _statusController =

      StreamController<P2PStatus>.broadcast();



  final StreamController<int> _peerCountController =

      StreamController<int>.broadcast();



  final StreamController<List<NearbyPeer>> _peersController =

      StreamController<List<NearbyPeer>>.broadcast();



  bool _isStarted = false;



  int _lastSyncedOperationsCount = 0;



  DateTime? _lastSyncTimestamp;



  P2PSyncService(this._storage, this._syncService, {String? deviceId})

    : _deviceId = deviceId ?? const Uuid().v4();



  String get deviceId => _deviceId;



  P2PStatus get status => _status;



  int? get serverPort => _httpServer?.port;



  int get nearbyPeerCount => _discoveredPeers.length;



  int get lastSyncedOperationsCount => _lastSyncedOperationsCount;



  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;



  Stream<P2PStatus> get statusStream => _statusController.stream;



  Stream<int> get peerCountStream => _peerCountController.stream;



  Stream<List<NearbyPeer>> get peersStream => _peersController.stream;



  List<NearbyPeer> get activePeers => _discoveredPeers.values.toList();



  void _setStatus(P2PStatus newStatus) {

    if (_status != newStatus) {

      _status = newStatus;



      if (!_statusController.isClosed) {

        _statusController.add(newStatus);

      }

    }

  }



  void _notifyPeersChanged() {

    if (!_peerCountController.isClosed) {

      _peerCountController.add(_discoveredPeers.length);

    }



    if (!_peersController.isClosed) {

      _peersController.add(_discoveredPeers.values.toList());

    }

  }



  /// Generates a deterministic 6-digit pairing code for two devices.



  static String derivePairingCode(String deviceA, String deviceB) {

    final sorted = [deviceA, deviceB]..sort();



    final bytes = utf8.encode('kith_p2p_pair_${sorted[0]}_${sorted[1]}');



    final digest = sha256.convert(bytes);



    final num = digest.bytes.fold<int>(

      0,

      (prev, elem) => (prev * 31 + elem) & 0x7FFFFFFF,

    );



    final code = (num % 900000 + 100000).toString();



    return '${code.substring(0, 3)} ${code.substring(3)}';

  }



  /// Derives an anonymous HMAC token for a trip to allow same-trip peer discovery without leaking names.



  static String deriveTripToken(String tripId, String inviteCode) {

    final key = utf8.encode('kith_p2p_trip_salt_$tripId');



    final bytes = utf8.encode('$tripId:$inviteCode');



    final hmac = Hmac(sha256, key);



    return hmac.convert(bytes).toString().substring(0, 16);

  }



  /// Derives a cryptographically strong HMAC-SHA256 authentication key for a trip.



  /// Prioritizes the 128-bit [p2pTripSecret] (at least 128 bits of entropy).



  /// Falls back to legacy deterministic derivation from [inviteCode] for backward compatibility.



  static List<int> deriveTripAuthKey(

    String tripId,

    String inviteCode, {

    String? p2pTripSecret,

  }) {

    final salt = utf8.encode('kith_p2p_auth_master_salt_$tripId');



    final List<int> message;



    if (p2pTripSecret != null && p2pTripSecret.isNotEmpty) {

      message = utf8.encode('$tripId:$p2pTripSecret:kith_authenticated_p2p_v2');

    } else {

      message = utf8.encode('$tripId:$inviteCode:kith_authenticated_p2p_v1');

    }



    final hmac = Hmac(sha256, salt);



    return hmac.convert(message).bytes;

  }



  /// Backward-compatible legacy derivation for trips created without an explicit 128-bit secret.



  static String deriveLegacyTripSecret(String tripId, String inviteCode) {

    final data = utf8.encode('$tripId:$inviteCode:kith_authenticated_p2p_v1');



    return sha256.convert(data).toString().substring(0, 32);

  }



  /// Computes an HMAC-SHA256 digital signature binding operation identity, sender, payload checksum, and timestamp.



  static String computeP2POperationSignature({

    required List<int> authKey,



    required String protocolVersion,



    required String tripId,



    required String operationId,



    required String senderDeviceId,



    required String payloadChecksum,



    required int timestampMs,

  }) {

    final message = utf8.encode(

      '$protocolVersion|$tripId|$operationId|$senderDeviceId|$payloadChecksum|$timestampMs',

    );



    final hmac = Hmac(sha256, authKey);



    return hmac.convert(message).toString();

  }



  /// Verifies an HMAC-SHA256 digital signature and enforces a strict replay window (default 300 seconds).



  static bool verifyP2POperationSignature({

    required List<int> authKey,



    required String signature,



    required String protocolVersion,



    required String tripId,



    required String operationId,



    required String senderDeviceId,



    required String payloadChecksum,



    required int timestampMs,



    int maxSkewSeconds = 120,



    int? currentTimestampMs,

  }) {

    final nowMs = currentTimestampMs ?? DateTime.now().millisecondsSinceEpoch;



    final skewMs = (nowMs - timestampMs).abs();



    if (skewMs > maxSkewSeconds * 1000) {

      return false; // Replay attack prevention: timestamp outside allowed skew window

    }



    final expectedSig = computeP2POperationSignature(

      authKey: authKey,



      protocolVersion: protocolVersion,



      tripId: tripId,



      operationId: operationId,



      senderDeviceId: senderDeviceId,



      payloadChecksum: payloadChecksum,



      timestampMs: timestampMs,

    );



    return RecoveryKeyService.constantTimeEquals(expectedSig, signature);

  }



  /// Computes an HMAC-SHA256 session authentication token binding the trip, sender device, authenticated user ID, and timestamp.

  static String computeP2PSessionToken({

    required List<int> authKey,

    required String protocolVersion,

    required String tripId,

    required String senderDeviceId,

    required String senderUserId,

    required int timestampMs,

    String? nonce,

  }) {

    final message = utf8.encode(

      '|session||||',

    );

    final hmac = Hmac(sha256, authKey);

    return hmac.convert(message).toString();

  }



  /// Verifies an HMAC-SHA256 session authentication token and enforces a strict drift/replay window (default 120 seconds).

  static bool verifyP2PSessionToken({

    required List<int> authKey,

    required String sessionToken,

    required String protocolVersion,

    required String tripId,

    required String senderDeviceId,

    required String senderUserId,

    required int timestampMs,

    int maxSkewSeconds = 120,

    int? currentTimestampMs,

    String? nonce,

  }) {

    final nowMs = currentTimestampMs ?? DateTime.now().millisecondsSinceEpoch;

    final skewMs = (nowMs - timestampMs).abs();

    if (skewMs > maxSkewSeconds * 1000) {

      return false; // Replay attack prevention: timestamp outside allowed skew window (>120s)

    }



    final expectedToken = computeP2PSessionToken(

      authKey: authKey,

      protocolVersion: protocolVersion,

      tripId: tripId,

      senderDeviceId: senderDeviceId,

      senderUserId: senderUserId,

      timestampMs: timestampMs,

      nonce: nonce,

    );



    return RecoveryKeyService.constantTimeEquals(expectedToken, sessionToken);

  }



  /// Starts an intentional, user-initiated P2P discovery session with battery-saving auto-timeout.



  Future<void> startDiscoverySession({

    Duration timeout = const Duration(seconds: 45),

  }) async {

    await start();



    _sessionTimeoutTimer?.cancel();



    _sessionTimeoutTimer = Timer(timeout, () {

      if (_status == P2PStatus.discovering || _status == P2PStatus.listening) {

        stop();



        _setStatus(P2PStatus.timeout);

      }

    });

  }



  /// Starts automatic P2P discovery and operation exchange server.



  Future<void> start() async {

    if (_isStarted) return;



    _isStarted = true;



    _setStatus(P2PStatus.listening);



    try {

      // 1. Start local TCP/HTTP server for encrypted operation exchange



      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);



      _httpServer!.listen(

        _handleHttpRequest,

        onError: (e) {

          debugPrint('[P2PSync] HTTP server error: $e');

        },

      );



      // 2. Start UDP socket for beacon discovery



      try {

        _udpSocket = await RawDatagramSocket.bind(

          InternetAddress.anyIPv4,



          p2pDiscoveryPort,



          reuseAddress: true,



          reusePort: !Platform.isWindows,

        );



        _udpSocket!.broadcastEnabled = true;



        _udpSocket!.listen(

          _handleUdpDatagram,

          onError: (e) {

            debugPrint('[P2PSync] UDP socket error: $e');

          },

        );

      } catch (e) {

        debugPrint('[P2PSync] UDP bind notice: $e');

      }



      // 3. Periodic beacon transmission every 3 seconds while searching



      _beaconTimer = Timer.periodic(

        const Duration(seconds: 3),

        (_) => broadcastBeacon(),

      );



      // 4. Periodic stale peer cleanup every 10 seconds



      _cleanupTimer = Timer.periodic(

        const Duration(seconds: 10),

        (_) => _cleanupStalePeers(),

      );



      // Immediate first beacon



      broadcastBeacon();



      _setStatus(P2PStatus.discovering);

    } catch (e) {

      debugPrint('[P2PSync] Failed to start P2P sync service: $e');



      _setStatus(P2PStatus.error);

    }

  }



  /// Stops all P2P network sockets and timers cleanly to conserve device battery.



  Future<void> stop() async {

    _isStarted = false;



    _sessionTimeoutTimer?.cancel();



    _beaconTimer?.cancel();



    _cleanupTimer?.cancel();



    _udpSocket?.close();



    _udpSocket = null;



    await _httpServer?.close(force: true);



    _httpServer = null;



    _discoveredPeers.clear();



    _setStatus(P2PStatus.idle);



    _notifyPeersChanged();

  }



  /// Broadcasts an anonymous discovery beacon over UDP to local network/hotspot peers.



  void broadcastBeacon() {

    if (_udpSocket == null || _httpServer == null) return;



    final trips = _storage.getSavedTrips();



    if (trips.isEmpty) return;



    final user = _storage.getSavedUser();



    final myDisplayName = user?['displayName']?.toString() ?? 'Kith Friend';



    final tokenMap = <String, String>{};



    for (final t in trips) {

      final id = t['id'] as String?;



      final code = t['inviteCode'] as String? ?? 'CODE';



      if (id != null) {

        tokenMap[id] = deriveTripToken(id, code);

      }

    }



    final myUserId = user?['id']?.toString() ?? '';



    final beacon = {

      'p': protocolTag,



      'd': _deviceId,



      'u': myUserId,



      'name': myDisplayName,



      'port': _httpServer!.port,



      't': tokenMap.values.toList(),



      'ts': DateTime.now().millisecondsSinceEpoch,

    };



    final payload = utf8.encode(jsonEncode(beacon));



    try {

      _udpSocket!.send(

        payload,

        InternetAddress('255.255.255.255'),

        p2pDiscoveryPort,

      );

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



      if (peerDeviceId == null || peerDeviceId == _deviceId) {

        return; // Ignore own beacon

      }



      final peerUserId = json['u'] as String?;



      final peerName = json['name'] as String? ?? 'Nearby Friend';



      final peerPort = json['port'] as int?;



      final peerTokens =

          (json['t'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {};



      if (peerPort == null || peerTokens.isEmpty) return;



      // Find shared trips by comparing local tokens with peer tokens



      final localTrips = _storage.getSavedTrips();



      final sharedTripIds = <String>{};



      final sharedTripNames = <String>[];



      for (final t in localTrips) {

        final id = t['id'] as String?;



        final code = t['inviteCode'] as String? ?? 'CODE';



        if (id != null) {

          final localToken = deriveTripToken(id, code);



          if (peerTokens.contains(localToken)) {

            // Validate peer identity: If peer specifies a userId, verify they are a linked KITH member

            // Virtual/unclaimed participants can NEVER trigger or participate in P2P sync.

            final membersList = t['members'] as List<dynamic>? ?? [];

            if (peerUserId != null && peerUserId.isNotEmpty) {

              final isAuthorizedMember = membersList.any((m) {

                if (m is Map) {

                  final isVirtual = m['isVirtual'] == true ||

                      m['is_virtual'] == true ||

                      m['isClaimed'] == false ||

                      m['is_claimed'] == false ||

                      (m['userId'] as String? ?? '').startsWith('unclaimed_');

                  final memberUserId = m['userId'] as String? ?? m['user_id'] as String? ?? '';

                  final memberId = m['id'] as String? ?? '';

                  final memberName = (m['displayName'] ?? m['display_name'])?.toString().trim().toLowerCase() ?? '';

                  final peerNormName = peerName.trim().toLowerCase();

                  return (!isVirtual && memberUserId == peerUserId) ||

                      memberId == peerUserId ||

                      (peerNormName.isNotEmpty && peerNormName != 'member' && memberName == peerNormName);

                }

                return false;

              });



              if (!isAuthorizedMember) {

                continue;

              }

            }



            sharedTripIds.add(id);



            final tripName = t['name']?.toString();



            if (tripName != null && !sharedTripNames.contains(tripName)) {

              sharedTripNames.add(tripName);

            }

          }

        }

      }



      final now = DateTime.now();



      final pairingCode = derivePairingCode(_deviceId, peerDeviceId);



      final existingPeer = _discoveredPeers[peerDeviceId];



      if (sharedTripIds.isEmpty) {

        return;

      }



      final newPeer = NearbyPeer(

        deviceId: peerDeviceId,



        displayName: peerName,



        userId: peerUserId,



        address: datagram.address,



        port: peerPort,



        sharedTripIds: sharedTripIds,



        sharedTripNames: sharedTripNames,



        pairingCode: pairingCode,



        lastSeenAt: now,



        lastSyncedAt: existingPeer?.lastSyncedAt,



        lastSyncedChanges: existingPeer?.lastSyncedChanges ?? 0,



        isSyncing: existingPeer?.isSyncing ?? false,



        isAuthenticated: existingPeer?.isAuthenticated ?? false,

      );



      _discoveredPeers[peerDeviceId] = newPeer;



      _notifyPeersChanged();



      // Automatic Mesh Auto-Sync Trigger:



      // When a peer sharing our trip is in local range, silently exchange pending mutations



      if (autoSyncEnabled && sharedTripIds.isNotEmpty && !_isAutoSyncBusy) {

        final lastSync = _lastAutoSyncTimes[peerDeviceId];



        if (lastSync == null || now.difference(lastSync).inSeconds >= 15) {

          _triggerBackgroundAutoSync(newPeer);

        }

      }

    } catch (_) {

      // Ignore malformed beacons

    }

  }



  final Map<String, DateTime> _lastAutoSyncTimes = {};



  bool _isAutoSyncBusy = false;



  bool autoSyncEnabled = true;



  Future<void> _triggerBackgroundAutoSync(NearbyPeer peer) async {

    if (_isAutoSyncBusy) return;



    _isAutoSyncBusy = true;



    _lastAutoSyncTimes[peer.deviceId] = DateTime.now();



    try {

      await syncWithPeer(peer);

    } catch (_) {

      // Ignore background auto-sync network glitches

    } finally {

      _isAutoSyncBusy = false;

    }

  }



  /// Synchronizes with ALL currently discovered nearby peers in the mesh.



  Future<NearbyMeshSyncResult> syncAllNearbyPeers({

    String? targetTripId,

  }) async {

    final candidatePeers = activePeers.where((p) {

      if (targetTripId == null || targetTripId.isEmpty) return true;



      return p.sharedTripIds.contains(targetTripId);

    }).toList();



    if (candidatePeers.isEmpty) {

      return NearbyMeshSyncResult(

        success: true,



        totalPeersSynced: 0,



        operationsSent: 0,



        operationsReceived: 0,



        syncedPeerNames: [],



        sharedTripIds: targetTripId != null ? [targetTripId] : [],

      );

    }



    _setStatus(P2PStatus.syncing);



    int totalSent = 0;



    int totalReceived = 0;



    final syncedPeerNames = <String>[];



    final allSharedTrips = <String>{};



    for (final peer in candidatePeers) {

      final res = await syncWithPeer(peer, targetTripId: targetTripId);



      if (res.success) {

        totalSent += res.operationsSent;



        totalReceived += res.operationsReceived;



        syncedPeerNames.add(peer.displayName);



        allSharedTrips.addAll(res.sharedTripIds);

      }

    }



    _setStatus(P2PStatus.synced);



    return NearbyMeshSyncResult(

      success: true,



      totalPeersSynced: syncedPeerNames.length,



      operationsSent: totalSent,



      operationsReceived: totalReceived,



      syncedPeerNames: syncedPeerNames,



      sharedTripIds: allSharedTrips.toList(),

    );

  }



  /// Removes peers that haven't broadcasted in the last 20 seconds.



  void _cleanupStalePeers() {

    final now = DateTime.now();



    final staleIds = <String>[];



    for (final entry in _discoveredPeers.entries) {

      if (now.difference(entry.value.lastSeenAt).inSeconds > 20) {

        staleIds.add(entry.key);

      }

    }



    if (staleIds.isNotEmpty) {

      for (final id in staleIds) {

        _discoveredPeers.remove(id);

      }



      _notifyPeersChanged();

    }

  }



  /// Synchronizes missing operations bidirectionally with a verified nearby peer.



  Future<NearbySyncResult> syncWithPeer(

    NearbyPeer peer, {

    String? targetTripId,

  }) async {

    final effectiveTripIds = <String>{

      if (targetTripId != null && targetTripId.isNotEmpty) targetTripId,



      ...peer.sharedTripIds,

    };



    if (effectiveTripIds.isEmpty) {

      return NearbySyncResult(

        success: false,

        errorMessage: 'No shared trips found',

      );

    }



    _setStatus(P2PStatus.syncing);



    if (_discoveredPeers.containsKey(peer.deviceId)) {

      _discoveredPeers[peer.deviceId] = _discoveredPeers[peer.deviceId]!

          .copyWith(isSyncing: true);



      _notifyPeersChanged();

    }



    int sentCount = 0;



    int receivedCount = 0;



    final client = HttpClient();



    client.connectionTimeout = const Duration(seconds: 4);



    try {

      for (final tripId in effectiveTripIds) {

        final localTrips = _storage.getSavedTrips();



        final tripMap = localTrips.firstWhere(

          (t) => t['id'] == tripId,

          orElse: () => {},

        );



        if (tripMap.isEmpty) continue;



        // Verify local user authorization: Virtual / unclaimed users can NEVER initiate P2P sync

        final myUser = _storage.getSavedUser();

        final myUserId = myUser?['id']?.toString() ?? '';

        if (myUserId.isEmpty || myUserId.startsWith('unclaimed_')) {

          debugPrint('[P2PSync] Unauthenticated or virtual local user cannot initiate P2P sync');

          continue;

        }



        final membersList = tripMap['members'] as List<dynamic>? ?? [];

        if (membersList.isNotEmpty) {

          final isClaimedMember = membersList.any((m) {

            if (m is Map) {

              final isVirtual = m['isVirtual'] == true ||

                  m['is_virtual'] == true ||

                  m['isClaimed'] == false ||

                  m['is_claimed'] == false ||

                  (m['userId'] as String? ?? '').startsWith('unclaimed_');

              final memberUserId = m['userId'] as String? ?? m['user_id'] as String? ?? '';

              return !isVirtual && memberUserId == myUserId;

            }

            return false;

          });



          if (!isClaimedMember) {

            debugPrint('[P2PSync] Local user  is not a claimed member of trip ; skipping');

            continue;

          }

        }



        final inviteCode = tripMap['inviteCode']?.toString() ?? '';



        final p2pSecret =

            tripMap['p2pTripSecret']?.toString() ??

            tripMap['p2p_trip_secret']?.toString();



        final authKey = deriveTripAuthKey(

          tripId,

          inviteCode,

          p2pTripSecret: p2pSecret,

        );



        // 1. Fetch peer watermark (authenticated with cryptographic session token)

        final watermarkNowMs = DateTime.now().millisecondsSinceEpoch;

        final watermarkSessionToken = computeP2PSessionToken(

          authKey: authKey,

          protocolVersion: protocolTag,

          tripId: tripId,

          senderDeviceId: _deviceId,

          senderUserId: myUserId,

          timestampMs: watermarkNowMs,

        );



        final watermarkUri = Uri(

          scheme: 'http',

          host: peer.address.address,

          port: peer.port,

          path: '/kith-p2p/watermark',

          queryParameters: {

            'tripId': tripId,

            'deviceId': _deviceId,

            'userId': myUserId,

            'timestamp': watermarkNowMs.toString(),

            'sessionToken': watermarkSessionToken,

          },

        );



        final req = await client.getUrl(watermarkUri);

        final res = await req.close();

        if (res.statusCode != 200) continue;



        final body = await utf8.decoder.bind(res).join();

        final json = jsonDecode(body) as Map<String, dynamic>;

        final peerKnownOps =

            (json['knownOperations'] as List<dynamic>?)

                ?.map((e) => e.toString())

                .toSet() ??

            {};



        // 2. Identify local operations missing on peer and tag with current node ID

        final localQueue = _syncService.getPendingMutationsForTrip(tripId);



        final missingOnPeer = localQueue

            .where((m) => !peerKnownOps.contains(m.id))

            .map((m) {

              final updatedForwarded = m.forwardedBy.contains(_deviceId)

                  ? m.forwardedBy

                  : [...m.forwardedBy, _deviceId];



              return m.copyWith(forwardedBy: updatedForwarded);

            })

            .toList();



        // 3. Push missing operations to peer and receive any missing peer operations in the response

        final pushUri = Uri(

          scheme: 'http',

          host: peer.address.address,

          port: peer.port,

          path: '/kith-p2p/operations',

        );



        final nowMs = DateTime.now().millisecondsSinceEpoch;

        final pushSessionToken = computeP2PSessionToken(

          authKey: authKey,

          protocolVersion: protocolTag,

          tripId: tripId,

          senderDeviceId: _deviceId,

          senderUserId: myUserId,

          timestampMs: nowMs,

        );



        final signedOps = missingOnPeer.map((m) {

          final opJson = m.toJson();

          final sig = computeP2POperationSignature(

            authKey: authKey,

            protocolVersion: protocolTag,

            tripId: tripId,

            operationId: m.id,

            senderDeviceId: _deviceId,

            payloadChecksum: m.payloadChecksum,

            timestampMs: nowMs,

          );

          opJson['signature'] = sig;

          opJson['signatureTimestamp'] = nowMs;

          return opJson;

        }).toList();



        final postReq = await client.postUrl(pushUri);

        postReq.headers.contentType = ContentType.json;



        final payload = {

          'protocol': protocolTag,

          'deviceId': _deviceId,

          'userId': myUserId,

          'timestamp': nowMs,

          'sessionToken': pushSessionToken,

          'tripId': tripId,

          'operations': signedOps,

          'knownLocalOperations': localQueue.map((m) => m.id).toList(),

        };



        postReq.write(jsonEncode(payload));

        final postRes = await postReq.close();



        if (postRes.statusCode == 200) {

          final resBody = await utf8.decoder.bind(postRes).join();

          final resJson = jsonDecode(resBody) as Map<String, dynamic>;



          // Verify peer ACK session token to cryptographically authenticate peer

          final peerAckToken = resJson['sessionToken'] as String?;

          final peerAckUserId = resJson['userId'] as String?;

          final peerAckTs = resJson['timestampMs'] as int?;

          if (peerAckToken != null && peerAckUserId != null && peerAckTs != null) {

            final isPeerValid = verifyP2PSessionToken(

              authKey: authKey,

              sessionToken: peerAckToken,

              protocolVersion: protocolTag,

              tripId: tripId,

              senderDeviceId: peer.deviceId,

              senderUserId: peerAckUserId,

              timestampMs: peerAckTs,

              maxSkewSeconds: 120,

            );

            if (isPeerValid && _discoveredPeers.containsKey(peer.deviceId)) {

              _discoveredPeers[peer.deviceId] = _discoveredPeers[peer.deviceId]!.copyWith(

                isAuthenticated: true,

                userId: peerAckUserId,

              );

            }

          }



          sentCount += missingOnPeer.length;



          for (final m in missingOnPeer) {

            await _syncService.markMutationP2PShared(m.id);

          }



          // Apply returned peer mutations with HMAC verification, hop limit & loop prevention



          final peerOps = resJson['returnOperations'] as List<dynamic>?;



          if (peerOps != null) {

            for (final rawOp in peerOps) {

              if (rawOp is Map<String, dynamic>) {

                final sig = rawOp['signature'] as String?;



                final sigTs = rawOp['signatureTimestamp'] as int?;



                final opId = rawOp['id'] as String?;



                final opTripId =

                    rawOp['payload']?['tripId'] as String? ?? tripId;



                final payloadChecksum = rawOp['payloadChecksum'] as String?;



                if (sig == null ||

                    sigTs == null ||

                    opId == null ||

                    payloadChecksum == null) {

                  debugPrint(

                    '[P2PSync] Dropping return operation without valid signature metadata: $opId',

                  );



                  continue;

                }



                // Strict Protocol Separation:

                // Modern trips (with p2pTripSecret) require valid v2 HMAC signatures.

                // Legacy trips (without p2pTripSecret) authenticate using legacy v1 (inviteCode).

                // A failed v2 verification NEVER downgrades to v1!

                final isValidSig = verifyP2POperationSignature(

                  authKey: authKey,

                  signature: sig,

                  protocolVersion: protocolTag,

                  tripId: opTripId,

                  operationId: opId,

                  senderDeviceId: peer.deviceId,

                  payloadChecksum: payloadChecksum,

                  timestampMs: sigTs,

                );



                if (!isValidSig) {

                  debugPrint(

                    '[P2PSync] Invalid return operation HMAC signature from peer ${peer.deviceId}: $opId',

                  );



                  continue;

                }



                final mutation = SyncMutation.fromJson(rawOp);



                if (mutation.forwardedBy.contains(_deviceId) ||

                    mutation.originDeviceId == _deviceId) {

                  continue;

                }



                if (mutation.hopCount >= 5) {

                  continue;

                }



                final applied = await _syncService.applyRemoteP2PMutation(

                  mutation,

                  _storage,

                );



                if (applied) {

                  receivedCount++;

                }

              }

            }

          }

        }

      }



      final totalExchanged = sentCount + receivedCount;



      if (totalExchanged > 0) {

        _lastSyncedOperationsCount = totalExchanged;



        _lastSyncTimestamp = DateTime.now();

      }



      if (_discoveredPeers.containsKey(peer.deviceId)) {

        _discoveredPeers[peer.deviceId] = _discoveredPeers[peer.deviceId]!

            .copyWith(

              lastSyncedAt: DateTime.now(),



              lastSyncedChanges: totalExchanged,



              isSyncing: false,

            );



        _notifyPeersChanged();

      }



      await _storage.addSyncLog(

        source: 'Nearby Peer (${peer.displayName})',



        status: 'synced',



        changesSent: sentCount,



        changesReceived: receivedCount,



        tripId: effectiveTripIds.isNotEmpty ? effectiveTripIds.first : null,



        details: 'Exchanged $sentCount sent, $receivedCount received via P2P',

      );



      _setStatus(P2PStatus.synced);



      return NearbySyncResult(

        success: true,



        operationsSent: sentCount,



        operationsReceived: receivedCount,



        sharedTripIds: effectiveTripIds.toList(),

      );

    } catch (e) {

      debugPrint('[P2PSync] Error syncing with peer ${peer.deviceId}: $e');



      if (_discoveredPeers.containsKey(peer.deviceId)) {

        _discoveredPeers[peer.deviceId] = _discoveredPeers[peer.deviceId]!

            .copyWith(isSyncing: false);



        _notifyPeersChanged();

      }



      _setStatus(P2PStatus.error);



      return NearbySyncResult(

        success: false,



        operationsSent: sentCount,



        operationsReceived: receivedCount,



        errorMessage: e.toString(),

      );

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

        final senderDeviceId = request.uri.queryParameters['deviceId'];

        final senderUserId = request.uri.queryParameters['userId'];

        final sessionToken = request.uri.queryParameters['sessionToken'];

        final timestampStr = request.uri.queryParameters['timestamp'];

        final timestampMs = timestampStr != null ? int.tryParse(timestampStr) : null;



        if (tripId == null || tripId.isEmpty) {

          response.statusCode = HttpStatus.badRequest;

          response.write(jsonEncode({'error': 'tripId is required'}));

          await response.close();

          return;

        }



        // Verify local authorization for this trip

        final trips = _storage.getSavedTrips();

        final trip = trips.firstWhere(

          (t) => t['id'] == tripId,

          orElse: () => {},

        );



        if (trip.isEmpty) {

          response.statusCode = HttpStatus.forbidden;

          response.write(

            jsonEncode({'error': 'Trip not found or unauthorized'}),

          );

          await response.close();

          return;

        }



        final inviteCode = trip['inviteCode']?.toString() ?? '';

        final p2pSecret =

            trip['p2pTripSecret']?.toString() ??

            trip['p2p_trip_secret']?.toString();

        final authKey = deriveTripAuthKey(

          tripId,

          inviteCode,

          p2pTripSecret: p2pSecret,

        );



        // Strict session token verification if provided or required for v2

        if (sessionToken != null && senderDeviceId != null && senderUserId != null && timestampMs != null) {

          final isSessionValid = verifyP2PSessionToken(

            authKey: authKey,

            sessionToken: sessionToken,

            protocolVersion: protocolTag,

            tripId: tripId,

            senderDeviceId: senderDeviceId,

            senderUserId: senderUserId,

            timestampMs: timestampMs,

            maxSkewSeconds: 120,

          );



          if (!isSessionValid) {

            response.statusCode = HttpStatus.unauthorized;

            response.write(jsonEncode({'error': 'Invalid or expired session token'}));

            await response.close();

            return;

          }



          // Verify senderUserId is an authorized, claimed member

          final membersList = trip['members'] as List<dynamic>? ?? [];

          if (membersList.isNotEmpty) {

            final isAuthorizedClaimed = membersList.any((m) {

              if (m is Map) {

                final isVirtual = m['isVirtual'] == true ||

                    m['is_virtual'] == true ||

                    m['isClaimed'] == false ||

                    m['is_claimed'] == false ||

                    (m['userId'] as String? ?? '').startsWith('unclaimed_');

                final memberUserId = m['userId'] as String? ?? m['user_id'] as String? ?? '';

                final mId = m['id']?.toString() ?? ''; return (!isVirtual && memberUserId == senderUserId) || (mId.isNotEmpty && mId == senderUserId);

              }

              return false;

            });



            if (!isAuthorizedClaimed) {

              response.statusCode = HttpStatus.forbidden;

              response.write(jsonEncode({'error': 'Sender is not an authorized claimed member of this trip'}));

              await response.close();

              return;

            }

          }

        } else if (p2pSecret != null && p2pSecret.isNotEmpty) {

          response.statusCode = HttpStatus.unauthorized;

          response.write(jsonEncode({'error': 'Session token required for v2 trips'}));

          await response.close();

          return;

        }



        final pendingOps = _syncService

            .getPendingMutationsForTrip(tripId)

            .map((m) => m.id)

            .toList();



        final processedP2POps = _storage.getProcessedP2POperationIds();



        final allKnownOps = {...pendingOps, ...processedP2POps}.toList();



        response.statusCode = HttpStatus.ok;



        response.write(

          jsonEncode({

            'protocol': protocolTag,



            'tripId': tripId,



            'deviceId': _deviceId,



            'knownOperations': allKnownOps,

          }),

        );



        await response.close();



        return;

      }



      if (path == '/kith-p2p/operations' && request.method == 'POST') {

        if (request.contentLength > 2 * 1024 * 1024) {

          response.statusCode = HttpStatus.requestEntityTooLarge;



          response.write(jsonEncode({'error': 'Payload exceeds 2MB limit'}));



          await response.close();



          return;

        }



        final content = await utf8.decoder.bind(request).join();



        final json = jsonDecode(content) as Map<String, dynamic>;



        final tripId = json['tripId'] as String?;

        final senderDeviceId = json['deviceId'] as String?;

        final senderUserId = json['userId'] as String?;

        final sessionToken = json['sessionToken'] as String?;

        final timestampMs = json['timestamp'] as int?;

        final opsList = json['operations'] as List<dynamic>?;



        final knownLocalOps =

            (json['knownLocalOperations'] as List<dynamic>?)

                ?.map((e) => e.toString())

                .toSet() ??

            {};



        if (tripId == null || opsList == null || senderDeviceId == null) {

          response.statusCode = HttpStatus.badRequest;



          response.write(

            jsonEncode({'error': 'tripId, deviceId, and operations required'}),

          );



          await response.close();



          return;

        }



        // Verify local user shares this trip



        final trips = _storage.getSavedTrips();



        final trip = trips.firstWhere(

          (t) => t['id'] == tripId,

          orElse: () => {},

        );



        final inviteCode = trip['inviteCode']?.toString();



        if (trip.isEmpty || inviteCode == null || inviteCode.isEmpty) {

          response.statusCode = HttpStatus.forbidden;



          response.write(

            jsonEncode({'error': 'Trip unauthorized or missing invite code'}),

          );



          await response.close();



          return;

        }



        final p2pSecret =

            trip['p2pTripSecret']?.toString() ??

            trip['p2p_trip_secret']?.toString();



        final authKey = deriveTripAuthKey(

          tripId,

          inviteCode,

          p2pTripSecret: p2pSecret,

        );



        // Strict session token verification if provided or required for v2

        if (sessionToken != null && senderUserId != null && timestampMs != null) {

          final isSessionValid = verifyP2PSessionToken(

            authKey: authKey,

            sessionToken: sessionToken,

            protocolVersion: protocolTag,

            tripId: tripId,

            senderDeviceId: senderDeviceId,

            senderUserId: senderUserId,

            timestampMs: timestampMs,

            maxSkewSeconds: 120,

          );



          if (!isSessionValid) {

            response.statusCode = HttpStatus.unauthorized;

            response.write(jsonEncode({'error': 'Invalid or expired session token'}));

            await response.close();

            return;

          }



          // Verify senderUserId is an authorized, claimed member

          final membersList = trip['members'] as List<dynamic>? ?? [];

          if (membersList.isNotEmpty) {

            final isAuthorizedClaimed = membersList.any((m) {

              if (m is Map) {

                final isVirtual = m['isVirtual'] == true ||

                    m['is_virtual'] == true ||

                    m['isClaimed'] == false ||

                    m['is_claimed'] == false ||

                    (m['userId'] as String? ?? '').startsWith('unclaimed_');

                final memberUserId = m['userId'] as String? ?? m['user_id'] as String? ?? '';

                final mId = m['id']?.toString() ?? ''; return (!isVirtual && memberUserId == senderUserId) || (mId.isNotEmpty && mId == senderUserId);

              }

              return false;

            });



            if (!isAuthorizedClaimed) {

              response.statusCode = HttpStatus.forbidden;

              response.write(jsonEncode({'error': 'Sender is not an authorized claimed member of this trip'}));

              await response.close();

              return;

            }

          }

        } else if (p2pSecret != null && p2pSecret.isNotEmpty) {

          response.statusCode = HttpStatus.unauthorized;

          response.write(jsonEncode({'error': 'Session token required for v2 trips'}));

          await response.close();

          return;

        }



        int appliedCount = 0;



        final processedIds = <String>[];



        for (final rawOp in opsList) {

          if (rawOp is Map<String, dynamic>) {

            final sig = rawOp['signature'] as String?;



            final sigTs = rawOp['signatureTimestamp'] as int?;



            final opId = rawOp['id'] as String?;



            final payloadChecksum = rawOp['payloadChecksum'] as String?;



            if (sig == null ||

                sigTs == null ||

                opId == null ||

                payloadChecksum == null) {

              debugPrint(

                '[P2PSync] Dropping incoming operation without HMAC signature: $opId',

              );



              continue;

            }



            // Virtual participant rejection: Virtual members cannot generate or sign mutations

            final opPayload = rawOp['payload'];

            if (opPayload is Map<String, dynamic>) {

              final opUserId = opPayload['userId'] as String? ?? opPayload['creatorId'] as String? ?? '';

              if (opUserId.startsWith('unclaimed_')) {

                debugPrint(

                  '[P2PSync] Dropping incoming operation attributed to virtual participant: ',

                );

                continue;

              }

            }



            // Strict Protocol Separation:

            // Modern trips (with p2pTripSecret) require valid v2 HMAC signatures.

            // Legacy trips (without p2pTripSecret) authenticate using legacy v1 (inviteCode).

            // A failed v2 verification NEVER downgrades to v1!

            final isValid = verifyP2POperationSignature(

              authKey: authKey,

              signature: sig,

              protocolVersion: protocolTag,

              tripId: tripId,

              operationId: opId,

              senderDeviceId: senderDeviceId,

              payloadChecksum: payloadChecksum,

              timestampMs: sigTs,

            );



            if (!isValid) {

              debugPrint(

                '[P2PSync] Rejecting untrusted operation HMAC signature: $opId from $senderDeviceId',

              );



              continue;

            }



            // Persistent replay detection across restarts



            final opStatus = _storage.checkOperationStatus(

              opId,

              payloadChecksum,

            );



            if (opStatus.isMismatch) {

              debugPrint(

                '[P2PSync] Replay alert: Operation $opId payload mismatch! Dropping.',

              );



              continue;

            }



            if (opStatus.isProcessed) {

              // Operation already applied in domain state; acknowledge to stop peer retry without duplicating



              processedIds.add(opId);



              continue;

            }



            final mutation = SyncMutation.fromJson(rawOp);



            if (mutation.forwardedBy.contains(_deviceId) ||

                mutation.originDeviceId == _deviceId) {

              continue;

            }



            if (mutation.hopCount >= 5) {

              continue;

            }



            final applied = await _syncService.applyRemoteP2PMutation(

              mutation,

              _storage,

            );



            if (applied) {

              appliedCount++;



              processedIds.add(mutation.id);

            }

          }

        }



        // Return local operations for this trip that the peer doesn't have yet, signed with authKey



        final localQueue = _syncService.getPendingMutationsForTrip(tripId);



        final returnNowMs = DateTime.now().millisecondsSinceEpoch;



        final returnOps = localQueue

            .where((m) => !knownLocalOps.contains(m.id))

            .map((m) {

              final updatedForwarded = m.forwardedBy.contains(_deviceId)

                  ? m.forwardedBy

                  : [...m.forwardedBy, _deviceId];



              final opJson = m.copyWith(forwardedBy: updatedForwarded).toJson();



              final sig = computeP2POperationSignature(

                authKey: authKey,



                protocolVersion: protocolTag,



                tripId: tripId,



                operationId: m.id,



                senderDeviceId: _deviceId,



                payloadChecksum: m.payloadChecksum,



                timestampMs: returnNowMs,

              );



              opJson['signature'] = sig;



              opJson['signatureTimestamp'] = returnNowMs;



              return opJson;

            })

            .toList();



        final myUser = _storage.getSavedUser();

        final myUserId = myUser?['id']?.toString() ?? '';

        final ackSessionToken = myUserId.isNotEmpty

            ? computeP2PSessionToken(

                authKey: authKey,

                protocolVersion: protocolTag,

                tripId: tripId,

                senderDeviceId: _deviceId,

                senderUserId: myUserId,

                timestampMs: returnNowMs,

              )

            : null;



        response.statusCode = HttpStatus.ok;



        response.write(

          jsonEncode({

            'status': 'ACK',

            'deviceId': _deviceId,

            'userId': myUserId,

            'timestampMs': returnNowMs,

            'sessionToken': ackSessionToken,

            'appliedCount': appliedCount,

            'processedOperationIds': processedIds,

            'returnOperations': returnOps,

            'timestamp': DateTime.now().toIso8601String(),

          }),

        );



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

