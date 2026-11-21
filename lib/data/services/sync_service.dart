import '../../core/services/supabase_cloud_sync.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/engine/expense_merge.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';
import 'local_storage_service.dart';

enum MutationType {
  createTrip,
  joinTrip,
  addMember,
  renameMember,
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

enum SyncStatus { synced, syncing, pending, offline, reconnecting, error }

enum SyncState { localPending, p2pShared, serverPending, serverAcked, failed, quarantined }

enum SyncOperationOutcome { success, partial, failed, skipped }

enum SyncSourceType { cloud, nearbyPeer, local }

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
  final SyncOperationOutcome outcome;

  const TripSyncReport({
    required this.tripId,
    required this.timestamp,
    required this.sources,
    required this.totalChangesSent,
    required this.totalChangesReceived,
    required this.pendingChangesCount,
    required this.isFullySynced,
    this.errorMessage,
    this.outcome = SyncOperationOutcome.success,
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
    'outcome': outcome.name,
  };
}

class SyncMutation {
  final String id;
  final String idempotencyKey;
  final String? userId;
  final String payloadChecksum;
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
  final int hopCount;
  final List<String> forwardedBy;
  final SyncOperationOutcome? outcome;

  SyncMutation({
    required this.id,
    String? idempotencyKey,
    this.userId,
    String? payloadChecksum,
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
    this.hopCount = 0,
    this.forwardedBy = const [],
    this.outcome,
  }) : idempotencyKey = idempotencyKey ?? id,
       payloadChecksum = payloadChecksum ?? computePayloadChecksum(payload);

  /// Computes a deterministic SHA-256 hash of the canonical JSON representation of [payload].
  static String computePayloadChecksum(Map<String, dynamic> payload) {
    final canonical = _canonicalJson(payload);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _canonicalJson(dynamic obj) {
    if (obj is Map) {
      final sortedKeys = obj.keys.map((k) => k.toString()).toList()..sort();
      final parts = sortedKeys.map((k) => '"$k":${_canonicalJson(obj[k])}');
      return '{${parts.join(',')}}';
    } else if (obj is List) {
      final parts = obj.map((item) => _canonicalJson(item));
      return '[${parts.join(',')}]';
    } else if (obj is String) {
      return jsonEncode(obj);
    } else if (obj is num || obj is bool) {
      return obj.toString();
    } else if (obj == null) {
      return 'null';
    } else {
      return jsonEncode(obj.toString());
    }
  }

  /// Returns the tripId associated with this mutation, if applicable.
  String? get tripId {
    if (payload.containsKey('tripId') && payload['tripId'] != null) {
      return payload['tripId'] as String;
    }
    if (type == MutationType.createTrip &&
        payload.containsKey('id') &&
        payload['id'] != null) {
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
    if (payload.containsKey('settlementId') &&
        payload['settlementId'] != null) {
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
    'userId': userId,
    'payloadChecksum': payloadChecksum,
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
    'hopCount': hopCount,
    'forwardedBy': forwardedBy,
    'outcome': outcome?.name,
  };

  factory SyncMutation.fromJson(Map<String, dynamic> json) => SyncMutation(
    id: json['id'] as String,
    idempotencyKey: json['idempotencyKey'] as String? ?? json['id'] as String,
    userId: json['userId'] as String?,
    payloadChecksum: json['payloadChecksum'] as String?,
    type: MutationType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MutationType.addExpense,
    ),
    payload: json['payload'] is Map<String, dynamic>
        ? json['payload'] as Map<String, dynamic>
        : {},
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
    hopCount: json['hopCount'] as int? ?? 0,
    forwardedBy: json['forwardedBy'] is List
        ? (json['forwardedBy'] as List).map((e) => e.toString()).toList()
        : const [],
    outcome: json['outcome'] != null
        ? SyncOperationOutcome.values.firstWhere(
            (e) => e.name == json['outcome'],
            orElse: () => SyncOperationOutcome.success,
          )
        : null,
  );

  SyncMutation copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    List<String>? dependsOn,
    SyncState? syncState,
    String? originDeviceId,
    String? lastError,
    int? version,
    int? hopCount,
    List<String>? forwardedBy,
    SyncOperationOutcome? outcome,
    String? payloadChecksum,
    String? userId,
    Map<String, dynamic>? payload,
  }) => SyncMutation(
    id: id,
    idempotencyKey: idempotencyKey,
    userId: userId ?? this.userId,
    payloadChecksum: payloadChecksum ?? this.payloadChecksum,
    type: type,
    payload: payload ?? this.payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    dependsOn: dependsOn ?? this.dependsOn,
    syncState: syncState ?? this.syncState,
    originDeviceId: originDeviceId ?? this.originDeviceId,
    lastError: lastError ?? this.lastError,
    version: version ?? this.version,
    hopCount: hopCount ?? this.hopCount,
    forwardedBy: forwardedBy ?? this.forwardedBy,
    outcome: outcome ?? this.outcome,
  );
}

/// Offline-first synchronization queue service.
/// Enqueues user mutations when offline, manages P2P operation exchanges,
/// and reconciles operations with the server with jittered backoff.
class SyncService {
  final LocalStorageService _storage;
  final SupabaseCloudSync _cloudSync = SupabaseCloudSync();
  SupabaseCloudSync get cloudSync => _cloudSync;
  final Uuid _uuid = const Uuid();
  final Map<String, Completer<void>> _tripLocks = {};
  SyncStatus _currentStatus = SyncStatus.synced;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  StreamSubscription? _realtimeSubscription;
  Timer? _periodicSyncTimer;
  ApiClient? _registeredApiClient;
  bool _isSessionExpired = false;
  String? _lastErrorMessage;

  bool get isSessionExpired => _isSessionExpired;
  String? get lastErrorMessage => _lastErrorMessage;

  SyncService(this._storage) {
    _storage.addOnClearDataListener(() {
      // Refresh status without destroying pending mutations in SQLite outbox
      _setStatus(SyncStatus.synced);
    });
  }

  /// Starts continuous periodic background synchronization to ensure offline
  /// mutations and pending deltas are automatically pushed to the cloud in the background.
  void startPeriodicSync(
    ApiClient apiClient, {
    Duration interval = const Duration(seconds: 15),
  }) {
    _registeredApiClient = apiClient;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(interval, (_) {
      if (!isProcessing && getPendingMutations(includeQuarantined: false).isNotEmpty) {
        unawaited(flushQueue(_registeredApiClient!));
      }
    });
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  bool get isProcessing => _tripLocks.isNotEmpty;

  /// Coordinates per-trip synchronization mutexes.
  /// Guarantees that mutations and synchronizations on the same trip are serialized,
  /// while distinct trips synchronize in parallel without lock contention.
  Future<T> runWithTripLock<T>(
    String tripId,
    Future<T> Function() action,
  ) async {
    while (_tripLocks.containsKey(tripId)) {
      await _tripLocks[tripId]!.future;
    }
    final completer = Completer<void>();
    _tripLocks[tripId] = completer;
    try {
      return await action();
    } finally {
      _tripLocks.remove(tripId);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  int get pendingCount => getPendingMutations(includeQuarantined: false).length;
  int get pendingMutationCount => pendingCount;
  int get quarantinedCount => getQuarantinedMutations().length;
  List<SyncMutation> getQueue() => getPendingMutations(includeQuarantined: false);
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

  /// Returns all mutations in the local storage outbox table (including quarantined).
  List<SyncMutation> getAllMutations({String? userId}) {
    final raw = _storage.getMutationQueue(userId: userId);
    return raw.map((json) => SyncMutation.fromJson(json)).toList();
  }

  /// Returns actionable pending mutations. By default, quarantined mutations are excluded
  /// to prevent infinite retry loops and UI lockups.
  List<SyncMutation> getPendingMutations({String? userId, bool includeQuarantined = false}) {
    final all = getAllMutations(userId: userId);
    if (includeQuarantined) return all;
    return all.where((m) => m.syncState != SyncState.quarantined).toList();
  }

  /// Returns mutations that were quarantined due to unresolvable validation errors or exceeded retries.
  List<SyncMutation> getQuarantinedMutations({String? userId}) {
    return getAllMutations(userId: userId)
        .where((m) => m.syncState == SyncState.quarantined)
        .toList();
  }

  Future<void> clearQueue() async {
    await _storage.clearMutationQueue();
    _lastErrorMessage = null;
    _setStatus(SyncStatus.synced);
  }

  /// Clears only quarantined mutations from the outbox after user review.
  Future<void> clearQuarantinedMutations() async {
    final queue = getAllMutations();
    queue.removeWhere((m) => m.syncState == SyncState.quarantined);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    final remaining = queue.where((m) => m.syncState != SyncState.quarantined);
    if (remaining.isEmpty) {
      _lastErrorMessage = null;
      _setStatus(SyncStatus.synced);
    }
  }

  /// Purges all pending and quarantined mutations from local storage outbox.
  Future<void> clearAllPendingMutations() async {
    await clearQueue();
    _lastErrorMessage = null;
    _setStatus(SyncStatus.synced);
  }

  /// Resets quarantined mutations back to localPending for user-directed retry.
  Future<void> retryQuarantinedMutations(ApiClient apiClient) async {
    final queue = getAllMutations();
    bool updated = false;
    for (int i = 0; i < queue.length; i++) {
      if (queue[i].syncState == SyncState.quarantined) {
        queue[i] = queue[i].copyWith(
          syncState: SyncState.localPending,
          retryCount: 0,
          lastError: null,
          lastAttemptAt: null,
        );
        updated = true;
      }
    }
    if (updated) {
      await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
      _setStatus(SyncStatus.pending);
      await flushQueue(apiClient, force: true);
    }
  }

  /// Returns all pending mutations for a specific trip, excluding permanently quarantined operations.
  List<SyncMutation> getPendingMutationsForTrip(String tripId) {
    return getPendingMutations(includeQuarantined: false)
        .where((m) => m.tripId == tripId)
        .toList();
  }

  /// Returns the number of pending mutations for a specific trip.
  int getPendingCountForTrip(String tripId) {
    return getPendingMutationsForTrip(tripId).length;
  }

  /// Returns true if there are pending un-synced operations for a trip.
  bool hasPendingMutationsForTrip(String tripId) {
    return getPendingCountForTrip(tripId) > 0;
  }

  /// Reactively responds to network connectivity status changes detected by ApiClient or NetworkMonitor.
  void handleConnectivityChange(bool isOnline) {
    if (!isOnline) {
      if (_currentStatus != SyncStatus.offline) {
        _setStatus(SyncStatus.offline);
      }
    } else {
      if (_currentStatus == SyncStatus.offline || _currentStatus == SyncStatus.reconnecting) {
        final pending = getPendingMutations(includeQuarantined: false);
        if (pending.isNotEmpty) {
          _setStatus(SyncStatus.pending);
          if (_registeredApiClient != null && !isProcessing) {
            unawaited(flushQueue(_registeredApiClient!));
          }
        } else {
          final quarantined = getQuarantinedMutations();
          if (quarantined.isNotEmpty) {
            _setStatus(SyncStatus.error);
          } else {
            _setStatus(SyncStatus.synced);
          }
        }
      }
    }
  }

  Future<SyncMutation> enqueueMutation(
    MutationType type,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
    String? userId,
    List<String>? dependsOn,
    ApiClient? backgroundApiClient,
  }) async {
    final mutationId = _uuid.v4();
    final effectiveUserId = userId ??
        _storage.getSavedUser()?['id'] as String? ??
        _storage.getSavedUser()?['accountId'] as String?;
    final mutation = SyncMutation(
      id: mutationId,
      idempotencyKey: idempotencyKey ?? mutationId,
      userId: effectiveUserId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
      dependsOn: dependsOn ?? const [],
      syncState: SyncState.localPending,
      originDeviceId: _storage.getDeviceId(),
    );

    final queue = getAllMutations();
    queue.add(mutation);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    _setStatus(SyncStatus.pending);

    final client = backgroundApiClient ?? _registeredApiClient;
    if (client != null) {
      unawaited(flushQueue(client));
    }

    return mutation;
  }

  Future<void> removeMutation(String id) async {
    final queue = getAllMutations();
    queue.removeWhere((m) => m.id == id);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    final actionable = queue.where((m) => m.syncState != SyncState.quarantined);
    if (actionable.isEmpty) {
      if (queue.isEmpty) {
        _lastErrorMessage = null;
        _setStatus(SyncStatus.synced);
      } else {
        _setStatus(SyncStatus.error);
        _lastErrorMessage = '${queue.length} change${queue.length > 1 ? "s" : ""} could not be synced.';
      }
    }
  }

  Future<void> markMutationP2PShared(String id) async {
    final queue = getAllMutations();
    final idx = queue.indexWhere((m) => m.id == id);
    if (idx != -1) {
      queue[idx] = queue[idx].copyWith(syncState: SyncState.p2pShared);
      await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
    }
  }

  /// Applies a mutation received from a nearby peer device or cloud delta idempotently.
  /// Preserves the EXACT original operation ID and updates local persistent cache.
  Future<bool> applyRemoteP2PMutation(
    SyncMutation mutation,
    LocalStorageService storage,
  ) async {
    try {
      final myDeviceId = storage.getDeviceId();

      // Loop Prevention: Drop packets that have already traversed this node
      if (mutation.forwardedBy.contains(myDeviceId) ||
          mutation.originDeviceId == myDeviceId) {
        return false;
      }

      // Hop Count Limit: Drop packets exceeding mesh boundary (max 5 hops)
      if (mutation.hopCount >= 5) {
        debugPrint(
          '[SyncService] Dropping mutation ${mutation.id}: max hop count (5) reached.',
        );
        return false;
      }

      // Strict Idempotency & Payload Tamper Verification
      final opStatus = storage.checkOperationStatus(
        mutation.id,
        mutation.payloadChecksum,
      );
      if (opStatus.isMismatch) {
        debugPrint(
          '[SyncService] WARNING: Payload mismatch detected for reused operation ID ${mutation.id}!',
        );
        return false;
      }
      if (opStatus.isProcessed) {
        return false;
      }

      final queue = getPendingMutations();
      final duplicateInQueue = queue.any((m) => m.id == mutation.id);
      if (duplicateInQueue) {
        await storage.recordProcessedOperation(
          ProcessedOperationRecord(
            operationId: mutation.id,
            payloadChecksum: mutation.payloadChecksum,
            processedAt: DateTime.now(),
            source: 'p2p',
          ),
        );
        return false;
      }

      final payload = mutation.payload;
      final tripId = mutation.tripId;

      // 2. Apply Domain State Locally
      switch (mutation.type) {
        case MutationType.addExpense:
          if (tripId != null) {
            final expId = payload['id'] as String? ?? mutation.id;
            // Tombstone check: Never resurrect deleted expenses
            if (storage.isExpenseTombstoned(tripId, expId)) {
              await storage.markP2POperationProcessed(mutation.id);
              return false;
            }

            final expenses = storage.getSavedExpenses(tripId);
            final idx = expenses.indexWhere((e) => e['id'] == expId);
            if (idx != -1) {
              // Existing expense: LWW reconciliation by timestamp
              final localUpdated =
                  DateTime.tryParse(
                    expenses[idx]['updatedAt']?.toString() ?? '',
                  ) ??
                  DateTime.tryParse(
                    expenses[idx]['createdAt']?.toString() ?? '',
                  ) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final remoteUpdated =
                  DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
                  DateTime.tryParse(payload['createdAt']?.toString() ?? '') ??
                  mutation.createdAt;

              if (remoteUpdated.isAfter(localUpdated)) {
                expenses[idx] = {...expenses[idx], ...payload};
                await storage.saveExpenses(tripId, expenses);
              }
            } else {
              expenses.insert(0, payload);
              await storage.saveExpenses(tripId, expenses);
            }
          }
          break;

        case MutationType.updateExpense:
          if (tripId != null) {
            final expId =
                payload['id'] as String? ?? payload['expenseId'] as String?;
            if (expId != null) {
              // Tombstone check: Never resurrect deleted expenses
              if (storage.isExpenseTombstoned(tripId, expId)) {
                await storage.markP2POperationProcessed(mutation.id);
                return false;
              }

              final expenses = storage.getSavedExpenses(tripId);
              final idx = expenses.indexWhere((e) => e['id'] == expId);
              if (idx != -1) {
                final localExpense = Expense.fromJson(expenses[idx]);
                final incomingExpense = Expense.fromJson(payload);
                final Expense? baseExpense = payload['baseExpense'] != null
                    ? Expense.fromJson(payload['baseExpense'] as Map<String, dynamic>)
                    : null;

                final mergedExpense = ExpenseMergeEngine.merge3Way(
                  local: localExpense,
                  remote: incomingExpense,
                  base: baseExpense,
                );

                expenses[idx] = mergedExpense.toJson();
                await storage.saveExpenses(tripId, expenses);
              } else {
                expenses.insert(0, payload);
                await storage.saveExpenses(tripId, expenses);
              }
            }
          }
          break;

        case MutationType.deleteExpense:
          if (tripId != null) {
            final expId =
                payload['id'] as String? ?? payload['expenseId'] as String?;
            if (expId != null) {
              await storage.markExpenseTombstoned(
                tripId,
                expId,
                mutation.createdAt,
              );
              final expenses = storage.getSavedExpenses(tripId);
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
            final stlId =
                payload['id'] as String? ?? payload['settlementId'] as String?;
            if (stlId != null) {
              final idx = settlements.indexWhere((s) => s['id'] == stlId);
              if (idx != -1) {
                settlements[idx] = {...settlements[idx], ...payload};
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
          final debtId =
              payload['debtId'] as String? ?? payload['id'] as String?;
          if (debtId != null) {
            final idx = debts.indexWhere((d) => d['id'] == debtId);
            if (idx != -1) {
              final repayments = List<Map<String, dynamic>>.from(
                debts[idx]['repayments'] ?? [],
              );
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
            final momentId =
                payload['id'] as String? ?? payload['momentId'] as String?;
            if (momentId != null) {
              moments.removeWhere((m) => m['id'] == momentId);
              await storage.saveJourneyMoments(tripId, moments);
            }
          }
          break;

        case MutationType.createTrip:
        case MutationType.joinTrip:
        case MutationType.updateTripLifecycle:
          final trips = storage.getSavedTrips();
          final tId =
              payload['id'] as String? ??
              payload['tripId'] as String? ??
              mutation.tripId;
          if (tId != null) {
            final idx = trips.indexWhere((t) => t['id'] == tId);
            if (idx != -1) {
              trips[idx] = {...trips[idx], ...payload};
            } else {
              trips.insert(0, payload);
            }
            await storage.saveTrips(trips);
          }
          break;

        default:
          break;
      }

      // Record in authoritative processed operations ledger
      await storage.recordProcessedOperation(
        ProcessedOperationRecord(
          operationId: mutation.id,
          payloadChecksum: mutation.payloadChecksum,
          processedAt: DateTime.now(),
          source: 'p2p',
        ),
      );

      // Store-and-Forward Replication:
      // Enqueue in local outbox with incremented hopCount and tagged forwardedBy
      // so this node can relay it to cloud and other peers
      final updatedForwardedBy = [...mutation.forwardedBy, myDeviceId];
      final p2pMutation = mutation.copyWith(
        syncState: SyncState.p2pShared,
        hopCount: mutation.hopCount + 1,
        forwardedBy: updatedForwardedBy,
      );
      queue.add(p2pMutation);
      await storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
      _setStatus(SyncStatus.pending);
      return true;
    } catch (e) {
      debugPrint(
        '[SyncService] Failed to apply remote P2P mutation ${mutation.id}: $e',
      );
      return false;
    }
  }

  Future<void> _updateMutationAttempt(
    String id,
    int retryCount, {
    String? errorMessage,
    SyncState syncState = SyncState.localPending,
  }) async {
    final queue = getAllMutations();
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
  Future<int> syncTripBatchWithServer(
    ApiClient apiClient,
    String tripId,
  ) async {
    final tripMutations = getPendingMutationsForTrip(tripId);
    if (tripMutations.isEmpty) return 0;

    try {
      final res = await apiClient.post(
        '/trips/$tripId/sync-operations',
        body: {'operations': tripMutations.map((m) => m.toJson()).toList()},
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
          if (opId != null &&
              (status == 'APPLIED' || status == 'ALREADY_PROCESSED')) {
            await removeMutation(opId);
            ackedCount++;
          } else if (opId != null && status == 'FAILED') {
            await _updateMutationAttempt(
              opId,
              1,
              errorMessage:
                  r['errorMessage'] as String? ??
                  'Operation rejected by server',
              syncState: SyncState.failed,
            );
          }
        }
      }

      // Update local storage trip snapshot if returned
      if (data.containsKey('trip') && data['trip'] is Map<String, dynamic>) {
        final serverTrip = Trip.fromJson(data['trip'] as Map<String, dynamic>);
        final trips = _storage.getSavedTrips();
        final idx = trips.indexWhere((t) => t['id'] == tripId);
        if (idx != -1) {
          final localTrip = Trip.fromJson(trips[idx]);
          final mergeResult = localTrip.mergeWithDetailed(serverTrip);
          trips[idx] = mergeResult.mergedTrip.toJson();
          if (mergeResult.memberIdMap.isNotEmpty) {
            await _storage.translateMemberIds(
              tripId: tripId,
              translationMap: mergeResult.memberIdMap,
            );
          }
        } else {
          trips.add(serverTrip.toJson());
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
            final serverExpenses = res
                .map((j) => Expense.fromJson(j as Map<String, dynamic>))
                .toList();
            final localExpensesRaw = _storage.getSavedExpenses(tripId);
            final localExpenses = localExpensesRaw
                .map((j) => Expense.fromJson(j))
                .toList();

            final pendingAfterBatch = getPendingMutationsForTrip(tripId);
            final pendingDeletedIds = pendingAfterBatch
                .where((m) => m.type == MutationType.deleteExpense)
                .map(
                  (m) => (m.payload['id'] ?? m.payload['expenseId']).toString(),
                )
                .toSet();
            final pendingUpdateIds = pendingAfterBatch
                .where((m) => m.type == MutationType.updateExpense)
                .map(
                  (m) => (m.payload['id'] ?? m.payload['expenseId']).toString(),
                )
                .toSet();
            final pendingBaseExpenses = <String, Expense>{};
            for (final m in pendingAfterBatch.where((m) => m.type == MutationType.updateExpense)) {
              final expId = (m.payload['id'] ?? m.payload['expenseId'])?.toString();
              if (expId != null && m.payload['baseExpense'] is Map<String, dynamic>) {
                try {
                  pendingBaseExpenses[expId] = Expense.fromJson(
                    m.payload['baseExpense'] as Map<String, dynamic>,
                  );
                } catch (_) {}
              }
            }

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
                // Reconcile non-conflicting field edits via 3-way merge
                final localExisting = mergedMap[server.id];
                if (localExisting != null) {
                  final baseExp = pendingBaseExpenses[server.id];
                  mergedMap[server.id] = ExpenseMergeEngine.merge3Way(
                    local: localExisting,
                    remote: server,
                    base: baseExp,
                  );
                  continue;
                }
              }
              if (!server.isDeleted) {
                if (!mergedMap.containsKey(server.id)) {
                  receivedCount++;
                  mergedMap[server.id] = server;
                } else {
                  final localExisting = mergedMap[server.id]!;
                  mergedMap[server.id] = ExpenseMergeEngine.merge3Way(
                    local: localExisting,
                    remote: server,
                  );
                }
              } else {
                mergedMap.remove(server.id);
              }
            }

            final mergedList = mergedMap.values.toList();
            mergedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            await _storage.saveExpenses(
              tripId,
              mergedList.map((e) => e.toJson()).toList(),
            );
          }
        } catch (_) {}

        totalReceived += receivedCount;
        sources.add(
          SyncSourceResult(
            name: 'Kith Cloud (Supabase)',
            type: SyncSourceType.cloud,
            status: 'synced',
            changesSent: sentCount,
            changesReceived: receivedCount,
            isSuccess: true,
          ),
        );
      } on NetworkException catch (_) {
        sources.add(
          const SyncSourceResult(
            name: 'Kith Cloud (Supabase)',
            type: SyncSourceType.cloud,
            status: 'offline',
            errorMessage: 'No internet connection',
            isSuccess: false,
          ),
        );
      } catch (e) {
        sources.add(
          SyncSourceResult(
            name: 'Kith Cloud (Supabase)',
            type: SyncSourceType.cloud,
            status: 'failed',
            errorMessage: e.toString(),
            isSuccess: false,
          ),
        );
      }
    } else {
      sources.add(
        const SyncSourceResult(
          name: 'Kith Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'offline',
          errorMessage: 'Device offline • Changes queued locally',
          isSuccess: false,
        ),
      );
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

            sources.add(
              SyncSourceResult(
                name: peer.displayName as String? ?? 'Nearby Friend',
                type: SyncSourceType.nearbyPeer,
                status: p2pResult.success ? 'synced' : 'failed',
                changesSent: p2pResult.operationsSent as int? ?? 0,
                changesReceived: p2pResult.operationsReceived as int? ?? 0,
                errorMessage: p2pResult.errorMessage as String?,
                isSuccess: p2pResult.success as bool? ?? false,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[SyncService] P2P reconciliation notice: $e');
      }
    }

    final remainingPending = getPendingCountForTrip(tripId);
    final isFullySynced =
        sources.isNotEmpty &&
        remainingPending == 0 &&
        sources.every((s) => s.isSuccess);

    await _storage.addSyncLog(
      source: 'Trip Sync ($tripId)',
      status: isFullySynced
          ? 'synced'
          : (sources.any((s) => s.status == 'offline') ? 'offline' : 'partial'),
      changesSent: totalSent,
      changesReceived: totalReceived,
      tripId: tripId,
      details:
          '$totalSent sent, $totalReceived received, $remainingPending pending',
    );

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
    return runWithTripLock('__outbox_queue__', () async {
      final activeUser = _storage.getSavedUser();
      final activeUserId = activeUser?['id'] as String? ?? activeUser?['accountId'] as String?;
      final token = activeUser?['anonymousToken'] as String? ?? activeUser?['token'] as String?;
      if (token != null && token.isNotEmpty && (apiClient.authToken == null || apiClient.authToken!.isEmpty)) {
        apiClient.setAuthToken(token);
      }

      // Auto-adopt any mutations created on this device by earlier guest sessions
      if (activeUserId != null) {
        final allMutations = getAllMutations();
        bool queueChanged = false;
        for (int i = 0; i < allMutations.length; i++) {
          final m = allMutations[i];
          if (m.originDeviceId == _storage.getDeviceId() &&
              (m.userId == null || m.userId != activeUserId)) {
            final payload = Map<String, dynamic>.from(m.payload);
            if (payload['userId'] == m.userId || payload['userId'] == null) {
              payload['userId'] = activeUserId;
            }
            if (payload['creatorId'] == m.userId || payload['creatorId'] == null) {
              payload['creatorId'] = activeUserId;
            }
            allMutations[i] = m.copyWith(
              userId: activeUserId,
              payload: payload,
            );
            queueChanged = true;
          }
        }
        if (queueChanged) {
          await _storage.saveMutationQueue(allMutations.map((m) => m.toJson()).toList());
        }
      }

      final actionableQueue = getPendingMutations(userId: activeUserId, includeQuarantined: false);
      final quarantinedQueue = getQuarantinedMutations(userId: activeUserId);

      // Guard: Do not display "Sync in progress..." if there are no actionable operations!
      if (actionableQueue.isEmpty) {
        if (quarantinedQueue.isNotEmpty) {
          _setStatus(SyncStatus.error);
          _lastErrorMessage = '${quarantinedQueue.length} change${quarantinedQueue.length > 1 ? "s" : ""} could not be synced.';
        } else {
          _isSessionExpired = false;
          _lastErrorMessage = null;
          _setStatus(SyncStatus.synced);
        }
        return;
      }

      _setStatus(SyncStatus.syncing);

      try {
        final now = DateTime.now();

        final blockedTripIds = <String>{};
        final completedMutationIds = <String>{};

        for (final mutation in actionableQueue) {
          final tId = mutation.tripId;

          // Multi-user safety: Skip mutations created by a different user account on another device
          if (activeUserId != null &&
              mutation.userId != null &&
              mutation.userId != activeUserId &&
              mutation.originDeviceId != _storage.getDeviceId()) {
            continue;
          }

          // If trip is blocked due to prior failure in this cycle (unless forced by user), skip
          if (!force && tId != null && blockedTripIds.contains(tId)) {
            continue;
          }

          // Dependency check
          final pendingIds = actionableQueue.map((m) => m.id).toSet();
          final hasUnresolvedDependencies = mutation.dependsOn.any(
            (depId) =>
                pendingIds.contains(depId) &&
                !completedMutationIds.contains(depId),
          );
          if (hasUnresolvedDependencies) {
            continue;
          }

          // Jittered exponential backoff check
          if (!force &&
              mutation.lastAttemptAt != null &&
              mutation.retryCount > 0) {
            final backoffSeconds = min(30, pow(2, mutation.retryCount).toInt());
            final nextAllowed = mutation.lastAttemptAt!.add(
              Duration(seconds: backoffSeconds),
            );
            if (now.isBefore(nextAllowed)) {
              if (tId != null) blockedTripIds.add(tId);
              continue;
            }
          }

          try {
            await _executeMutation(apiClient, mutation);
            completedMutationIds.add(mutation.id);
            await removeMutation(mutation.id);

            if (mutation.type == MutationType.updateTripLifecycle &&
                tId != null) {
              final targetLifecycle =
                  mutation.payload['lifecycleState'] as String?;
              if (targetLifecycle == 'completed' ||
                  targetLifecycle == 'settled') {
                _promoteLocalTripLifecycle(tId, targetLifecycle!);
              }
            }
          } on NetworkException catch (_) {
            _lastErrorMessage = 'No internet connection. Changes saved locally.';
            await _updateMutationAttempt(mutation.id, mutation.retryCount + 1);
            if (tId != null) blockedTripIds.add(tId);
            _setStatus(SyncStatus.offline);
            break;
          } on AccountDeletedException catch (e) {
            debugPrint('[SyncService] Global account deletion encountered during flush: $e');
            await clearQueue();
            _setStatus(SyncStatus.error);
            break;
          } on ApiException catch (e) {
            if (e.code == 'ACCOUNT_DELETED' || e.message.toLowerCase().contains('permanently deleted')) {
              debugPrint('[SyncService] Global account deletion code encountered during flush: ${e.message}');
              await clearQueue();
              _setStatus(SyncStatus.error);
              break;
            }
            debugPrint(
              '[SyncService] Client error ${e.statusCode} for mutation ${mutation.id}: ${e.message}',
            );
            _lastErrorMessage = e.message;
            if (e.statusCode == 401) {
              debugPrint(
                '[SyncService] Authentication expired (401). Pausing sync queue.',
              );
              _isSessionExpired = true;
              _lastErrorMessage =
                  'Your session has expired. Sign in again to synchronize your changes.';
              _setStatus(SyncStatus.error);
              await _updateMutationAttempt(
                mutation.id,
                mutation.retryCount,
                errorMessage: 'Session expired. Please sign in again.',
                syncState: SyncState.localPending,
              );
              break;
            } else if (e.statusCode >= 500) {
              debugPrint(
                '[SyncService] Server error ${e.statusCode} for mutation ${mutation.id}. Pausing sync with exponential backoff.',
              );
              await _updateMutationAttempt(
                mutation.id,
                mutation.retryCount + 1,
                errorMessage: 'Kith servers temporarily unavailable (${e.statusCode}). Will retry.',
                syncState: SyncState.localPending,
              );
              if (tId != null) blockedTripIds.add(tId);
              _setStatus(SyncStatus.reconnecting);
              break;
            } else if (e.statusCode == 409) {
              // Already resolved conflict / duplicate -> acknowledge safely
              completedMutationIds.add(mutation.id);
              await removeMutation(mutation.id);
            } else if (e.statusCode == 403 &&
                mutation.type == MutationType.updateTripLifecycle) {
              // Unauthorized lifecycle transition by non-creator: Drop mutation and revert local trip state to active
              debugPrint(
                '[SyncService] Dropping unauthorized lifecycle mutation ${mutation.id} (403): ${e.message}',
              );
              completedMutationIds.add(mutation.id);
              await removeMutation(mutation.id);
              if (tId != null) {
                _promoteLocalTripLifecycle(tId, 'active');
              }
            } else if (e.statusCode == 404 &&
                mutation.type == MutationType.deleteExpense &&
                e.message.toLowerCase().contains('expense not found')) {
              completedMutationIds.add(mutation.id);
              await removeMutation(mutation.id);
            } else if (e.statusCode == 404 &&
                (e.message.toLowerCase().contains('trip not found') ||
                 e.message.toLowerCase().contains('not found'))) {
              // Self-healing: Trip is missing on server! Re-create trip on server and retry.
              final tripId = mutation.tripId;
              bool autoHealed = false;
              if (tripId != null) {
                final healed = await _ensureTripOnServer(apiClient, tripId);
                if (healed) {
                  try {
                    await _executeMutation(apiClient, mutation);
                    completedMutationIds.add(mutation.id);
                    await removeMutation(mutation.id);
                    autoHealed = true;
                  } catch (_) {}
                }
              }
              if (!autoHealed) {
                _lastErrorMessage = e.message;
                await _updateMutationAttempt(
                  mutation.id,
                  mutation.retryCount + 1,
                  errorMessage: e.message,
                  syncState: SyncState.failed,
                );
                if (tId != null) blockedTripIds.add(tId);
              }
            } else {
              final msgLower = e.message.toLowerCase();
              final isMembershipError = (e.statusCode == 400 || e.statusCode == 422 || e.statusCode == 403) &&
                  (msgLower.contains('payer member') ||
                   msgLower.contains('split participant') ||
                   msgLower.contains('member not found') ||
                   msgLower.contains('not part of this trip') ||
                   msgLower.contains('is not in this trip') ||
                   msgLower.contains('not a member'));

              // Self-healing: Member or trip out of sync on server. Re-push trip & members and retry!
              bool autoHealed = false;
              if (isMembershipError && tId != null) {
                final healed = await _ensureTripOnServer(apiClient, tId);
                if (healed) {
                  try {
                    await _executeMutation(apiClient, mutation);
                    completedMutationIds.add(mutation.id);
                    await removeMutation(mutation.id);
                    autoHealed = true;
                  } catch (_) {}
                }
              }

              if (!autoHealed) {
                _lastErrorMessage = e.message;
                final isMaxRetryExceeded = mutation.retryCount >= 5 && (e.statusCode == 400 || e.statusCode == 422);

                if (isMembershipError || isMaxRetryExceeded) {
                  debugPrint(
                    '[SyncService] Quarantining mutation ${mutation.id} due to ${isMembershipError ? "member-ID divergence" : "max retries exceeded"}: ${e.message}',
                  );
                  await _updateMutationAttempt(
                    mutation.id,
                    mutation.retryCount + 1,
                    errorMessage: e.message,
                    syncState: SyncState.quarantined,
                  );
                  // CRITICAL: Do NOT add tId to blockedTripIds so independent trip operations can proceed!
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
              }
            }
          } catch (e) {
            debugPrint(
              '[SyncService] Unexpected error on mutation ${mutation.id}: $e',
            );
            _lastErrorMessage = e.toString();
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

        final remainingActionable = getPendingMutations(userId: activeUserId, includeQuarantined: false);
        final remainingQuarantined = getQuarantinedMutations(userId: activeUserId);

        if (remainingActionable.isEmpty) {
          _isSessionExpired = false;
          _lastErrorMessage = null;
          if (remainingQuarantined.isNotEmpty) {
            _setStatus(SyncStatus.error);
            _lastErrorMessage = '${remainingQuarantined.length} change${remainingQuarantined.length > 1 ? "s" : ""} could not be synced.';
          } else {
            _setStatus(SyncStatus.synced);
          }
        } else if (_currentStatus != SyncStatus.offline &&
            _currentStatus != SyncStatus.error &&
            _currentStatus != SyncStatus.reconnecting) {
          if (completedMutationIds.isNotEmpty) {
            _setStatus(SyncStatus.pending);
          } else if (force || blockedTripIds.isNotEmpty || remainingActionable.any((m) => m.retryCount > 0)) {
            _setStatus(SyncStatus.error);
            _lastErrorMessage = _lastErrorMessage ??
                'Unable to sync ${remainingActionable.length} change${remainingActionable.length > 1 ? "s" : ""}. Tap to review.';
          } else {
            _setStatus(SyncStatus.pending);
          }
        }
      } finally {
        // Per-trip lock releases in runWithTripLock
      }
    });
  }

  Future<bool> _ensureTripOnServer(ApiClient apiClient, String tripId) async {
    final trips = _storage.getSavedTrips();
    final tripJson = trips.where((t) => t['id'] == tripId).firstOrNull;
    if (tripJson == null) return false;

    final user = _storage.getSavedUser();
    final accountId =
        user?['accountId'] as String? ?? user?['id'] as String? ?? 'guest_acc';

    // 1. Sync to Supabase directly
    if (_cloudSync.isAvailable) {
      try {
        await _cloudSync.syncTrip(tripJson, accountId: accountId);
      } catch (_) {}
    }

    // 2. Post to API backend
    try {
      final members = (tripJson['members'] as List<dynamic>? ?? []);
      final friendNames = members
          .where((m) => m is Map && m['role'] != 'creator')
          .map((m) => (m as Map)['displayName']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final payload = {
        'id': tripJson['id'],
        'name': tripJson['name'],
        'description': tripJson['description'],
        'emoji': tripJson['emoji'] ?? '✈️',
        'coverGradientIndex': tripJson['coverGradientIndex'] ?? 0,
        'currencyCode': tripJson['currencyCode'] ?? 'INR',
        'tripMode': tripJson['tripMode'] ?? 'split_only',
        'inviteCode': tripJson['inviteCode'],
        'p2pTripSecret': tripJson['p2pTripSecret'] ?? tripJson['p2p_trip_secret'],
        'p2p_trip_secret': tripJson['p2pTripSecret'] ?? tripJson['p2p_trip_secret'],
        'initialFriendNames': friendNames,
        'members': members,
      };

      try {
        await apiClient.post('/trips', body: payload);
      } on ApiException catch (e) {
        if (e.statusCode != 409) {
          rethrow;
        }
        // 409 Conflict: trip already exists on server, proceed to synchronize members
      }

      // Re-push members to guarantee all participant IDs exist on server
      for (final m in members) {
        if (m is Map) {
          try {
            await apiClient.post('/trips/$tripId/members', body: {
              'tripId': tripId,
              'id': m['id'],
              'userId': m['userId'],
              'displayName': m['displayName'],
              'claimToken': m['claimToken'],
              'isVirtual': m['isVirtual'] ?? true,
            });
          } catch (_) {}
        }
      }

      return true;
    } catch (e) {
      debugPrint('[SyncService] Failed to auto-heal trip $tripId on server: $e');
      return false;
    }
  }

  /// Authoritative incremental Delta Cloud reconciliation using Supabase.
  /// Fetches only changes that occurred after the last sync cursor to protect Supabase Free Tier.
  Future<TripSyncReport> reconcileWithCloud(
    String accountId, {
    ApiClient? apiClient,
  }) async {
    _setStatus(SyncStatus.syncing);
    final sources = <SyncSourceResult>[];
    int totalSent = 0;
    int totalReceived = 0;

    try {
      // 1. Flush pending mutations first
      if (apiClient != null) {
        await flushQueue(apiClient);
      }

      // 2. Fetch change events using PostgreSQL serialized monotonic sequence RPC
      final lastSeq = _storage.getInt('kith_last_sync_seq_$accountId') ?? 0;
      final syncEvents = await _cloudSync.fetchSyncEvents(
        accountId: accountId,
        lastSeq: lastSeq,
      );

      if (syncEvents.isNotEmpty) {
        int maxSeq = lastSeq;
        final workingTrips = Map<String, Map<String, dynamic>>.fromEntries(
          _storage.getSavedTrips().map((t) => MapEntry(t['id'] as String, t)),
        );
        final workingExpensesByTrip =
            <String, Map<String, Map<String, dynamic>>>{};
        final workingSettlementsByTrip =
            <String, Map<String, Map<String, dynamic>>>{};
        final workingPE = Map<String, Map<String, dynamic>>.fromEntries(
          _storage.getSavedPersonalExpenses().map(
            (pe) => MapEntry(pe['id'] as String, pe),
          ),
        );
        final workingPD = Map<String, Map<String, dynamic>>.fromEntries(
          _storage.getSavedPersonalDebts().map(
            (pd) => MapEntry(pd['id'] as String, pd),
          ),
        );
        final tombstonesToAdd = <Map<String, String>>[];

        for (final ev in syncEvents) {
          final seq = (ev['seq'] as num?)?.toInt() ?? 0;
          if (seq > maxSeq) maxSeq = seq;

          final table = ev['table_name'] as String?;
          final action = ev['action'] as String?;
          final recordId = ev['record_id'] as String?;
          final tripId = ev['trip_id'] as String?;
          final rawPayload = ev['payload'];
          final payload = rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : <String, dynamic>{};

          if (table == 'trips' && recordId != null) {
            if (action == 'DELETE') {
              workingTrips.remove(recordId);
            } else if (payload.isNotEmpty) {
              final existingJson = workingTrips[recordId];
              if (existingJson != null) {
                final localTrip = Trip.fromJson(existingJson);
                final remoteTrip = Trip.fromJson(payload);
                final mergeResult = localTrip.mergeWithDetailed(remoteTrip);
                workingTrips[recordId] = mergeResult.mergedTrip.toJson();
                if (mergeResult.memberIdMap.isNotEmpty) {
                  await _storage.translateMemberIds(
                    tripId: recordId,
                    translationMap: mergeResult.memberIdMap,
                  );
                }
              } else {
                workingTrips[recordId] = payload;
              }
            }
          } else if (table == 'expenses' &&
              tripId != null &&
              recordId != null) {
            workingExpensesByTrip.putIfAbsent(
              tripId,
              () => Map.fromEntries(
                _storage
                    .getSavedExpenses(tripId)
                    .map((e) => MapEntry(e['id'] as String, e)),
              ),
            );
            if (action == 'DELETE') {
              workingExpensesByTrip[tripId]!.remove(recordId);
              tombstonesToAdd.add({'tripId': tripId, 'expenseId': recordId});
            } else if (payload.isNotEmpty) {
              final pendingForExpense = getPendingMutationsForTrip(tripId).any((m) {
                final entityId = (m.payload['id'] ?? m.payload['expenseId'])?.toString();
                return entityId == recordId &&
                    (m.type == MutationType.addExpense ||
                        m.type == MutationType.updateExpense ||
                        m.type == MutationType.deleteExpense);
              });
              final existing = workingExpensesByTrip[tripId]![recordId];
              final localUpdated = DateTime.tryParse(existing?['updatedAt']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final remoteUpdated = DateTime.tryParse(
                    payload['updatedAt']?.toString() ?? payload['updated_at']?.toString() ?? '',
                  ) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final tombstoned = _storage.isExpenseTombstoned(tripId, recordId);
              if (!pendingForExpense && !tombstoned && (existing == null || !localUpdated.isAfter(remoteUpdated))) {
                workingExpensesByTrip[tripId]![recordId] = payload;
              }
            }
          } else if (table == 'settlements' &&
              tripId != null &&
              recordId != null) {
            workingSettlementsByTrip.putIfAbsent(
              tripId,
              () => Map.fromEntries(
                _storage
                    .getSavedTripSettlements(tripId)
                    .map((s) => MapEntry(s['id'] as String, s)),
              ),
            );
            if (action == 'DELETE') {
              workingSettlementsByTrip[tripId]!.remove(recordId);
            } else if (payload.isNotEmpty) {
              workingSettlementsByTrip[tripId]![recordId] = payload;
            }
          } else if (table == 'personal_expenses' && recordId != null) {
            if (action == 'DELETE') {
              workingPE.remove(recordId);
            } else if (payload.isNotEmpty) {
              workingPE[recordId] = payload;
            }
          } else if (table == 'personal_debts' && recordId != null) {
            if (action == 'DELETE') {
              workingPD.remove(recordId);
            } else if (payload.isNotEmpty) {
              workingPD[recordId] = payload;
            }
          }
        }

        // Apply entire event page atomically before advancing cursor
        final commitOk = await _storage.commitAtomicMutationBatch(
          updatedTrips: workingTrips.values.toList(),
          updatedExpensesByTrip: workingExpensesByTrip.map(
            (k, v) => MapEntry(k, v.values.toList()),
          ),
          updatedSettlementsByTrip: workingSettlementsByTrip.map(
            (k, v) => MapEntry(k, v.values.toList()),
          ),
          updatedPersonalExpenses: workingPE.values.toList(),
          updatedPersonalDebts: workingPD.values.toList(),
        );

        if (commitOk) {
          for (final t in tombstonesToAdd) {
            await _storage.markExpenseTombstoned(t['tripId']!, t['expenseId']!);
          }
          await _storage.setInt('kith_last_sync_seq_$accountId', maxSeq);
          totalReceived += syncEvents.length;
        } else {
          throw StateError(
            'Atomic commit failed for sync events batch up to seq $maxSeq',
          );
        }
      }

      // 3. Fallback / Cold Start Bootstrap:
      // Keyset pagination delta changes run ONLY when lastSeq == 0 AND syncEvents.isEmpty
      // (e.g. cold start on an older backend or when event changelog has not been initialized).
      // Once lastSeq > 0, an empty syncEvents simply means "zero new changes", NOT a fallback!
      final shouldRunColdStartFallback = (lastSeq == 0 && syncEvents.isEmpty);

      if (shouldRunColdStartFallback) {
        final rawCursor = _storage.getString(
          'kith_last_sync_cursor_$accountId',
        );
        final cursor = rawCursor != null && rawCursor.isNotEmpty
            ? (DateTime.tryParse(rawCursor) ??
                  DateTime.now().subtract(const Duration(days: 30)))
            : DateTime.now().subtract(const Duration(days: 30));

        final activeTrips = _storage
            .getSavedTrips()
            .map((t) => t['id'] as String)
            .toList();
        final deltas = await _cloudSync.fetchDeltaChanges(
          accountId: accountId,
          sinceCursor: cursor,
          activeTripIds: activeTrips,
        );

        // Reconcile modified trips with Non-Destructive Safe Union Merge
        final modifiedTrips =
            deltas['modifiedTrips'] as List<Map<String, dynamic>>? ?? [];
        if (modifiedTrips.isNotEmpty) {
          final existingTrips = _storage.getSavedTrips();
          final tripMap = {for (final t in existingTrips) t['id']: t};
          for (final t in modifiedTrips) {
            if (t['is_deleted'] == true) {
              tripMap.remove(t['id']);
            } else {
              final existingJson = tripMap[t['id']];
              if (existingJson != null) {
                final localTrip = Trip.fromJson(existingJson);
                final remoteTrip = Trip.fromJson(t);
                final mergeResult = localTrip.mergeWithDetailed(remoteTrip);
                tripMap[t['id']] = mergeResult.mergedTrip.toJson();
                if (mergeResult.memberIdMap.isNotEmpty) {
                  await _storage.translateMemberIds(
                    tripId: t['id'] as String,
                    translationMap: mergeResult.memberIdMap,
                  );
                }
              } else {
                tripMap[t['id']] = t;
              }
            }
          }
          await _storage.saveTrips(tripMap.values.toList());
          totalReceived += modifiedTrips.length;
        }

        // Reconcile modified expenses
        final modifiedExpenses =
            deltas['modifiedExpenses'] as List<Map<String, dynamic>>? ?? [];
        for (final exp in modifiedExpenses) {
          final tripId = exp['trip_id'] as String? ?? exp['tripId'] as String?;
          if (tripId != null && tripId.isNotEmpty) {
            final existingExp = _storage.getSavedExpenses(tripId);
            final expId = exp['id'] as String;
            final isDeleted =
                exp['is_deleted'] == true || exp['isDeleted'] == true;
            existingExp.removeWhere((e) => e['id'] == expId);
            if (!isDeleted) {
              existingExp.insert(0, exp);
            }
            await _storage.saveExpenses(tripId, existingExp);
            totalReceived++;
          }
        }

        // Reconcile modified settlements
        final modifiedSettlements =
            deltas['modifiedSettlements'] as List<Map<String, dynamic>>? ?? [];
        for (final stl in modifiedSettlements) {
          final tripId = stl['trip_id'] as String? ?? stl['tripId'] as String?;
          if (tripId != null && tripId.isNotEmpty) {
            final existingStl = _storage.getSavedTripSettlements(tripId);
            final stlId = stl['id'] as String;
            final isDeleted =
                stl['is_deleted'] == true || stl['isDeleted'] == true;
            existingStl.removeWhere((s) => s['id'] == stlId);
            if (!isDeleted) {
              existingStl.insert(0, stl);
            }
            await _storage.saveTripSettlements(tripId, existingStl);
            totalReceived++;
          }
        }

        // Reconcile modified personal expenses
        final modifiedPE =
            deltas['modifiedPersonalExpenses'] as List<Map<String, dynamic>>? ??
            [];
        if (modifiedPE.isNotEmpty) {
          final existingPE = _storage.getSavedPersonalExpenses();
          final peMap = {for (final pe in existingPE) pe['id']: pe};
          for (final pe in modifiedPE) {
            if (pe['is_deleted'] == true) {
              peMap.remove(pe['id']);
            } else {
              peMap[pe['id']] = pe;
            }
          }
          await _storage.savePersonalExpenses(peMap.values.toList());
          totalReceived += modifiedPE.length;
        }

        // Reconcile modified personal debts
        final modifiedPD =
            deltas['modifiedPersonalDebts'] as List<Map<String, dynamic>>? ??
            [];
        if (modifiedPD.isNotEmpty) {
          final existingPD = _storage.getSavedPersonalDebts();
          final pdMap = {for (final pd in existingPD) pd['id']: pd};
          for (final pd in modifiedPD) {
            if (pd['is_deleted'] == true) {
              pdMap.remove(pd['id']);
            } else {
              pdMap[pd['id']] = pd;
            }
          }
          await _storage.savePersonalDebts(pdMap.values.toList());
          totalReceived += modifiedPD.length;
        }

        // Advance server sync cursor accurately
        final serverTsStr = deltas['latestServerTimestamp'] as String?;
        final nextCursor = serverTsStr != null && serverTsStr.isNotEmpty
            ? DateTime.tryParse(serverTsStr) ??
                  DateTime.now().subtract(const Duration(seconds: 2))
            : DateTime.now().subtract(const Duration(seconds: 2));
        await _storage.setString(
          'kith_last_sync_cursor_$accountId',
          nextCursor.toIso8601String(),
        );
      }

      _setStatus(SyncStatus.synced);

      sources.add(
        SyncSourceResult(
          name: 'Kith Authoritative Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'synced',
          changesSent: totalSent,
          changesReceived: totalReceived,
          isSuccess: true,
        ),
      );
    } catch (e) {
      debugPrint('[SyncService] Cloud reconciliation notice: $e');
      _setStatus(SyncStatus.error);
      sources.add(
        SyncSourceResult(
          name: 'Kith Authoritative Cloud (Supabase)',
          type: SyncSourceType.cloud,
          status: 'failed',
          errorMessage: e.toString(),
          isSuccess: false,
        ),
      );
    }

    final hasSuccess = sources.any((s) => s.isSuccess);
    final hasFailure = sources.any((s) => !s.isSuccess);
    final finalOutcome = (hasSuccess && !hasFailure)
        ? SyncOperationOutcome.success
        : (hasSuccess && hasFailure)
        ? SyncOperationOutcome.partial
        : SyncOperationOutcome.failed;

    return TripSyncReport(
      tripId: 'all_trips',
      timestamp: DateTime.now(),
      sources: sources,
      totalChangesSent: totalSent,
      totalChangesReceived: totalReceived,
      pendingChangesCount: pendingCount,
      isFullySynced: pendingCount == 0,
      outcome: finalOutcome,
    );
  }

  void _promoteLocalTripLifecycle(String tripId, String targetLifecycle) {
    try {
      final trips = _storage.getSavedTrips();
      final idx = trips.indexWhere((t) => t['id'] == tripId);
      if (idx != -1) {
        trips[idx] = {
          ...trips[idx],
          'lifecycleState': targetLifecycle,
          'completedAt':
              targetLifecycle == 'completed' || targetLifecycle == 'settled'
              ? (trips[idx]['completedAt'] ?? DateTime.now().toIso8601String())
              : trips[idx]['completedAt'],
        };
        _storage.saveTrips(trips);
      }
    } catch (_) {}
  }

  Future<void> _executeMutation(
    ApiClient apiClient,
    SyncMutation mutation,
  ) async {
    final payload = mutation.payload;
    final user = _storage.getSavedUser();
    final accountId =
        user?['accountId'] as String? ?? user?['id'] as String? ?? 'guest_acc';

    // Supabase is a best-effort mirror. Outbox acknowledgement depends on the API push below.
    if (_cloudSync.isAvailable) {
      try {
        switch (mutation.type) {
          case MutationType.createTrip:
          case MutationType.joinTrip:
await _cloudSync.syncTrip(payload, accountId: accountId);
            break;
          case MutationType.addMember:
          case MutationType.renameMember:
            final tId = mutation.payload['tripId'] as String?;
            if (tId != null) {
              final tripJson = _storage
                  .getSavedTrips()
                  .where((t) => t['id'] == tId)
                  .firstOrNull;
              if (tripJson != null) {
await _cloudSync.syncTrip(
                  tripJson,
                  accountId: accountId,
                );
              }
            }
            break;
          case MutationType.addExpense:
          case MutationType.updateExpense:
await _cloudSync.syncExpense(payload, accountId: accountId);
            break;
          case MutationType.deleteExpense:
            final tripId = mutation.payload['tripId'] as String? ?? '';
            final expenseId =
                payload['id'] as String? ??
                payload['expenseId'] as String? ??
                '';
            if (expenseId.isNotEmpty) {
await _cloudSync.markExpenseDeleted(expenseId, tripId);
            }
            break;
          case MutationType.recordTripSettlement:
          case MutationType.confirmTripSettlement:
          case MutationType.disputeTripSettlement:
          case MutationType.submitSettlementProof:
await _cloudSync.syncSettlement(payload, accountId: accountId);
            break;
          case MutationType.createPersonalExpense:
          case MutationType.updatePersonalExpense:
await _cloudSync.syncPersonalExpense(payload, accountId: accountId);
            break;
          case MutationType.createPersonalDebt:
          case MutationType.updatePersonalDebt:
          case MutationType.recordPersonalRepayment:
await _cloudSync.syncPersonalDebt(payload, accountId: accountId);
            break;
          default:
            break;
        }
      } catch (e) {
        debugPrint('[SyncService] Direct Supabase push notice: $e');
      }
    }

    // The Node API is the read path for trips and expenses. A Supabase mirror
    // write must not acknowledge the outbox until that API accepts the change.
    await _pushToSecondaryApi(apiClient, mutation);
  }

  Future<void> _pushToSecondaryApi(
    ApiClient apiClient,
    SyncMutation mutation,
  ) async {
    final payload = mutation.payload;
    switch (mutation.type) {
      case MutationType.createTrip:
        await apiClient.post('/trips', body: payload);
        break;

      case MutationType.joinTrip:
        await apiClient.post('/trips/join', body: payload);
        break;

      case MutationType.addMember:
        final tripId = mutation.payload['tripId'] as String;
        final res = await apiClient.post('/trips/$tripId/members', body: payload);
        if (res is Map<String, dynamic>) {
          final serverTrip = Trip.fromJson(res);
          final trips = _storage.getSavedTrips().map((j) => Trip.fromJson(j)).toList();
          final idx = trips.indexWhere((t) => t.id == tripId);
          if (idx != -1) {
            final mergeResult = trips[idx].mergeWithDetailed(serverTrip);
            trips[idx] = mergeResult.mergedTrip;
            await _storage.saveTrips(trips.map((t) => t.toJson()).toList());
            if (mergeResult.memberIdMap.isNotEmpty) {
              await _storage.translateMemberIds(
                tripId: tripId,
                translationMap: mergeResult.memberIdMap,
              );
            }
          }
        }
        break;

      case MutationType.renameMember:
        final tripId = mutation.payload['tripId'] as String;
        final memberId =
            payload['memberId'] as String? ?? payload['id'] as String;
        await apiClient.patch(
          '/trips/$tripId/members/$memberId',
          body: payload,
        );
        break;

      case MutationType.updateTripLifecycle:
        final tripId = mutation.tripId ?? (mutation.payload['tripId'] as String?) ?? '';
        await apiClient.patch('/trips/$tripId/lifecycle', body: payload);
        break;

      case MutationType.addExpense:
      case MutationType.updateExpense:
        final tripId = mutation.tripId ?? (mutation.payload['tripId'] as String?) ?? 'general';
        final expensePayload = Map<String, dynamic>.from(payload);

        // Dynamic member ID self-healing: rewrite any merged or translated member IDs in payload
        final tripJson = _storage.getSavedTrips().where((t) => t['id'] == tripId).firstOrNull;
        if (tripJson != null) {
          final members = tripJson['members'] as List<dynamic>? ?? [];
          final translationMap = <String, String>{};
          for (final m in members) {
            if (m is Map) {
              final mergedInto = m['mergedIntoMemberId'] ?? m['merged_into_member_id'];
              final mId = m['id']?.toString();
              if (mergedInto != null && mId != null && mergedInto != mId) {
                translationMap[mId] = mergedInto.toString();
              }
            }
          }
          if (translationMap.isNotEmpty) {
            final oldPaidBy = expensePayload['paidById']?.toString() ?? expensePayload['paid_by_id']?.toString();
            if (oldPaidBy != null && translationMap.containsKey(oldPaidBy)) {
              expensePayload['paidById'] = translationMap[oldPaidBy];
            }
            if (expensePayload['splits'] is List) {
              final splitsList = (expensePayload['splits'] as List).map((s) {
                if (s is Map) {
                  final sMap = Map<String, dynamic>.from(s);
                  final mId = sMap['memberId']?.toString() ?? sMap['member_id']?.toString();
                  if (mId != null && translationMap.containsKey(mId)) {
                    sMap['memberId'] = translationMap[mId];
                  }
                  return sMap;
                }
                return s;
              }).toList();
              expensePayload['splits'] = splitsList;
            }
          }
        }

        if (mutation.type == MutationType.addExpense) {
          await apiClient.post('/trips/$tripId/expenses', body: expensePayload);
        } else {
          final expenseId =
              expensePayload['id'] as String? ?? expensePayload['expenseId'] as String? ?? mutation.id;
          await apiClient.put(
            '/trips/$tripId/expenses/$expenseId',
            body: expensePayload,
          );
        }
        break;

      case MutationType.deleteExpense:
        final tripId = mutation.tripId ?? (mutation.payload['tripId'] as String?) ?? 'general';
        final expenseId =
            payload['id'] as String? ?? payload['expenseId'] as String? ?? mutation.id;
        await apiClient.delete('/trips/$tripId/expenses/$expenseId');
        break;

      case MutationType.createPersonalExpense:
        await apiClient.post('/personal/expenses', body: payload);
        break;

      case MutationType.updatePersonalExpense:
        final expenseId =
            payload['id'] as String? ?? payload['expenseId'] as String;
        await apiClient.put('/personal/expenses/$expenseId', body: payload);
        break;

      case MutationType.deletePersonalExpense:
        final expenseId =
            payload['id'] as String? ?? payload['expenseId'] as String;
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
        await apiClient.post(
          '/personal/debts/$debtId/repayments',
          body: payload,
        );
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
        final momentId =
            payload['id'] as String? ?? payload['momentId'] as String;
        await apiClient.delete('/trips/$tripId/moments/$momentId');
        break;

      case MutationType.recordTripSettlement:
        final tripId = mutation.payload['tripId'] as String? ?? mutation.tripId;
        if (tripId != null && tripId.isNotEmpty) {
          await apiClient.post('/trips/$tripId/settlements', body: payload);
        }
        break;

      case MutationType.confirmTripSettlement:
        final tripId = mutation.payload['tripId'] as String? ?? mutation.tripId;
        final settlementId =
            payload['id'] as String? ?? payload['settlementId'] as String?;
        if (tripId != null && tripId.isNotEmpty && settlementId != null && settlementId.isNotEmpty) {
          await apiClient.post(
            '/trips/$tripId/settlements/$settlementId/confirm',
            body: payload,
          );
        }
        break;

      case MutationType.disputeTripSettlement:
        final tripId = mutation.payload['tripId'] as String? ?? mutation.tripId;
        final settlementId =
            payload['id'] as String? ?? payload['settlementId'] as String?;
        if (tripId != null && tripId.isNotEmpty && settlementId != null && settlementId.isNotEmpty) {
          await apiClient.post(
            '/trips/$tripId/settlements/$settlementId/dispute',
            body: payload,
          );
        }
        break;

      case MutationType.submitSettlementProof:
        final tripId = mutation.payload['tripId'] as String? ?? mutation.tripId;
        final settlementId =
            payload['id'] as String? ?? payload['settlementId'] as String?;
        if (tripId != null && tripId.isNotEmpty && settlementId != null && settlementId.isNotEmpty) {
          await apiClient.post(
            '/trips/$tripId/settlements/$settlementId/proof',
            body: payload,
          );
        }
        break;
    }
  }

  /// Attaches a realtime client to automatically trigger local queue flush when sync is requested.
  void attachRealtimeClient(
    RealtimeClient realtimeClient, {
    ApiClient? apiClient,
  }) {
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
    stopPeriodicSync();
    _realtimeSubscription?.cancel();
    _statusController.close();
  }
}
