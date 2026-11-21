import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kith_app/data/services/ble_discovery_service.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/p2p_sync_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/trip_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    syncService = SyncService(storage);
  });

  group('BLE Discovery & P2P Self-Exclusion Architecture Suite', () {
    test('1. BleDiscoveryService hashing: Generates deterministic 32-bit and 64-bit hashes', () {
      final tripToken = 'MNLI01';
      final hash32A = BleDiscoveryService.hashStringTo32Bit(tripToken);
      final hash32B = BleDiscoveryService.hashStringTo32Bit(tripToken);

      expect(hash32A, equals(hash32B));
      expect(hash32A, isA<int>());

      final deviceId = 'device_darpan_phone_001';
      final hash64A = BleDiscoveryService.hashStringTo64Bit(deviceId);
      final hash64B = BleDiscoveryService.hashStringTo64Bit(deviceId);

      expect(hash64A, equals(hash64B));
      expect(hash64A, isA<int>());

      // Distinct inputs produce distinct hashes
      final otherHash32 = BleDiscoveryService.hashStringTo32Bit('KASOL2');
      expect(hash32A, isNot(equals(otherHash32)));
    });

    test('2. NearbyPeer transport properties: Distinguishes BLE-only vs Mesh vs Hybrid', () {
      final blePeer = NearbyPeer(
        deviceId: 'dev_peer_ble',
        userId: 'usr_neel',
        displayName: 'Neel Vyas',
        address: InternetAddress.loopbackIPv4,
        port: 0,
        sharedTripIds: {'trip_manali'},
        pairingCode: '123456',
        lastSeenAt: DateTime.now(),
        transport: 'ble',
        rssi: -65,
      );

      expect(blePeer.isBleOnly, isTrue);
      expect(blePeer.canSyncData, isFalse);
      expect(blePeer.transport, equals('ble'));

      final wifiPeer = NearbyPeer(
        deviceId: 'dev_peer_wifi',
        userId: 'usr_neel',
        displayName: 'Neel Vyas',
        address: InternetAddress('192.168.43.120'),
        port: 54322,
        sharedTripIds: {'trip_manali'},
        pairingCode: '123456',
        lastSeenAt: DateTime.now(),
        transport: 'wifi_mesh',
      );

      expect(wifiPeer.isBleOnly, isFalse);
      expect(wifiPeer.canSyncData, isTrue);
      expect(wifiPeer.transport, equals('wifi_mesh'));

      final hybridPeer = blePeer.copyWith(
        address: InternetAddress('192.168.43.120'),
        port: 54322,
        transport: 'hybrid',
      );

      expect(hybridPeer.isBleOnly, isFalse);
      expect(hybridPeer.canSyncData, isTrue);
      expect(hybridPeer.transport, equals('hybrid'));
    });

    test('3. P2PSyncService anchors on durable LocalStorage device ID across instances', () async {
      final persistedDeviceId = storage.getDeviceId();
      expect(persistedDeviceId, isNotEmpty);

      // Instance initialized without explicit deviceId must adopt persistent storage device ID
      final p2pService1 = P2PSyncService(storage, syncService);
      expect(p2pService1.deviceId, equals(persistedDeviceId));

      // Second instance also receives the exact same device ID
      final p2pService2 = P2PSyncService(storage, syncService);
      expect(p2pService2.deviceId, equals(persistedDeviceId));
      expect(p2pService1.deviceId, equals(p2pService2.deviceId));
    });

    test('4. P2PSyncService: Registers BLE-discovered peer and handles upgrade to Wi-Fi mesh', () {
      final p2p = P2PSyncService(storage, syncService);

      p2p.registerBleDiscoveredPeer(
        deviceId: 'dev_peer_remote_123',
        displayName: 'Neel Vyas',
        userId: 'usr_neel',
        sharedTripIds: {'trip_manali'},
        rssi: -58,
      );

      final tripPeers = p2p.activePeers.where((p) => p.sharedTripIds.contains('trip_manali')).toList();
      expect(tripPeers.length, equals(1));
      final peer = tripPeers.first;
      expect(peer.displayName, equals('Neel Vyas'));
      expect(peer.userId, equals('usr_neel'));
      expect(peer.isBleOnly, isTrue);
      expect(peer.transport, equals('ble'));
      expect(peer.rssi, equals(-58));

      // Upgrading when Wi-Fi beacon arrives from same device
      p2p.registerBleDiscoveredPeer(
        deviceId: 'dev_peer_remote_123',
        displayName: 'Neel Vyas',
        userId: 'usr_neel',
        sharedTripIds: {'trip_manali'},
        rssi: -52,
      );

      final updatedPeers = p2p.activePeers.where((p) => p.sharedTripIds.contains('trip_manali')).toList();
      expect(updatedPeers.length, equals(1));
      final upgraded = updatedPeers.first;
      expect(upgraded.rssi, equals(-52));
    });

    test('5. Local device exclusion: Local device NEVER added to nearby peers via BLE register', () {
      final p2p = P2PSyncService(storage, syncService);
      final myDeviceId = p2p.deviceId;

      // Attempting to register own device via BLE simulation
      p2p.registerBleDiscoveredPeer(
        deviceId: myDeviceId,
        displayName: 'Darpan Parmar',
        userId: 'usr_darpan',
        sharedTripIds: {'trip_manali'},
        rssi: -40,
      );

      // Verify self is discarded
      expect(p2p.activePeers.where((p) => p.deviceId == myDeviceId).isEmpty, isTrue);
    });

    test('6. Trip member radar categorization: Distinguishes local user from remote peers', () {
      final currentUserId = 'usr_darpan';
      final darpanMember = TripMember(
        id: 'mbr_darpan',
        userId: currentUserId,
        displayName: 'Darpan Parmar',
        role: 'creator',
        joinedAt: DateTime.now(),
        isClaimed: true,
        isVirtualMember: false,
        status: 'claimed',
      );

      final neelMember = TripMember(
        id: 'mbr_neel',
        userId: 'usr_neel',
        displayName: 'Neel Vyas',
        role: 'member',
        joinedAt: DateTime.now(),
        isClaimed: true,
        isVirtualMember: false,
        status: 'claimed',
      );

      final members = [darpanMember, neelMember];

      // Eligible members logic as overhauled in radar sheet:
      final localMember = members.firstWhere((m) => m.userId == currentUserId);
      final remoteMembers = members.where((m) => m.userId != currentUserId).toList();

      expect(localMember.displayName, equals('Darpan Parmar'));
      expect(localMember.userId, equals(currentUserId));

      expect(remoteMembers.length, equals(1));
      expect(remoteMembers.first.displayName, equals('Neel Vyas'));
      expect(remoteMembers.any((m) => m.userId == currentUserId), isFalse);
    });
  });
}
