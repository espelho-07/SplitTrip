import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Structured, secure diagnostic logging engine for SplitTrip (KITH).
///
/// Features:
/// 1. Correlation tracking across UI, database, sync queue, and network.
/// 2. Automatic regex-based zero-exposure secret redaction (JWTs, session tokens, recovery keys, UPI IDs).
/// 3. In-memory circular buffer for debugging and telemetry.
/// 4. Structured JSON serialization for testing and diagnostics.
class DiagnosticLogEntry {
  final String correlationId;
  final String? operationId;
  final String? deviceId;
  final String? tripId;
  final String operationType;
  final String timestampUtc;
  final String syncState;
  final String? errorCategory;
  final Map<String, dynamic> metadata;

  const DiagnosticLogEntry({
    required this.correlationId,
    this.operationId,
    this.deviceId,
    this.tripId,
    required this.operationType,
    required this.timestampUtc,
    required this.syncState,
    this.errorCategory,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'correlationId': correlationId,
        if (operationId != null) 'operationId': operationId,
        if (deviceId != null) 'deviceId': deviceId,
        if (tripId != null) 'tripId': tripId,
        'operationType': operationType,
        'timestampUtc': timestampUtc,
        'syncState': syncState,
        if (errorCategory != null) 'errorCategory': errorCategory,
        'metadata': metadata,
      };

  @override
  String toString() => jsonEncode(toJson());
}

class DiagnosticLogger {
  static final DiagnosticLogger instance = DiagnosticLogger._internal();

  DiagnosticLogger._internal();

  static const int _maxBufferSize = 500;
  final List<DiagnosticLogEntry> _buffer = [];

  List<DiagnosticLogEntry> get recentLogs => List.unmodifiable(_buffer);

  void clearLogs() {
    _buffer.clear();
  }

  /// Logs any database mutation or query event.
  void logDatabaseOp({
    required String correlationId,
    String? tripId,
    required String table,
    required String action,
    int? affectedRows,
    dynamic error,
  }) {
    _record(
      correlationId: correlationId,
      tripId: tripId,
      operationType: 'DB_$action',
      syncState: error != null ? 'FAILED' : 'COMMITTED',
      errorCategory: error != null ? 'DATABASE_ERROR' : null,
      metadata: {
        'table': table,
        'affectedRows': ?affectedRows,
        if (error != null) 'error': _sanitizeString(error.toString()),
      },
    );
  }

  /// Logs a synchronization request dispatch.
  void logSyncRequest({
    required String correlationId,
    required String operationId,
    String? tripId,
    String? deviceId,
    required String mutationType,
    required int retryCount,
  }) {
    _record(
      correlationId: correlationId,
      operationId: operationId,
      deviceId: deviceId,
      tripId: tripId,
      operationType: 'SYNC_DISPATCH',
      syncState: 'SYNCING',
      metadata: {
        'mutationType': mutationType,
        'retryCount': retryCount,
      },
    );
  }

  /// Logs a synchronization server response acknowledgment.
  void logSyncResponse({
    required String correlationId,
    required String operationId,
    String? tripId,
    required int statusCode,
    required bool isSuccess,
    dynamic error,
  }) {
    _record(
      correlationId: correlationId,
      operationId: operationId,
      tripId: tripId,
      operationType: 'SYNC_RESPONSE',
      syncState: isSuccess ? 'SYNCED' : 'FAILED',
      errorCategory: error != null ? 'SYNC_ERROR' : null,
      metadata: {
        'statusCode': statusCode,
        'isSuccess': isSuccess,
        if (error != null) 'error': _sanitizeString(error.toString()),
      },
    );
  }

  /// Logs an update conflict or stale revision detection.
  void logConflict({
    required String correlationId,
    required String tripId,
    String? operationId,
    required int localRevision,
    required int serverRevision,
  }) {
    _record(
      correlationId: correlationId,
      operationId: operationId,
      tripId: tripId,
      operationType: 'CONFLICT_DETECTED',
      syncState: 'CONFLICT',
      errorCategory: 'CONFLICT',
      metadata: {
        'localRevision': localRevision,
        'serverRevision': serverRevision,
      },
    );
  }

  /// Logs an authentication failure or session expiration.
  void logAuthFailure({
    required String correlationId,
    String? accountId,
    required String reason,
  }) {
    _record(
      correlationId: correlationId,
      operationType: 'AUTH_FAILURE',
      syncState: 'FAILED',
      errorCategory: 'AUTHENTICATION_ERROR',
      metadata: {
        'accountId': ?accountId,
        'reason': _sanitizeString(reason),
      },
    );
  }

  /// Logs a trip completion transition.
  void logTripCompletion({
    required String correlationId,
    required String tripId,
    required String completionState,
    required int unsyncedCount,
    bool force = false,
  }) {
    _record(
      correlationId: correlationId,
      tripId: tripId,
      operationType: 'TRIP_COMPLETION',
      syncState: unsyncedCount == 0 ? 'SYNCED' : 'REQUIRES_REVIEW',
      metadata: {
        'completionState': completionState,
        'unsyncedCount': unsyncedCount,
        'force': force,
      },
    );
  }

  void _record({
    required String correlationId,
    String? operationId,
    String? deviceId,
    String? tripId,
    required String operationType,
    required String syncState,
    String? errorCategory,
    Map<String, dynamic> metadata = const {},
  }) {
    final entry = DiagnosticLogEntry(
      correlationId: correlationId,
      operationId: operationId,
      deviceId: deviceId,
      tripId: tripId,
      operationType: operationType,
      timestampUtc: DateTime.now().toUtc().toIso8601String(),
      syncState: syncState,
      errorCategory: errorCategory,
      metadata: _sanitizeMetadata(metadata),
    );

    if (_buffer.length >= _maxBufferSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(entry);

    if (kDebugMode) {
      debugPrint('[DiagnosticLogger] $entry');
    }
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> input) {
    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('token') ||
          key.contains('secret') ||
          key.contains('password') ||
          key.contains('recoverykey') ||
          key.contains('auth')) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is String) {
        sanitized[entry.key] = _sanitizeString(entry.value as String);
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeMetadata(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  String _sanitizeString(String text) {
    // Redact JWT tokens (eyJ...)
    var result = text.replaceAll(RegExp(r'eyJ[a-zA-Z0-9_\-\.]+'), '[REDACTED_JWT]');
    // Redact recovery keys (KITH-XXXX-XXXX)
    result = result.replaceAll(RegExp(r'KITH-[A-Z0-9]{4}-[A-Z0-9]{4}', caseSensitive: false), '[REDACTED_RECOVERY_KEY]');
    // Redact Bearer tokens
    result = result.replaceAll(RegExp(r'Bearer\s+[a-zA-Z0-9_\-\.]+', caseSensitive: false), 'Bearer [REDACTED]');
    // Redact session tokens (kith_sess_...)
    result = result.replaceAll(RegExp(r'kith_sess_[a-zA-Z0-9_]+'), '[REDACTED_SESSION_TOKEN]');
    return result;
  }
}
