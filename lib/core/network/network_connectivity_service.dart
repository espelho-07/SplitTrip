import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/sync_service.dart';
import 'api_client.dart';

enum NetworkStatus {
  online,
  offline,
}

abstract class NetworkConnectivityService {
  Future<bool> isOnline();
  Stream<NetworkStatus> get onStatusChanged;
  void dispose();
}

class NetworkConnectivityServiceImpl implements NetworkConnectivityService {
  final Connectivity _connectivity;
  final SyncService? _syncService;
  final ApiClient? _apiClient;
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkConnectivityServiceImpl({
    Connectivity? connectivity,
    this._syncService,
    this._apiClient,
  }) : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  void _init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isNowOnline = _isResultOnline(results);
      final status = isNowOnline ? NetworkStatus.online : NetworkStatus.offline;
      _controller.add(status);

      // Trigger automatic sync on reconnecting to mobile network or Wi-Fi
      if (isNowOnline && _syncService != null && _apiClient != null) {
        _syncService.flushQueue(_apiClient);
      }
    });
  }

  bool _isResultOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  @override
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isResultOnline(results);
    } catch (_) {
      return true; // Graceful fallback
    }
  }

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
