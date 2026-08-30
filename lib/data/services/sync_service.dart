import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/realtime_client.dart';
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
  confirmTripSettlement,
  disputeTripSettlement,
  submitSettlementProof,
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
  final List<String> dependsOn;

  SyncMutation({
    required this.id,
    String? idempotencyKey,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.dependsOn = const [],
  }) : idempotencyKey = idempotencyKey ?? id;

  /// Returns the tripId associated with this mutation, if applicable.
  String? get tripId {
    if (payload.containsKey('tripId') && payload['tripId'] != null) {
      return payload['tripId'] as String;
    }
    if (type == MutationType.createTrip && payload.containsKey('id') && payload['id'] != null) {
      return payload['id'] as String;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'idempotencyKey': idempotencyKey,
    'type': type.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'dependsOn': dependsOn,
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
    dependsOn: json['dependsOn'] is List
        ? (json['dependsOn'] as List).map((e) => e.toString()).toList()
        : const [],
  );

  SyncMutation copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    List<String>? dependsOn,
  }) => SyncMutation(
    id: id,
    idempotencyKey: idempotencyKey,
    type: type,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    dependsOn: dependsOn ?? this.dependsOn,
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

  /// Returns all pending mutations for a specific trip.
  List<SyncMutation> getPendingMutationsForTrip(String tripId) {
    return getPendingMutations().where((m) => m.tripId == tripId).toList();
  }

  /// Returns the number of pending mutations for a specific trip.
  int getPendingCountForTrip(String tripId) {
    return getPendingMutationsForTrip(tripId).length;
  }

  /// Returns true if there are pending un-synced operations for a trip.
  bool hasPendingMutationsForTrip(String tripId) {
    return getPendingCountForTrip(tripId) > 0;
  }

  Future<SyncMutation> enqueueMutation(
    MutationType type,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
    List<String>? dependsOn,
    ApiClient? backgroundApiClient,
  }) async {
    final mutationId = _uuid.v4();
    final mutation = SyncMutation(
      id: mutationId,
      idempotencyKey: idempotencyKey ?? mutationId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
      dependsOn: dependsOn ?? const [],
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

  /// Processes all pending offline mutations against the remote backend in dependency order.
  Future<void> flushQueue(ApiClient apiClient, {bool force = false}) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final queue = getPendingMutations();
      final now = DateTime.now();

      // Track blocked trip IDs in this pass (if an earlier mutation for a trip failed, subsequent dependent operations must wait)
      final blockedTripIds = <String>{};
      final completedMutationIds = <String>{};

      for (final mutation in queue) {
        final tId = mutation.tripId;

        // If trip is blocked due to prior failure in this cycle, skip
        if (tId != null && blockedTripIds.contains(tId)) {
          continue;
        }

        // Dependency check: If any mutation in dependsOn is still pending in the queue, skip
        final pendingIds = queue.map((m) => m.id).toSet();
        final hasUnresolvedDependencies = mutation.dependsOn.any(
          (depId) => pendingIds.contains(depId) && !completedMutationIds.contains(depId),
        );
        if (hasUnresolvedDependencies) {
          continue;
        }

        // Jittered exponential backoff check: base 1s * 2^retryCount, capped at 30s
        if (!force && mutation.lastAttemptAt != null && mutation.retryCount > 0) {
          final backoffSeconds = min(30, pow(2, mutation.retryCount).toInt());
          final nextAllowed = mutation.lastAttemptAt!.add(Duration(seconds: backoffSeconds));
          if (now.isBefore(nextAllowed)) {
            if (tId != null) blockedTripIds.add(tId);
            continue; // Skip this item until backoff period passes
          }
        }

        try {
          await _executeMutation(apiClient, mutation);
          completedMutationIds.add(mutation.id);
          await removeMutation(mutation.id);

          // If this was a trip lifecycle update to completed, ensure local storage reflects completed state
          if (mutation.type == MutationType.updateTripLifecycle && tId != null) {
            final targetLifecycle = mutation.payload['lifecycleState'] as String?;
            if (targetLifecycle == 'completed' || targetLifecycle == 'settled') {
              _promoteLocalTripLifecycle(tId, targetLifecycle!);
            }
          }
        } on NetworkException catch (_) {
          // Increment retry count and back off
          await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
          if (tId != null) blockedTripIds.add(tId);
          _setStatus(SyncStatus.offline);
          break; // Break loop and retry later when connection returns
        } on ApiException catch (e) {
          // If server rejects with 4xx unrecoverable client error, drop mutation to unblock queue
          debugPrint('[SyncService] Client error ${e.statusCode} for mutation ${mutation.id}: ${e.message}');
          completedMutationIds.add(mutation.id);
          await removeMutation(mutation.id);
        } catch (e) {
          debugPrint('[SyncService] Unexpected error on mutation ${mutation.id}: $e');
          await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
          if (tId != null) blockedTripIds.add(tId);
          _setStatus(SyncStatus.error);
          break;
        }
      }

      final remaining = getPendingMutations();
      if (remaining.isEmpty) {
        _setStatus(SyncStatus.synced);
      } else if (_currentStatus != SyncStatus.offline && _currentStatus != SyncStatus.error) {
        _setStatus(SyncStatus.pending);
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _promoteLocalTripLifecycle(String tripId, String lifecycleState) {
    try {
      final trips = _storage.getSavedTrips();
      final idx = trips.indexWhere((t) => t['id'] == tripId);
      if (idx != -1) {
        trips[idx]['lifecycleState'] = lifecycleState;
        trips[idx]['updatedAt'] = DateTime.now().toIso8601String();
        _storage.saveTrips(trips);
      }
    } catch (e) {
      debugPrint('[SyncService] Notice updating local trip lifecycle: $e');
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
      case MutationType.confirmTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = mutation.payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/confirm', body: mutation.payload);
        break;
      case MutationType.disputeTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = mutation.payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/dispute', body: mutation.payload);
        break;
      case MutationType.submitSettlementProof:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = mutation.payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/proof', body: mutation.payload);
        break;
    }
  }

  StreamSubscription? _realtimeSubscription;

  /// Attaches a realtime client to automatically trigger local queue flush when sync is requested.
  void attachRealtimeClient(RealtimeClient realtimeClient, {ApiClient? apiClient}) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = realtimeClient.events.listen((event) {
      if (event.type == 'trip_sync_requested') {
        if (apiClient != null) {
          flushQueue(apiClient, force: true);
        }
      }
    });
  }

  void dispose() {
    _realtimeSubscription?.cancel();
    _statusController.close();
  }
}

