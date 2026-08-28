import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeTripEvent {
  final String? eventId;
  final String type;
  final String? entityType;
  final String? entityId;
  final String tripId;
  final String? userId;
  final String? actorId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> payload;
  final int version;
  final DateTime timestamp;

  const RealtimeTripEvent({
    this.eventId,
    required this.type,
    this.entityType,
    this.entityId,
    required this.tripId,
    this.userId,
    this.actorId,
    required this.data,
    required this.payload,
    this.version = 1,
    required this.timestamp,
  });

  factory RealtimeTripEvent.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['payload'] is Map<String, dynamic> ? json['payload'] as Map<String, dynamic> : <String, dynamic>{});

    return RealtimeTripEvent(
      eventId: json['eventId'] as String?,
      type: json['type'] as String? ?? json['eventType'] as String? ?? 'unknown',
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      tripId: json['tripId'] as String? ?? (rawData['tripId'] as String? ?? ''),
      userId: json['userId'] as String?,
      actorId: json['actorId'] as String? ?? (rawData['actorId'] as String?),
      data: rawData,
      payload: rawData,
      version: json['version'] is int ? json['version'] as int : 1,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get eventType => type;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'type': type,
        'entityType': entityType,
        'entityId': entityId,
        'tripId': tripId,
        'userId': userId,
        'actorId': actorId,
        'data': data,
        'payload': payload,
        'version': version,
        'timestamp': timestamp.toIso8601String(),
      };
}

typedef RealtimeSyncEvent = RealtimeTripEvent;

class RealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<RealtimeTripEvent> _eventController =
      StreamController<RealtimeTripEvent>.broadcast();
  final StreamController<RealtimeConnectionState> _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();

  final Set<String> _activeSubscribedTripIds = {};
  final List<String> _processedEventIds = [];
  static const int _maxProcessedEventIds = 200;

  String? _authToken;
  String? _currentUserId;
  bool _isConnected = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  DateTime? _lastEventTimestamp;

  Stream<RealtimeTripEvent> get events => _eventController.stream;
  Stream<RealtimeConnectionState> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  void setAuthToken(String? token, {String? userId}) {
    _authToken = token;
    if (userId != null) {
      _currentUserId = userId;
    }
    if (_isConnected) {
      _sendAuth();
    }
  }

  void connect() {
    if (_isDisposed) return;
    _cleanupChannel();
    _updateConnectionState(RealtimeConnectionState.connecting);

    try {
      final wsUrl = AppConfig.wsUrl;
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.ready.then((_) {
        if (_isDisposed) return;
        _isConnected = true;
        _reconnectAttempts = 0;
        _updateConnectionState(RealtimeConnectionState.connected);

        // Authenticate immediately
        _sendAuth();

        // Resubscribe to user room
        if (_currentUserId != null) {
          _sendSubscribeUser(_currentUserId!);
        }

        // Resubscribe to all active trip rooms
        for (final tripId in _activeSubscribedTripIds) {
          _sendSubscribe(tripId);
          // Request catchup if we had previous events
          if (_lastEventTimestamp != null) {
            _sendCatchup(tripId: tripId, since: _lastEventTimestamp!);
          }
        }
      }).catchError((err) {
        debugPrint('[RealtimeClient] Connection handshake failed: $err');
        _isConnected = false;
        _cleanupChannel();
        _scheduleReconnect();
      });

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (err) {
          debugPrint('[RealtimeClient] Stream error: $err');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[RealtimeClient] Connect error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _updateConnectionState(RealtimeConnectionState state) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
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

  void subscribeToUser(String userId) {
    _currentUserId = userId;
    if (_isConnected) {
      _sendSubscribeUser(userId);
    } else {
      connect();
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

  void _sendSubscribeUser(String userId) {
    _sendJson({
      'action': 'subscribe',
      'scope': 'user',
      'userId': userId,
      'token': _authToken,
    });
  }

  void _sendCatchup({String? tripId, required DateTime since}) {
    _sendJson({
      'action': 'catchup',
      'tripId': ?tripId,
      'sinceTimestamp': since.toIso8601String(),
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

  @visibleForTesting
  void handleRawMessage(dynamic raw) {
    _handleMessage(raw);
  }

  void _handleMessage(dynamic raw) {
    try {
      final dynamic decoded = raw is Map<String, dynamic>
          ? raw
          : (raw is Map ? Map<String, dynamic>.from(raw) : jsonDecode(raw.toString()));

      if (decoded is Map<String, dynamic>) {

        final type = decoded['type'] as String?;

        if (type == 'connected' || type == 'subscribed' || type == 'unsubscribed' || type == 'auth_success') {
          return;
        }

        // Handle catchup batch
        if (type == 'catchup_response' && decoded['events'] is List) {
          final list = decoded['events'] as List;
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              _processEvent(RealtimeTripEvent.fromJson(item));
            }
          }
          return;
        }

        final event = RealtimeTripEvent.fromJson(decoded);
        _processEvent(event);
      }
    } catch (_) {
      // Ignore malformed payloads
    }
  }

  void _processEvent(RealtimeTripEvent event) {
    // Deduplication check
    if (event.eventId != null && event.eventId!.isNotEmpty) {
      if (_processedEventIds.contains(event.eventId)) {
        return; // Skip already processed event
      }
      _processedEventIds.add(event.eventId!);
      if (_processedEventIds.length > _maxProcessedEventIds) {
        _processedEventIds.removeAt(0);
      }
    }

    _lastEventTimestamp = event.timestamp;
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _updateConnectionState(RealtimeConnectionState.reconnecting);
    _reconnectTimer?.cancel();

    // Exponential backoff with jitter: 1s, 2s, 4s, 8s, max 16s + jitter
    final baseSeconds = min(16, pow(2, _reconnectAttempts).toInt());
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: baseSeconds, milliseconds: jitterMs);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void _cleanupChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _activeSubscribedTripIds.clear();
    _cleanupChannel();
    _isConnected = false;
    _updateConnectionState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanupChannel();
    _eventController.close();
    _connectionStateController.close();
  }
}

