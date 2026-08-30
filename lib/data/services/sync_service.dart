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

enum SyncState {
  localPending,
  p2pShared,
  serverPending,
  serverAcked,
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
  final SyncState syncState;
  final String? originDeviceId;

  SyncMutation({
    required this.id,
    String? idempotencyKey,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.dependsOn = const [],
    this.syncState = SyncState.localPending,
    this.originDeviceId,
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
    'syncState': syncState.name,
    'originDeviceId': originDeviceId,
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
    syncState: SyncState.values.firstWhere(
      (e) => e.name == json['syncState'],
      orElse: () => SyncState.localPending,
    ),
    originDeviceId: json['originDeviceId'] as String?,
  );

  SyncMutation copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    List<String>? dependsOn,
    SyncState? syncState,
    String? originDeviceId,
  }) => SyncMutation(
    id: id,
    idempotencyKey: idempotencyKey,
    type: type,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    dependsOn: dependsOn ?? this.dependsOn,
    syncState: syncState ?? this.syncState,
    originDeviceId: originDeviceId ?? this.originDeviceId,
  );
}

/// Offline-first synchronization queue service.
/// Enqueues user mutations when offline, manages P2P operation exchanges,
/// and reconciles operations with the server with jittered backoff.
class SyncService {
  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();
  bool _isProcessing = false;
  SyncStatus _currentStatus = SyncStatus.synced;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  StreamSubscription? _realtimeSubscription;

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
      syncState: SyncState.localPending,
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

  Future<void> markMutationP2PShared(String id) async {
    final queue = getPendingMutations();
    final idx = queue.indexWhere((m) => m.id == id);
    if (idx != -1) {
      queue[idx] = queue[idx].copyWith(syncState: SyncState.p2pShared);
      await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    }
  }

  /// Applies an operation received via P2P locally and stores it in the sync queue as P2P_SHARED.
  /// Preserves the exact same unique operation_id for eventual server reconciliation.
  Future<bool> applyRemoteP2PMutation(SyncMutation mutation, LocalStorageService storage) async {
    // Deduplication check
    final queue = getPendingMutations();
    if (queue.any((m) => m.id == mutation.id) || storage.isP2POperationProcessed(mutation.id)) {
      return false; // Already present or applied
    }

    final tripId = mutation.tripId;
    if (tripId == null) return false;

    // Apply domain mutation locally to local storage
    try {
      if (mutation.type == MutationType.addExpense || mutation.type == MutationType.updateExpense) {
        final existingExpenses = storage.getSavedExpenses(tripId);
        final expenseJson = Map<String, dynamic>.from(mutation.payload);
        final expId = expenseJson['id'] as String?;

        if (expId != null) {
          final idx = existingExpenses.indexWhere((e) => e['id'] == expId);
          if (idx != -1) {
            existingExpenses[idx] = expenseJson;
          } else {
            existingExpenses.add(expenseJson);
          }
          await storage.saveExpenses(tripId, existingExpenses);
        }
      } else if (mutation.type == MutationType.deleteExpense) {
        final existingExpenses = storage.getSavedExpenses(tripId);
        final expId = mutation.payload['id'] as String? ?? mutation.payload['expenseId'] as String?;
        if (expId != null) {
          existingExpenses.removeWhere((e) => e['id'] == expId);
          await storage.saveExpenses(tripId, existingExpenses);
        }
      } else if (mutation.type == MutationType.updateTripLifecycle) {
        final targetLifecycle = mutation.payload['lifecycleState'] as String?;
        if (targetLifecycle != null) {
          _promoteLocalTripLifecycle(tripId, targetLifecycle);
        }
      }

      // Enqueue in local mutation queue as P2P_SHARED with SAME operation_id
      final p2pMutation = mutation.copyWith(syncState: SyncState.p2pShared);
      queue.add(p2pMutation);
      await storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
      _setStatus(SyncStatus.pending);
      return true;
    } catch (e) {
      debugPrint('[SyncService] Failed to apply remote P2P mutation ${mutation.id}: $e');
      return false;
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

  /// Batch reconciles all pending mutations for a trip against the authoritative server endpoint.
  Future<int> syncTripBatchWithServer(ApiClient apiClient, String tripId) async {
    final tripMutations = getPendingMutationsForTrip(tripId);
    if (tripMutations.isEmpty) return 0;

    try {
      final res = await apiClient.post(
        '/trips/$tripId/sync-operations',
        body: {
          'operations': tripMutations.map((m) => m.toJson()).toList(),
        },
      );

      final data = res is Map<String, dynamic> && res.containsKey('data')
          ? res['data'] as Map<String, dynamic>
          : (res is Map<String, dynamic> ? res : <String, dynamic>{});

      final results = data['results'] as List<dynamic>? ?? [];
      int ackedCount = 0;

      for (final r in results) {
        if (r is Map<String, dynamic>) {
          final opId = r['operationId'] as String?;
          final status = r['status'] as String?;
          if (opId != null && (status == 'APPLIED' || status == 'ALREADY_PROCESSED')) {
            await removeMutation(opId);
            ackedCount++;
          }
        }
      }

      // Update local storage trip snapshot if returned
      if (data.containsKey('trip') && data['trip'] is Map<String, dynamic>) {
        final serverTrip = data['trip'] as Map<String, dynamic>;
        final trips = _storage.getSavedTrips();
        final idx = trips.indexWhere((t) => t['id'] == tripId);
        if (idx != -1) {
          trips[idx] = serverTrip;
        } else {
          trips.add(serverTrip);
        }
        await _storage.saveTrips(trips);
      }

      return ackedCount;
    } catch (e) {
      debugPrint('[SyncService] Batch sync notice for trip $tripId: $e');
      return 0;
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

      final blockedTripIds = <String>{};
      final completedMutationIds = <String>{};

      for (final mutation in queue) {
        final tId = mutation.tripId;

        // If trip is blocked due to prior failure in this cycle, skip
        if (tId != null && blockedTripIds.contains(tId)) {
          continue;
        }

        // Dependency check
        final pendingIds = queue.map((m) => m.id).toSet();
        final hasUnresolvedDependencies = mutation.dependsOn.any(
          (depId) => pendingIds.contains(depId) && !completedMutationIds.contains(depId),
        );
        if (hasUnresolvedDependencies) {
          continue;
        }

        // Jittered exponential backoff check
        if (!force && mutation.lastAttemptAt != null && mutation.retryCount > 0) {
          final backoffSeconds = min(30, pow(2, mutation.retryCount).toInt());
          final nextAllowed = mutation.lastAttemptAt!.add(Duration(seconds: backoffSeconds));
          if (now.isBefore(nextAllowed)) {
            if (tId != null) blockedTripIds.add(tId);
            continue;
          }
        }

        try {
          await _executeMutation(apiClient, mutation);
          completedMutationIds.add(mutation.id);
          await removeMutation(mutation.id);

          if (mutation.type == MutationType.updateTripLifecycle && tId != null) {
            final targetLifecycle = mutation.payload['lifecycleState'] as String?;
            if (targetLifecycle == 'completed' || targetLifecycle == 'settled') {
              _promoteLocalTripLifecycle(tId, targetLifecycle!);
            }
          }
        } on NetworkException catch (_) {
          await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
          if (tId != null) blockedTripIds.add(tId);
          _setStatus(SyncStatus.offline);
          break;
        } on ApiException catch (e) {
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

  void _promoteLocalTripLifecycle(String tripId, String targetLifecycle) {
    try {
      final trips = _storage.getSavedTrips();
      final idx = trips.indexWhere((t) => t['id'] == tripId);
      if (idx != -1) {
        trips[idx] = {
          ...trips[idx],
          'lifecycleState': targetLifecycle,
          'completedAt': targetLifecycle == 'completed' || targetLifecycle == 'settled'
              ? (trips[idx]['completedAt'] ?? DateTime.now().toIso8601String())
              : trips[idx]['completedAt'],
        };
        _storage.saveTrips(trips);
      }
    } catch (_) {}
  }

  Future<void> _executeMutation(ApiClient apiClient, SyncMutation mutation) async {
    final payload = mutation.payload;

    switch (mutation.type) {
      case MutationType.createTrip:
        await apiClient.post('/trips', body: payload);
        break;

      case MutationType.joinTrip:
        await apiClient.post('/trips/join', body: payload);
        break;

      case MutationType.updateTripLifecycle:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.patch('/trips/$tripId/lifecycle', body: payload);
        break;

      case MutationType.addExpense:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.post('/trips/$tripId/expenses', body: payload);
        break;

      case MutationType.updateExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = payload['id'] as String? ?? payload['expenseId'] as String;
        await apiClient.put('/trips/$tripId/expenses/$expenseId', body: payload);
        break;

      case MutationType.deleteExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = payload['id'] as String? ?? payload['expenseId'] as String;
        await apiClient.delete('/trips/$tripId/expenses/$expenseId');
        break;

      case MutationType.createPersonalExpense:
        await apiClient.post('/personal/expenses', body: payload);
        break;

      case MutationType.updatePersonalExpense:
        final expenseId = payload['id'] as String? ?? payload['expenseId'] as String;
        await apiClient.put('/personal/expenses/$expenseId', body: payload);
        break;

      case MutationType.deletePersonalExpense:
        final expenseId = payload['id'] as String? ?? payload['expenseId'] as String;
        await apiClient.delete('/personal/expenses/$expenseId');
        break;

      case MutationType.createPersonalDebt:
        await apiClient.post('/personal/debts', body: payload);
        break;

      case MutationType.recordPersonalRepayment:
        final debtId = payload['debtId'] as String? ?? payload['id'] as String;
        await apiClient.post('/personal/debts/$debtId/repayments', body: payload);
        break;

      case MutationType.deletePersonalDebt:
        final debtId = payload['debtId'] as String? ?? payload['id'] as String;
        await apiClient.delete('/personal/debts/$debtId');
        break;

      case MutationType.setPersonalBudget:
        final category = payload['category'] as String;
        await apiClient.post('/personal/budgets/$category', body: payload);
        break;

      case MutationType.createJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentPayload = mutation.payload.containsKey('moment')
            ? mutation.payload['moment'] as Map<String, dynamic>
            : payload;
        await apiClient.post('/trips/$tripId/moments', body: momentPayload);
        break;

      case MutationType.deleteJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentId = payload['id'] as String? ?? payload['momentId'] as String;
        await apiClient.delete('/trips/$tripId/moments/$momentId');
        break;

      case MutationType.recordTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.post('/trips/$tripId/settlements', body: payload);
        break;

      case MutationType.confirmTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = payload['id'] as String? ?? payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/confirm', body: payload);
        break;

      case MutationType.disputeTripSettlement:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = payload['id'] as String? ?? payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/dispute', body: payload);
        break;

      case MutationType.submitSettlementProof:
        final tripId = mutation.payload['tripId'] as String;
        final settlementId = payload['id'] as String? ?? payload['settlementId'] as String;
        await apiClient.post('/trips/$tripId/settlements/$settlementId/proof', body: payload);
        break;
    }
  }

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
