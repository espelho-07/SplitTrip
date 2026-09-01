import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/models/expense.dart';
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
  updatePersonalDebt,
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
  failed,
}

enum SyncSourceType {
  cloud,
  nearbyPeer,
  local,
}

class SyncSourceResult {
  final String name;
  final SyncSourceType type;
  final String status; // 'synced', 'failed', 'offline', 'up_to_date'
  final int changesSent;
  final int changesReceived;
  final String? errorMessage;
  final bool isSuccess;

  const SyncSourceResult({
    required this.name,
    required this.type,
    required this.status,
    this.changesSent = 0,
    this.changesReceived = 0,
    this.errorMessage,
    required this.isSuccess,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'status': status,
    'changesSent': changesSent,
    'changesReceived': changesReceived,
    'errorMessage': errorMessage,
    'isSuccess': isSuccess,
  };
}

class TripSyncReport {
  final String tripId;
  final DateTime timestamp;
  final List<SyncSourceResult> sources;
  final int totalChangesSent;
  final int totalChangesReceived;
  final int pendingChangesCount;
  final bool isFullySynced;
  final String? errorMessage;

  const TripSyncReport({
    required this.tripId,
    required this.timestamp,
    required this.sources,
    required this.totalChangesSent,
    required this.totalChangesReceived,
    required this.pendingChangesCount,
    required this.isFullySynced,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'timestamp': timestamp.toIso8601String(),
    'sources': sources.map((s) => s.toJson()).toList(),
    'totalChangesSent': totalChangesSent,
    'totalChangesReceived': totalChangesReceived,
    'pendingChangesCount': pendingChangesCount,
    'isFullySynced': isFullySynced,
    'errorMessage': errorMessage,
  };
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
  final String? lastError;
  final int version;

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
    this.lastError,
    this.version = 1,
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

  /// Returns the entity ID associated with this mutation (e.g. expense ID, debt ID).
  String? get entityId {
    if (payload.containsKey('id') && payload['id'] != null) {
      return payload['id'] as String;
    }
    if (payload.containsKey('expenseId') && payload['expenseId'] != null) {
      return payload['expenseId'] as String;
    }
    if (payload.containsKey('debtId') && payload['debtId'] != null) {
      return payload['debtId'] as String;
    }
    if (payload.containsKey('settlementId') && payload['settlementId'] != null) {
      return payload['settlementId'] as String;
    }
    if (payload.containsKey('momentId') && payload['momentId'] != null) {
      return payload['momentId'] as String;
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
    'lastError': lastError,
    'version': version,
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
    lastError: json['lastError'] as String?,
    version: json['version'] as int? ?? 1,
  );

  SyncMutation copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    List<String>? dependsOn,
    SyncState? syncState,
    String? originDeviceId,
    String? lastError,
    int? version,
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
    lastError: lastError ?? this.lastError,
    version: version ?? this.version,
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
      originDeviceId: _storage.getDeviceId(),
    );

    final queue = getPendingMutations();
    queue.add(mutation);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    _setStatus(SyncStatus.pending);

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

  /// Applies a mutation received from a nearby peer device or cloud delta idempotently.
  /// Preserves the EXACT original operation ID and updates local persistent cache.
  Future<bool> applyRemoteP2PMutation(SyncMutation mutation, LocalStorageService storage) async {
    try {
      // 1. Strict Idempotency & Replay Protection
      if (storage.isP2POperationProcessed(mutation.id)) {
        return false;
      }

      final queue = getPendingMutations();
      final duplicateInQueue = queue.any((m) => m.id == mutation.id);
      if (duplicateInQueue) {
        await storage.markP2POperationProcessed(mutation.id);
        return false;
      }

      final payload = mutation.payload;
      final tripId = mutation.tripId;

      // 2. Apply Domain State Locally
      switch (mutation.type) {
        case MutationType.addExpense:
          if (tripId != null) {
            final expenses = storage.getSavedExpenses(tripId);
            final expId = payload['id'] as String? ?? mutation.id;
            expenses.removeWhere((e) => e['id'] == expId);
            expenses.insert(0, payload);
            await storage.saveExpenses(tripId, expenses);
          }
          break;

        case MutationType.updateExpense:
          if (tripId != null) {
            final expenses = storage.getSavedExpenses(tripId);
            final expId = payload['id'] as String? ?? payload['expenseId'] as String?;
            if (expId != null) {
              final idx = expenses.indexWhere((e) => e['id'] == expId);
              if (idx != -1) {
                expenses[idx] = payload;
              } else {
                expenses.insert(0, payload);
              }
              await storage.saveExpenses(tripId, expenses);
            }
          }
          break;

        case MutationType.deleteExpense:
          if (tripId != null) {
            final expenses = storage.getSavedExpenses(tripId);
            final expId = payload['id'] as String? ?? payload['expenseId'] as String?;
            if (expId != null) {
              expenses.removeWhere((e) => e['id'] == expId);
              await storage.saveExpenses(tripId, expenses);
            }
          }
          break;

        case MutationType.recordTripSettlement:
          if (tripId != null) {
            final settlements = storage.getSavedTripSettlements(tripId);
            final stlId = payload['id'] as String? ?? mutation.id;
            settlements.removeWhere((s) => s['id'] == stlId);
            settlements.insert(0, payload);
            await storage.saveTripSettlements(tripId, settlements);
          }
          break;

        case MutationType.confirmTripSettlement:
        case MutationType.disputeTripSettlement:
        case MutationType.submitSettlementProof:
          if (tripId != null) {
            final settlements = storage.getSavedTripSettlements(tripId);
            final stlId = payload['id'] as String? ?? payload['settlementId'] as String?;
            if (stlId != null) {
              final idx = settlements.indexWhere((s) => s['id'] == stlId);
              if (idx != -1) {
                settlements[idx] = {
                  ...settlements[idx],
                  ...payload,
                };
                await storage.saveTripSettlements(tripId, settlements);
              }
            }
          }
          break;

        case MutationType.createPersonalDebt:
          final debts = storage.getPersonalDebts();
          final debtId = payload['id'] as String? ?? mutation.id;
          debts.removeWhere((d) => d['id'] == debtId);
          debts.insert(0, payload);
          await storage.savePersonalDebts(debts);
          break;

        case MutationType.recordPersonalRepayment:
          final debts = storage.getPersonalDebts();
          final debtId = payload['debtId'] as String? ?? payload['id'] as String?;
          if (debtId != null) {
            final idx = debts.indexWhere((d) => d['id'] == debtId);
            if (idx != -1) {
              final repayments = List<Map<String, dynamic>>.from(debts[idx]['repayments'] ?? []);
              repayments.insert(0, payload);
              debts[idx]['repayments'] = repayments;
              await storage.savePersonalDebts(debts);
            }
          }
          break;

        case MutationType.createJourneyMoment:
          if (tripId != null) {
            final moments = storage.getSavedJourneyMoments(tripId);
            final momentId = payload['id'] as String? ?? mutation.id;
            moments.removeWhere((m) => m['id'] == momentId);
            moments.insert(0, payload);
            await storage.saveJourneyMoments(tripId, moments);
          }
          break;

        case MutationType.deleteJourneyMoment:
          if (tripId != null) {
            final moments = storage.getSavedJourneyMoments(tripId);
            final momentId = payload['id'] as String? ?? payload['momentId'] as String?;
            if (momentId != null) {
              moments.removeWhere((m) => m['id'] == momentId);
              await storage.saveJourneyMoments(tripId, moments);
            }
          }
          break;

        default:
          break;
      }

      // Mark operation processed locally to avoid replay
      await storage.markP2POperationProcessed(mutation.id);

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

  Future<void> _updateMutationAttempt(
    String id,
    int retryCount, {
    String? errorMessage,
    SyncState syncState = SyncState.localPending,
  }) async {
    final queue = getPendingMutations();
    final idx = queue.indexWhere((m) => m.id == id);
    if (idx != -1) {
      queue[idx] = queue[idx].copyWith(
        retryCount: retryCount,
        lastAttemptAt: DateTime.now(),
        lastError: errorMessage,
        syncState: syncState,
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
          } else if (opId != null && status == 'FAILED') {
            await _updateMutationAttempt(
              opId,
              1,
              errorMessage: r['errorMessage'] as String? ?? 'Operation rejected by server',
              syncState: SyncState.failed,
            );
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

  /// Comprehensive multi-source canonical reconciliation for a single trip.
  /// Reconciles both Cloud (API/Supabase) and nearby P2P devices, returning a transparent source-by-source report.
  Future<TripSyncReport> reconcileTripWithAllSources({
    required String tripId,
    ApiClient? apiClient,
    dynamic p2pService, // P2PSyncService instance if available
  }) async {
    final sources = <SyncSourceResult>[];
    int totalSent = 0;
    int totalReceived = 0;

    // ── 1. Cloud (Server / Supabase) Reconciliation ────────────────────────
    if (apiClient != null) {
      try {
        final sentCount = await syncTripBatchWithServer(apiClient, tripId);
        totalSent += sentCount;

        // Fetch remote expenses to pull down changes created by other members
        int receivedCount = 0;
        try {
          final res = await apiClient.get('/trips/$tripId/expenses');
          if (res is List) {
            final serverExpenses = res.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList();
            final localExpensesRaw = _storage.getSavedExpenses(tripId);
            final localExpenses = localExpensesRaw.map((j) => Expense.fromJson(j)).toList();

            final pendingAfterBatch = getPendingMutationsForTrip(tripId);
            final pendingDeletedIds = pendingAfterBatch
                .where((m) => m.type == MutationType.deleteExpense)
                .map((m) => (m.payload['id'] ?? m.payload['expenseId']).toString())
                .toSet();
            final pendingUpdateIds = pendingAfterBatch
                .where((m) => m.type == MutationType.updateExpense)
                .map((m) => (m.payload['id'] ?? m.payload['expenseId']).toString())
                .toSet();

            final mergedMap = <String, Expense>{};
            for (final local in localExpenses) {
              if (!local.isDeleted && !pendingDeletedIds.contains(local.id)) {
                mergedMap[local.id] = local;
              }
            }

            for (final server in serverExpenses) {
              if (pendingDeletedIds.contains(server.id)) {
                continue;
              }
              if (pendingUpdateIds.contains(server.id)) {
                // Keep local pending edit unless server is strictly newer
                final localExisting = mergedMap[server.id];
                if (localExisting != null && localExisting.updatedAt.isAfter(server.updatedAt)) {
                  continue;
                }
              }
              if (!server.isDeleted) {
                if (!mergedMap.containsKey(server.id)) {
                  receivedCount++;
                }
                mergedMap[server.id] = server;
              } else {
                mergedMap.remove(server.id);
              }
            }

            final mergedList = mergedMap.values.toList();
            mergedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            await _storage.saveExpenses(tripId, mergedList.map((e) => e.toJson()).toList());
          }
        } catch (_) {}

        totalReceived += receivedCount;
        sources.add(SyncSourceResult(
          name: 'Kith Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'synced',
          changesSent: sentCount,
          changesReceived: receivedCount,
          isSuccess: true,
        ));
      } on NetworkException catch (_) {
        sources.add(const SyncSourceResult(
          name: 'Kith Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'offline',
          errorMessage: 'No internet connection',
          isSuccess: false,
        ));
      } catch (e) {
        sources.add(SyncSourceResult(
          name: 'Kith Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'failed',
          errorMessage: e.toString(),
          isSuccess: false,
        ));
      }
    }

    // ── 2. Nearby P2P Peers Reconciliation ──────────────────────────────────
    if (p2pService != null) {
      try {
        final activePeers = p2pService.activePeers as List<dynamic>? ?? [];
        for (final peer in activePeers) {
          final peerTripIds = (peer.sharedTripIds as List<String>?) ?? [];
          if (peerTripIds.contains(tripId)) {
            final p2pResult = await p2pService.syncWithPeer(peer);
            totalSent += p2pResult.operationsSent as int? ?? 0;
            totalReceived += p2pResult.operationsReceived as int? ?? 0;

            sources.add(SyncSourceResult(
              name: peer.displayName as String? ?? 'Nearby Friend',
              type: SyncSourceType.nearbyPeer,
              status: p2pResult.success ? 'synced' : 'failed',
              changesSent: p2pResult.operationsSent as int? ?? 0,
              changesReceived: p2pResult.operationsReceived as int? ?? 0,
              errorMessage: p2pResult.errorMessage as String?,
              isSuccess: p2pResult.success as bool? ?? false,
            ));
          }
        }
      } catch (e) {
        debugPrint('[SyncService] P2P reconciliation notice: $e');
      }
    }

    final remainingPending = getPendingCountForTrip(tripId);
    final isFullySynced = remainingPending == 0 && sources.every((s) => s.isSuccess);

    return TripSyncReport(
      tripId: tripId,
      timestamp: DateTime.now(),
      sources: sources,
      totalChangesSent: totalSent,
      totalChangesReceived: totalReceived,
      pendingChangesCount: remainingPending,
      isFullySynced: isFullySynced,
      errorMessage: sources.any((s) => !s.isSuccess)
          ? sources.firstWhere((s) => !s.isSuccess).errorMessage
          : null,
    );
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
          if (e.statusCode == 409) {
            // Already resolved conflict / duplicate -> acknowledge safely
            completedMutationIds.add(mutation.id);
            await removeMutation(mutation.id);
          } else {
            // Record failure reason and retry with backoff, NEVER silently drop financial mutations!
            await _updateMutationAttempt(
              mutation.id,
              mutation.retryCount + 1,
              errorMessage: e.message,
              syncState: SyncState.failed,
            );
            if (tId != null) blockedTripIds.add(tId);
          }
        } catch (e) {
          debugPrint('[SyncService] Unexpected error on mutation ${mutation.id}: $e');
          await _updateMutationAttempt(
            mutation.id,
            mutation.retryCount + 1,
            errorMessage: e.toString(),
            syncState: SyncState.failed,
          );
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

      case MutationType.updatePersonalDebt:
        final debtId = payload['debtId'] as String? ?? payload['id'] as String;
        await apiClient.put('/personal/debts/$debtId', body: payload);
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
