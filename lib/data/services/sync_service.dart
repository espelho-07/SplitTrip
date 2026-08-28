import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import 'local_storage_service.dart';

enum MutationType {
  createTrip,
  joinTrip,
  updateTripLifecycle,
  addExpense,
  updateExpense,
  deleteExpense,
  createPersonalExpense,
  updatePersonalExpense,
  deletePersonalExpense,
  createPersonalDebt,
  recordPersonalRepayment,
  deletePersonalDebt,
  setPersonalBudget,
  createJourneyMoment,
  deleteJourneyMoment,
  recordTripSettlement,
}

enum SyncStatus {
  synced,
  syncing,
  pending,
  offline,
  reconnecting,
  error,
}

class SyncMutation {
  final String id;
  final String idempotencyKey;
  final MutationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;

  SyncMutation({
    required this.id,
    String? idempotencyKey,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
  }) : idempotencyKey = idempotencyKey ?? id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'idempotencyKey': idempotencyKey,
    'type': type.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
  };

  factory SyncMutation.fromJson(Map<String, dynamic> json) => SyncMutation(
    id: json['id'] as String,
    idempotencyKey: json['idempotencyKey'] as String? ?? json['id'] as String,
    type: MutationType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MutationType.addExpense,
    ),
    payload: json['payload'] is Map<String, dynamic> ? json['payload'] as Map<String, dynamic> : {},
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    retryCount: json['retryCount'] as int? ?? 0,
    lastAttemptAt: json['lastAttemptAt'] != null
        ? DateTime.tryParse(json['lastAttemptAt'] as String)
        : null,
  );

  SyncMutation copyWith({int? retryCount, DateTime? lastAttemptAt}) => SyncMutation(
    id: id,
    idempotencyKey: idempotencyKey,
    type: type,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );
}

/// Offline-first synchronization queue service.
/// Enqueues user mutations when offline and processes them with jittered backoff.
class SyncService {
  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();
  bool _isProcessing = false;
  SyncStatus _currentStatus = SyncStatus.synced;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncService(this._storage);

  bool get isProcessing => _isProcessing;
  int get pendingCount => getPendingMutations().length;
  int get pendingMutationCount => pendingCount;
  List<SyncMutation> getQueue() => getPendingMutations();
  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;


  void _setStatus(SyncStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  List<SyncMutation> getPendingMutations() {
    final raw = _storage.getMutationQueue();
    return raw.map((json) => SyncMutation.fromJson(json)).toList();
  }

  Future<SyncMutation> enqueueMutation(
    MutationType type,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
    ApiClient? backgroundApiClient,
  }) async {
    final mutationId = _uuid.v4();
    final mutation = SyncMutation(
      id: mutationId,
      idempotencyKey: idempotencyKey ?? mutationId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    final queue = getPendingMutations();
    queue.add(mutation);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    _setStatus(SyncStatus.pending);

    // If API client provided, trigger non-blocking immediate background flush
    if (backgroundApiClient != null) {
      unawaited(flushQueue(backgroundApiClient));
    }

    return mutation;
  }

  Future<void> removeMutation(String id) async {
    final queue = getPendingMutations();
    queue.removeWhere((m) => m.id == id);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    if (queue.isEmpty) {
      _setStatus(SyncStatus.synced);
    }
  }

  Future<void> _updateMutationAttempt(String id, int retryCount) async {
    final queue = getPendingMutations();
    final idx = queue.indexWhere((m) => m.id == id);
    if (idx != -1) {
      queue[idx] = queue[idx].copyWith(
        retryCount: retryCount,
        lastAttemptAt: DateTime.now(),
      );
      await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    }
  }

  /// Processes all pending offline mutations against the remote backend.
  Future<void> flushQueue(ApiClient apiClient) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final queue = getPendingMutations();
      final now = DateTime.now();

      for (final mutation in queue) {
        // Jittered exponential backoff check: base 1s * 2^retryCount, capped at 30s
        if (mutation.lastAttemptAt != null && mutation.retryCount > 0) {
          final backoffSeconds = min(30, pow(2, mutation.retryCount).toInt());
          final nextAllowed = mutation.lastAttemptAt!.add(Duration(seconds: backoffSeconds));
          if (now.isBefore(nextAllowed)) {
            continue; // Skip this item until backoff period passes
          }
        }

        try {
          await _executeMutation(apiClient, mutation);
          await removeMutation(mutation.id);
        } on NetworkException catch (_) {
          // Increment retry count and back off
          await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
          _setStatus(SyncStatus.offline);
          break; // Break loop and retry later when connection returns
        } on ApiException catch (e) {
          // If server rejects with 4xx unrecoverable client error, drop mutation to unblock queue
          debugPrint('[SyncService] Client error ${e.statusCode} for mutation ${mutation.id}: ${e.message}');
          await removeMutation(mutation.id);
        } catch (e) {
          debugPrint('[SyncService] Unexpected error on mutation ${mutation.id}: $e');
          await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
          _setStatus(SyncStatus.error);
          break;
        }
      }

      final remaining = getPendingMutations();
      if (remaining.isEmpty) {
        _setStatus(SyncStatus.synced);
      } else {
        _setStatus(SyncStatus.pending);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeMutation(ApiClient apiClient, SyncMutation mutation) async {
    switch (mutation.type) {
      case MutationType.createTrip:
        await apiClient.post('/trips', body: mutation.payload);
        break;
      case MutationType.joinTrip:
        await apiClient.post('/trips/join', body: mutation.payload);
        break;
      case MutationType.updateTripLifecycle:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.patch('/trips/$tripId/lifecycle', body: mutation.payload);
        break;
      case MutationType.addExpense:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.post('/trips/$tripId/expenses', body: mutation.payload);
        break;
      case MutationType.updateExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = mutation.payload['id'] as String;
        await apiClient.put('/trips/$tripId/expenses/$expenseId', body: mutation.payload);
        break;
      case MutationType.deleteExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = mutation.payload['expenseId'] as String;
        await apiClient.delete('/trips/$tripId/expenses/$expenseId');
        break;
      case MutationType.createPersonalExpense:
        await apiClient.post('/personal/expenses', body: mutation.payload);
        break;
      case MutationType.updatePersonalExpense:
        final id = mutation.payload['id'] as String;
        await apiClient.put('/personal/expenses/$id', body: mutation.payload);
        break;
      case MutationType.deletePersonalExpense:
        final id = mutation.payload['id'] as String;
        await apiClient.delete('/personal/expenses/$id');
        break;
      case MutationType.createPersonalDebt:
        await apiClient.post('/personal/debts', body: mutation.payload);
        break;
      case MutationType.recordPersonalRepayment:
        final debtId = mutation.payload['debtId'] as String;
        await apiClient.post('/personal/debts/$debtId/repayments', body: mutation.payload);
        break;
      case MutationType.deletePersonalDebt:
        final id = mutation.payload['id'] as String;
        await apiClient.delete('/personal/debts/$id');
        break;
      case MutationType.setPersonalBudget:
        await apiClient.put('/personal/budget', body: mutation.payload);
        break;
      case MutationType.createJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentPayload = mutation.payload['moment'] as Map<String, dynamic>;
        await apiClient.post('/trips/$tripId/moments', body: momentPayload);
        break;
      case MutationType.deleteJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentId = mutation.payload['momentId'] as String;
        await apiClient.delete('/trips/$tripId/moments/$momentId');
        break;
      case MutationType.recordTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.post('/trips/$tripId/settlements', body: mutation.payload);
        break;
    }
  }

  void dispose() {
    _statusController.close();
  }
}

