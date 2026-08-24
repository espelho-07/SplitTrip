import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class RealtimeTripEvent {
  final String type;
  final String tripId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const RealtimeTripEvent({
    required this.type,
    required this.tripId,
    required this.data,
    required this.timestamp,
  });

  factory RealtimeTripEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeTripEvent(
      type: json['type'] as String? ?? 'unknown',
      tripId: json['tripId'] as String? ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class RealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<RealtimeTripEvent> _eventController =
      StreamController<RealtimeTripEvent>.broadcast();

  final Set<String> _activeSubscribedTripIds = {};
  String? _authToken;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  Stream<RealtimeTripEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  void setAuthToken(String? token) {
    _authToken = token;
    if (_isConnected) {
      _sendAuth();
    }
  }

  void connect() {
    if (_isDisposed) return;
    _cleanupChannel();

    try {
      final wsUrl = AppConfig.wsUrl;
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Authenticate if token exists
      _sendAuth();

      // Resubscribe to existing active trip rooms
      for (final tripId in _activeSubscribedTripIds) {
        _sendSubscribe(tripId);
      }
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _sendAuth() {
    if (_channel != null && _authToken != null) {
      _sendJson({
        'action': 'auth',
        'token': _authToken,
      });
    }
  }

  void subscribeToTrip(String tripId) {
    _activeSubscribedTripIds.add(tripId);
    if (_isConnected) {
      _sendSubscribe(tripId);
    } else {
      connect();
    }
  }

  void unsubscribeFromTrip(String tripId) {
    _activeSubscribedTripIds.remove(tripId);
    if (_isConnected) {
      _sendJson({
        'action': 'unsubscribe',
        'tripId': tripId,
      });
    }
  }

  void _sendSubscribe(String tripId) {
    _sendJson({
      'action': 'subscribe',
      'tripId': tripId,
      'token': _authToken,
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode(payload));
      }
    } catch (_) {
      // Ignored
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'] as String?;
        if (type == 'connected' || type == 'subscribed' || type == 'unsubscribed' || type == 'auth_success') {
          return;
        }

        final event = RealtimeTripEvent.fromJson(decoded);
        _eventController.add(event);
      }
    } catch (_) {
      // Ignore malformed payloads
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void _cleanupChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanupChannel();
    _eventController.close();
  }
}
