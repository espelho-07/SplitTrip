import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a peer device discovered in physical proximity via Bluetooth Low Energy.
class BleDiscoveredEvent {
  final int tripTokenHash;
  final String deviceIdHash;
  final int userIdHash;
  final int rssi;
  final int flags;
  final String? deviceAddress;
  final DateTime timestamp;

  BleDiscoveredEvent({
    required this.tripTokenHash,
    required this.deviceIdHash,
    required this.userIdHash,
    required this.rssi,
    required this.flags,
    this.deviceAddress,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'BleDiscoveredEvent(tripHash: $tripTokenHash, devHash: $deviceIdHash, userHash: $userIdHash, rssi: $rssi dBm)';
}

/// State of the native Bluetooth Low Energy subsystem.
class BleState {
  final bool isSupported;
  final bool isEnabled;
  final bool hasPermissions;
  final bool isAdvertising;
  final bool isScanning;

  const BleState({
    this.isSupported = false,
    this.isEnabled = false,
    this.hasPermissions = false,
    this.isAdvertising = false,
    this.isScanning = false,
  });

  factory BleState.fromMap(Map<dynamic, dynamic> map) {
    return BleState(
      isSupported: map['isSupported'] == true,
      isEnabled: map['isEnabled'] == true,
      hasPermissions: map['hasPermissions'] == true,
      isAdvertising: map['isAdvertising'] == true,
      isScanning: map['isScanning'] == true,
    );
  }
}

/// Service managing native Bluetooth Low Energy discovery for Kith.
class BleDiscoveryService {
  static const MethodChannel _channel = MethodChannel('com.nirniq.kith/ble_discovery');

  final StreamController<BleDiscoveredEvent> _peerDiscoveredController =
      StreamController<BleDiscoveredEvent>.broadcast();
  final StreamController<BleState> _stateController =
      StreamController<BleState>.broadcast();

  BleState _currentState = const BleState();
  BleState get currentState => _currentState;

  Stream<BleDiscoveredEvent> get onPeerDiscovered => _peerDiscoveredController.stream;
  Stream<BleState> get onStateChanged => _stateController.stream;

  BleDiscoveryService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onBlePeerDiscovered':
        try {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final event = BleDiscoveredEvent(
            tripTokenHash: map['tripTokenHash'] as int? ?? 0,
            deviceIdHash: map['deviceIdHash']?.toString() ?? '',
            userIdHash: map['userIdHash'] as int? ?? 0,
            rssi: map['rssi'] as int? ?? -70,
            flags: map['flags'] as int? ?? 0,
            deviceAddress: map['deviceAddress'] as String?,
          );
          _peerDiscoveredController.add(event);
        } catch (e) {
          debugPrint('[BleDiscovery] Error parsing onBlePeerDiscovered: $e');
        }
        break;

      case 'onBleStateChanged':
        try {
          final map = Map<dynamic, dynamic>.from(call.arguments as Map);
          _currentState = BleState.fromMap(map);
          _stateController.add(_currentState);
        } catch (e) {
          debugPrint('[BleDiscovery] Error parsing onBleStateChanged: $e');
        }
        break;
    }
  }

  Future<bool> isSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hashes a string into a signed 32-bit integer for BLE advertisement payloads.
  static int hashStringTo32Bit(String input) {
    if (input.isEmpty) return 0;
    final bytes = sha256.convert(utf8.encode(input)).bytes;
    final buffer = ByteData.sublistView(Uint8List.fromList(bytes));
    return buffer.getInt32(0);
  }

  /// Hashes a string into a signed 64-bit integer for BLE device identifiers.
  static int hashStringTo64Bit(String input) {
    if (input.isEmpty) return 0;
    final bytes = sha256.convert(utf8.encode(input)).bytes;
    final buffer = ByteData.sublistView(Uint8List.fromList(bytes));
    return buffer.getInt64(0);
  }

  /// Starts broadcasting a compact BLE beacon for the given trip.
  Future<bool> startAdvertising({
    required String tripToken,
    required String deviceId,
    required String userId,
  }) async {
    try {
      final tripHash = hashStringTo32Bit(tripToken);
      final devHash = hashStringTo64Bit(deviceId);
      final userHash = hashStringTo32Bit(userId);

      final res = await _channel.invokeMethod<bool>('startAdvertising', {
        'tripTokenHash': tripHash,
        'deviceIdHash': devHash,
        'userIdHash': userHash,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[BleDiscovery] Failed to start advertising: $e');
      return false;
    }
  }

  /// Stops broadcasting BLE discovery beacons.
  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
    } catch (_) {}
  }

  /// Starts scanning for nearby BLE beacons belonging to the specified trip.
  Future<bool> startScanning({
    required String tripToken,
    required String deviceId,
  }) async {
    try {
      final tripHash = hashStringTo32Bit(tripToken);
      final devHash = hashStringTo64Bit(deviceId);

      final res = await _channel.invokeMethod<bool>('startScanning', {
        'tripTokenHash': tripHash,
        'deviceIdHash': devHash,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[BleDiscovery] Failed to start scanning: $e');
      return false;
    }
  }

  /// Stops scanning for BLE discovery beacons.
  Future<void> stopScanning() async {
    try {
      await _channel.invokeMethod('stopScanning');
    } catch (_) {}
  }

  /// Stops all active BLE activities.
  Future<void> stopAll() async {
    try {
      await _channel.invokeMethod('stopAll');
    } catch (_) {}
  }

  void dispose() {
    stopAll();
    _peerDiscoveredController.close();
    _stateController.close();
  }
}
