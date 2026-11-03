import 'dart:async';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/engine/balance_engine.dart';
import '../../domain/engine/money_engine.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import 'package:uuid/uuid.dart';

class ExpenseRepository {
  final LocalStorageService storage;
  final SyncService syncService;
  final ApiClient apiClient;
  final RealtimeClient? realtimeClient;

  ExpenseRepository({
    required this.storage,
    required this.syncService,
    required this.apiClient,
    this.realtimeClient,
  });

  final Map<String, List<Expense>> _cachedExpensesInMemory = {};

  /// Invalidates in-memory expense cache. If [tripId] is provided, only that trip's cache is invalidated.
  void invalidateCache([String? tripId]) {
    if (tripId != null) {
      _cachedExpensesInMemory.remove(tripId);
    } else {
      _cachedExpensesInMemory.clear();
    }
  }

  /// Synchronously returns cached expenses for a trip without network latency.
  List<Expense> getCachedExpenses(String tripId) {
    if (_cachedExpensesInMemory.containsKey(tripId)) {
      return _cachedExpensesInMemory[tripId]!;
    }
    final raw = storage.getSavedExpenses(tripId);
    final list = raw.map((json) => Expense.fromJson(json)).toList();
    _cachedExpensesInMemory[tripId] = list;
    return list;
  }

  /// Loads all expenses recorded for a specific trip.
  /// Uses local-first two-way reconciliation with pending outbox mutation preservation:
  /// Local un-synced expenses and edits are never wiped by older server data,
  /// and locally deleted expenses are never resurrected.
  Future<List<Expense>> getExpenses(String tripId) async {
    final localExpenses = getCachedExpenses(tripId);
    try {
      final res = await apiClient.get('/trips/$tripId/expenses');
      if (res is List) {
        final serverExpenses = res.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList();

        // 1. Inspect local pending outbox mutations
        final pendingMutations = syncService.getPendingMutationsForTrip(tripId);
        final pendingDeletedIds = pendingMutations
            .where((m) => m.type == MutationType.deleteExpense)
            .map((m) => (m.payload['id'] ?? m.payload['expenseId']).toString())
            .toSet();
        final pendingUpdateMap = {
          for (final m in pendingMutations.where((m) => m.type == MutationType.updateExpense))
            (m.payload['id'] ?? m.payload['expenseId']).toString(): Expense.fromJson(m.payload)
        };

        final mergedMap = <String, Expense>{};
        // 2. Populate local expenses, skipping locally deleted items
        for (final local in localExpenses) {
          if (!local.isDeleted && !pendingDeletedIds.contains(local.id)) {
            mergedMap[local.id] = local;
          }
        }

        // 3. Merge server expenses safely
        for (final server in serverExpenses) {
          // Never resurrect an expense marked for deletion in the local outbox
          if (pendingDeletedIds.contains(server.id)) {
            continue;
          }
          // Never overwrite a local unpushed edit with older server data
          if (pendingUpdateMap.containsKey(server.id)) {
            final pendingEdit = pendingUpdateMap[server.id]!;
            if (pendingEdit.updatedAt.isAfter(server.updatedAt)) {
              mergedMap[server.id] = pendingEdit;
              continue;
            }
          }
          if (!server.isDeleted) {
            mergedMap[server.id] = server;
          } else {
            mergedMap.remove(server.id);
          }
        }

        final mergedList = mergedMap.values.toList();
        mergedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        await storage.saveExpenses(tripId, mergedList.map((e) => e.toJson()).toList());
        _cachedExpensesInMemory[tripId] = mergedList;
        return mergedList;
      }
    } catch (_) {
      // Offline fallback: return durable local cache
    }

    return localExpenses;
  }

  /// Adds a new expense to the trip after verifying deterministic zero-sum split equality.
  Future<Expense> addExpense(Expense expense) async {
    // Deterministic client-side validation
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
    }

    // 1. FAST LOCAL HYDRATION & ATOMIC COMMIT:
    // Staging domain state and outbox mutation atomically in a single coordinated batch
    final currentExpenses = getCachedExpenses(expense.tripId);
    currentExpenses.removeWhere((e) => e.id == expense.id);
    currentExpenses.insert(0, expense);

    final queue = syncService.getPendingMutations();
    final mutation = SyncMutation(
      id: const Uuid().v4(),
      idempotencyKey: expense.id,
      type: MutationType.addExpense,
      payload: expense.toJson(),
      createdAt: DateTime.now(),
      syncState: SyncState.localPending,
      originDeviceId: storage.getDeviceId(),
    );
    queue.add(mutation);

    await storage.commitAtomicMutationBatch(
      updatedExpensesByTrip: {
        expense.tripId: currentExpenses.map((e) => e.toJson()).toList(),
      },
      updatedOutbox: queue.map((m) => m.toJson()).toList(),
    );
    _cachedExpensesInMemory[expense.tripId] = currentExpenses;

    _logLocalActivity(
      tripId: expense.tripId,
      type: 'expense_added',
      description: 'Added "${expense.title}" for ₹${(expense.amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {'expenseId': expense.id, 'amountInPaise': expense.amountInPaise},
    );

    unawaited(syncService.flushQueue(apiClient));
    return expense;
  }

  /// Updates an existing expense after verifying deterministic zero-sum split equality.
  Future<Expense> updateExpense(Expense expense) async {
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
    }

    // 1. Update local persistent cache & outbox atomically
    final currentExpenses = getCachedExpenses(expense.tripId);
    final idx = currentExpenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      currentExpenses[idx] = expense;
    } else {
      currentExpenses.insert(0, expense);
    }

    final queue = syncService.getPendingMutations();
    final mutation = SyncMutation(
      id: const Uuid().v4(),
      idempotencyKey: expense.id,
      type: MutationType.updateExpense,
      payload: expense.toJson(),
      createdAt: DateTime.now(),
      syncState: SyncState.localPending,
      originDeviceId: storage.getDeviceId(),
    );
    queue.add(mutation);

    await storage.commitAtomicMutationBatch(
      updatedExpensesByTrip: {
        expense.tripId: currentExpenses.map((e) => e.toJson()).toList(),
      },
      updatedOutbox: queue.map((m) => m.toJson()).toList(),
    );
    _cachedExpensesInMemory[expense.tripId] = currentExpenses;

    _logLocalActivity(
      tripId: expense.tripId,
      type: 'expense_updated',
      description: 'Updated "${expense.title}" for ₹${(expense.amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {'expenseId': expense.id, 'amountInPaise': expense.amountInPaise},
    );

    unawaited(syncService.flushQueue(apiClient));
    return expense;
  }


  /// Deletes an expense by ID and updates local cache.
  Future<void> deleteExpense({
    required String tripId,
    required String expenseId,
  }) async {

    final currentExpenses = getCachedExpenses(tripId);
    final index = currentExpenses.indexWhere((e) => e.id == expenseId);
    String deletedTitle = 'Expense';
    if (index != -1) {
      deletedTitle = currentExpenses[index].title;
      currentExpenses.removeAt(index);
    }

    final queue = syncService.getPendingMutations();
    final mutation = SyncMutation(
      id: const Uuid().v4(),
      idempotencyKey: 'del_$expenseId',
      type: MutationType.deleteExpense,
      payload: {'tripId': tripId, 'expenseId': expenseId},
      createdAt: DateTime.now(),
      syncState: SyncState.localPending,
      originDeviceId: storage.getDeviceId(),
    );
    queue.add(mutation);

    await storage.commitAtomicMutationBatch(
      updatedExpensesByTrip: {
        tripId: currentExpenses.map((e) => e.toJson()).toList(),
      },
      updatedOutbox: queue.map((m) => m.toJson()).toList(),
      tombstoneToAdd: {'tripId': tripId, 'expenseId': expenseId},
    );

    _logLocalActivity(
      tripId: tripId,
      type: 'expense_deleted',
      description: 'Deleted expense "$deletedTitle"',
      metadata: {'expenseId': expenseId},
    );

    unawaited(syncService.flushQueue(apiClient));
  }

  /// Computes the live balance summary for a trip.
  /// Always derives balances from local canonical expenses and settlements
  /// to guarantee 100% deterministic agreement with the displayed expense list.
  Future<BalanceSummary> getBalanceSummary({
    required Trip trip,
    required String currentUserId,
  }) async {
    final savedSettlements = storage.getSavedTripSettlements(trip.id);
    final expenses = getCachedExpenses(trip.id);

    return BalanceEngine.calculateBalances(
      members: trip.members,
      expenses: expenses,
      settlements: savedSettlements,
      currentUserId: currentUserId,
    );
  }

  /// Returns cached settlements for a trip.
  List<Map<String, dynamic>> getCachedSettlements(String tripId) {
    return storage.getSavedTripSettlements(tripId);
  }

  /// Fetches authoritative settlements for a trip from the server and updates local cache.
  Future<List<Map<String, dynamic>>> getSettlements(String tripId) async {
    final cached = storage.getSavedTripSettlements(tripId);
    try {
      final res = await apiClient.get('/trips/$tripId/settlements');
      if (res is List) {
        final serverList = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        // Inspect pending settlement mutations to avoid dropping offline recorded settlements
        final pendingMutations = syncService.getPendingMutationsForTrip(tripId);
        final pendingSettlementIds = pendingMutations
            .where((m) => m.type == MutationType.recordTripSettlement)
            .map((m) => (m.payload['id'] ?? m.payload['settlementId']).toString())
            .toSet();

        final mergedMap = <String, Map<String, dynamic>>{};
        for (final c in cached) {
          final id = c['id']?.toString() ?? '';
          if (id.isNotEmpty) mergedMap[id] = c;
        }
        for (final s in serverList) {
          final id = s['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            // Keep local version if pending unpushed update
            if (pendingSettlementIds.contains(id) && mergedMap.containsKey(id)) {
              continue;
            }
            mergedMap[id] = s;
          }
        }

        final mergedList = mergedMap.values.toList();
        await storage.saveTripSettlements(tripId, mergedList);
        return mergedList;
      }
    } catch (_) {
      // Offline fallback to cached settlements
    }
    return cached;
  }

  /// Fetches pending settlement verifications across all user trips from the server.
  Future<void> syncPendingVerifications(String currentUserId) async {
    if (currentUserId.isEmpty) return;
    try {
      final res = await apiClient.get('/settlements/pending');
      if (res is Map<String, dynamic>) {
        final pendingList = (res['pending'] as List?) ?? [];
        for (final p in pendingList) {
          if (p is Map) {
            final pMap = Map<String, dynamic>.from(p);
            await storage.addPaymentVerification(pMap);
          }
        }
        final disputedList = (res['disputed'] as List?) ?? [];
        for (final d in disputedList) {
          if (d is Map) {
            final dMap = Map<String, dynamic>.from(d);
            await storage.addPaymentVerification(dMap);
          }
        }
      }
    } catch (_) {
      // Background sync non-blocking
    }
  }

  /// Records a direct settlement payment between two members.
  Future<void> recordSettlement({
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    required int amountInPaise,
    String? settlementId,
    String? paymentReference,
    String? recipientUpiId,
    String? fromName,
    String? toName,
    String? note,
    String paymentStatus = 'marked_paid',
    String? tripName,
    String? fromUserId,
    String? toUserId,
  }) async {
    final id = settlementId ?? 'stl_loc_${DateTime.now().millisecondsSinceEpoch}';
    final isActuallyPaid = paymentStatus == 'confirmed' || paymentStatus == 'paid' || paymentStatus == 'completed' || paymentStatus == 'manual_settled';
    final payload = {
      'id': id,
      'tripId': tripId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'amountInPaise': amountInPaise,
      'paymentReference': paymentReference,
      'recipientUpiId': recipientUpiId,
      'fromName': fromName,
      'toName': toName,
      'note': note,
      'status': paymentStatus,
      'isSettled': isActuallyPaid,
      'markedPaidAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Save locally (idempotent)
    final saved = storage.getSavedTripSettlements(tripId);
    saved.removeWhere((s) => s['id'] == id);
    saved.insert(0, payload);
    await storage.saveTripSettlements(tripId, saved);

    final payerDisplay = fromName ?? 'Member';
    final receiverDisplay = toName ?? 'Member';
    final formattedAmt = (amountInPaise / 100).toStringAsFixed(2);

    // Only save verification request locally if current user is the Receiver (Payee)
    final savedUser = storage.getSavedUser();
    final currentUserId = savedUser != null ? savedUser['id'] as String? : null;
    if (currentUserId != null && toUserId != null && currentUserId == toUserId) {
      final verificationPayload = {
        'id': 'pvr_$id',
        'settlementId': id,
        'tripId': tripId,
        'tripName': tripName ?? 'Trip',
        'payerMemberId': fromMemberId,
        'payerUserId': fromUserId,
        'payerName': payerDisplay,
        'receiverMemberId': toMemberId,
        'receiverUserId': toUserId,
        'receiverName': receiverDisplay,
        'amountInPaise': amountInPaise,
        'paymentMethod': recipientUpiId != null && recipientUpiId.contains('@') ? 'UPI' : 'Direct',
        'paymentReference': paymentReference,
        'recipientUpiId': recipientUpiId,
        'note': note,
        'status': isActuallyPaid ? 'confirmed' : 'pending_verification',
        'markedAt': DateTime.now().toIso8601String(),
      };
      await storage.addPaymentVerification(verificationPayload);
    }

    _logLocalActivity(
      tripId: tripId,
      type: 'settlement_recorded',
      description: isActuallyPaid
          ? '$payerDisplay paid ₹$formattedAmt to $receiverDisplay'
          : '$payerDisplay marked ₹$formattedAmt as paid to $receiverDisplay (Pending confirmation)',
      metadata: {
        'settlementId': id,
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amountInPaise': amountInPaise,
        'paymentReference': paymentReference,
        'recipientUpiId': recipientUpiId,
        'status': paymentStatus,
      },
    );

    await syncService.enqueueMutation(
      MutationType.recordTripSettlement,
      payload,
      idempotencyKey: id,
      backgroundApiClient: apiClient,
    );
  }

  /// Confirm payment receipt by Receiver (Payee Handshake)
  Future<void> confirmSettlementVerification({
    required String tripId,
    required String verificationId,
    required String settlementId,
    String? receiverName,
    String? payerName,
    int? amountInPaise,
  }) async {
    // 1. Update verification request status
    await storage.updatePaymentVerificationStatus(verificationId, 'confirmed');

    // 2. Update settlement in local trip storage
    final settlements = storage.getSavedTripSettlements(tripId);
    final verifs = storage.getSavedPaymentVerifications();
    final v = verifs.where((x) => x['id'] == verificationId || x['settlementId'] == settlementId).firstOrNull;

    final payerMemId = v?['payerMemberId'] as String?;
    final receiverMemId = v?['receiverMemberId'] as String?;
    final payerUsrId = v?['payerUserId'] as String?;
    final receiverUsrId = v?['receiverUserId'] as String?;

    int idx = settlements.indexWhere((s) => s['id'] == settlementId || s['id'] == verificationId);
    if (idx == -1 && payerMemId != null && receiverMemId != null) {
      idx = settlements.indexWhere((s) => s['fromMemberId'] == payerMemId && s['toMemberId'] == receiverMemId);
    }

    final nowStr = DateTime.now().toIso8601String();
    if (idx != -1) {
      settlements[idx]['status'] = 'confirmed';
      settlements[idx]['isSettled'] = true;
      settlements[idx]['confirmedAt'] = nowStr;
    } else {
      settlements.insert(0, {
        'id': settlementId,
        'tripId': tripId,
        'fromMemberId': payerMemId,
        'toMemberId': receiverMemId,
        'fromUserId': payerUsrId,
        'toUserId': receiverUsrId,
        'fromName': payerName ?? v?['payerName'],
        'toName': receiverName ?? v?['receiverName'],
        'amountInPaise': amountInPaise ?? v?['amountInPaise'] ?? 0,
        'status': 'confirmed',
        'isSettled': true,
        'confirmedAt': nowStr,
        'createdAt': nowStr,
      });
    }
    await storage.saveTripSettlements(tripId, settlements);

    final rName = receiverName ?? 'Receiver';
    final pName = payerName ?? 'Payer';
    final amtStr = amountInPaise != null ? '₹${(amountInPaise / 100).toStringAsFixed(2)}' : 'payment';

    _logLocalActivity(
      tripId: tripId,
      type: 'settlement_confirmed',
      description: '$rName confirmed receiving $amtStr from $pName ✓',
      metadata: {
        'verificationId': verificationId,
        'settlementId': settlementId,
        'status': 'confirmed',
      },
    );

    await syncService.enqueueMutation(
      MutationType.confirmTripSettlement,
      {
        'settlementId': settlementId,
        'tripId': tripId,
        'status': 'confirmed',
        'isSettled': true,
        'verificationId': verificationId,
      },
      idempotencyKey: 'cnf_$verificationId',
      backgroundApiClient: apiClient,
    );

    // Drain background sync immediately
    unawaited(syncService.flushQueue(apiClient));
  }

  /// Dispute payment receipt by Receiver (Payee Handshake)
  Future<void> disputeSettlementVerification({
    required String tripId,
    required String verificationId,
    required String settlementId,
    String? receiverName,
    String? payerName,
    int? amountInPaise,
    String? reason,
  }) async {
    // 1. Update verification request status
    await storage.updatePaymentVerificationStatus(
      verificationId,
      'disputed',
      reason: reason ?? 'Marked not received by payee',
    );

    // 2. Revert settlement in local trip storage
    final settlements = storage.getSavedTripSettlements(tripId);
    final idx = settlements.indexWhere((s) => s['id'] == settlementId);
    if (idx != -1) {
      settlements[idx]['status'] = 'disputed';
      settlements[idx]['isSettled'] = false;
      settlements[idx]['disputedAt'] = DateTime.now().toIso8601String();
      settlements[idx]['disputeReason'] = reason;
      await storage.saveTripSettlements(tripId, settlements);
    }

    final rName = receiverName ?? 'Receiver';
    final pName = payerName ?? 'Payer';
    final amtStr = amountInPaise != null ? '₹${(amountInPaise / 100).toStringAsFixed(2)}' : 'payment';

    _logLocalActivity(
      tripId: tripId,
      type: 'settlement_disputed',
      description: '$rName reported that $amtStr was NOT received from $pName',
      metadata: {
        'verificationId': verificationId,
        'settlementId': settlementId,
        'status': 'disputed',
        'reason': reason,
      },
    );

    await syncService.enqueueMutation(
      MutationType.disputeTripSettlement,
      {
        'settlementId': settlementId,
        'tripId': tripId,
        'reason': reason,
        'verificationId': verificationId,
      },
      idempotencyKey: 'dsp_$verificationId',
      backgroundApiClient: apiClient,
    );
  }

  /// Submit payment proof for disputed or pending settlement (by Payer)
  Future<void> submitSettlementProof({
    required String tripId,
    required String verificationId,
    required String settlementId,
    String? receiverName,
    String? payerName,
    int? amountInPaise,
    String? transactionRef,
    String? proofImageUrl,
    String? proofNote,
  }) async {
    // 1. Update verification request status & proof in local storage
    await storage.updatePaymentVerificationStatus(
      verificationId,
      'proof_submitted',
      transactionRef: transactionRef,
      proofImageUrl: proofImageUrl,
      proofNote: proofNote,
    );

    // 2. Update settlement in local trip storage
    final settlements = storage.getSavedTripSettlements(tripId);
    final idx = settlements.indexWhere((s) => s['id'] == settlementId);
    if (idx != -1) {
      settlements[idx]['status'] = 'proof_submitted';
      settlements[idx]['isSettled'] = false;
      settlements[idx]['transactionRef'] = transactionRef;
      settlements[idx]['proofImageUrl'] = proofImageUrl;
      settlements[idx]['proofNote'] = proofNote;
      settlements[idx]['proofSubmittedAt'] = DateTime.now().toIso8601String();
      await storage.saveTripSettlements(tripId, settlements);
    }

    final rName = receiverName ?? 'Receiver';
    final pName = payerName ?? 'Payer';
    final amtStr = amountInPaise != null ? '₹${(amountInPaise / 100).toStringAsFixed(2)}' : 'payment';

    _logLocalActivity(
      tripId: tripId,
      type: 'payment_proof_submitted',
      description: '$pName submitted payment proof for $amtStr to $rName',
      metadata: {
        'verificationId': verificationId,
        'settlementId': settlementId,
        'transactionRef': transactionRef,
        'status': 'proof_submitted',
      },
    );

    await syncService.enqueueMutation(
      MutationType.submitSettlementProof,
      {
        'settlementId': settlementId,
        'tripId': tripId,
        'transactionRef': transactionRef,
        'proofImageUrl': proofImageUrl,
        'proofNote': proofNote,
        'verificationId': verificationId,
      },
      idempotencyKey: 'prf_$verificationId',
      backgroundApiClient: apiClient,
    );
  }


  void _logLocalActivity({
    required String tripId,
    required String type,
    required String description,
    required Map<String, dynamic> metadata,
  }) {
    final raw = storage.getSavedActivityLogs(tripId);
    final now = DateTime.now();
    final log = {
      'id': 'act_loc_${now.millisecondsSinceEpoch}',
      'tripId': tripId,
      'type': type,
      'actorId': metadata['actorId'] ?? '',
      'actorName': metadata['actorName'] ?? 'You',
      'description': description,
      'metadata': metadata,
      'createdAt': now.toIso8601String(),
    };
    raw.insert(0, log);
    storage.saveActivityLogs(tripId, raw);
  }
}
