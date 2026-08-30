import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/engine/balance_engine.dart';
import '../../domain/engine/money_engine.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

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

  /// Synchronously returns cached expenses for a trip without network latency.
  List<Expense> getCachedExpenses(String tripId) {
    final raw = storage.getSavedExpenses(tripId);
    return raw.map((json) => Expense.fromJson(json)).toList();
  }

  /// Loads all expenses recorded for a specific trip.
  Future<List<Expense>> getExpenses(String tripId) async {
    try {
      final res = await apiClient.get('/trips/$tripId/expenses');
      if (res is List) {
        final expenses = res.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList();
        await storage.saveExpenses(tripId, expenses.map((e) => e.toJson()).toList());
        return expenses;
      }
    } catch (_) {
      // Offline fallback
    }

    return getCachedExpenses(tripId);
  }

  /// Adds a new expense to the trip after verifying deterministic zero-sum split equality.
  Future<Expense> addExpense(Expense expense) async {
    // Deterministic client-side validation
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
    }

    // 1. FAST LOCAL HYDRATION: Write to local persistent cache instantly (< 5ms)
    final currentExpenses = getCachedExpenses(expense.tripId);
    currentExpenses.removeWhere((e) => e.id == expense.id);
    currentExpenses.insert(0, expense);

    await storage.saveExpenses(
      expense.tripId,
      currentExpenses.map((e) => e.toJson()).toList(),
    );

    _logLocalActivity(
      tripId: expense.tripId,
      type: 'expense_added',
      description: 'Added "${expense.title}" for ₹${(expense.amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {'expenseId': expense.id, 'amountInPaise': expense.amountInPaise},
    );

    // 2. Enqueue mutation and trigger non-blocking background network synchronization
    await syncService.enqueueMutation(
      MutationType.addExpense,
      expense.toJson(),
      idempotencyKey: expense.id,
      backgroundApiClient: apiClient,
    );

    return expense;
  }

  /// Updates an existing expense after verifying deterministic zero-sum split equality.
  Future<Expense> updateExpense(Expense expense) async {
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
    }

    // 1. Update local persistent cache instantly
    final currentExpenses = getCachedExpenses(expense.tripId);
    final idx = currentExpenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      currentExpenses[idx] = expense;
    } else {
      currentExpenses.insert(0, expense);
    }

    await storage.saveExpenses(
      expense.tripId,
      currentExpenses.map((e) => e.toJson()).toList(),
    );

    _logLocalActivity(
      tripId: expense.tripId,
      type: 'expense_updated',
      description: 'Updated "${expense.title}" for ₹${(expense.amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {'expenseId': expense.id, 'amountInPaise': expense.amountInPaise},
    );

    // 2. Enqueue mutation and trigger non-blocking background network synchronization
    await syncService.enqueueMutation(
      MutationType.updateExpense,
      expense.toJson(),
      idempotencyKey: expense.id,
      backgroundApiClient: apiClient,
    );

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
      await storage.saveExpenses(
        tripId,
        currentExpenses.map((e) => e.toJson()).toList(),
      );
    }

    _logLocalActivity(
      tripId: tripId,
      type: 'expense_deleted',
      description: 'Deleted expense "$deletedTitle"',
      metadata: {'expenseId': expenseId},
    );

    await syncService.enqueueMutation(
      MutationType.deleteExpense,
      {'tripId': tripId, 'expenseId': expenseId},
      idempotencyKey: 'del_$expenseId',
      backgroundApiClient: apiClient,
    );
  }

  /// Computes the live balance summary for a trip.
  Future<BalanceSummary> getBalanceSummary({
    required Trip trip,
    required String currentUserId,
  }) async {
    final savedSettlements = storage.getSavedTripSettlements(trip.id);
    try {
      final res = await apiClient.get('/trips/${trip.id}/expenses/balance/summary');
      if (res is Map<String, dynamic>) {
        final serverSummary = BalanceSummary.fromJson(res);
        if (savedSettlements.isEmpty) {
          return serverSummary;
        }
      }
    } catch (_) {
      // Offline fallback
    }

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
    String paymentStatus = 'paid',
    String? tripName,
    String? fromUserId,
    String? toUserId,
  }) async {
    final id = settlementId ?? 'stl_loc_${DateTime.now().millisecondsSinceEpoch}';
    final isActuallyPaid = paymentStatus == 'paid' || paymentStatus == 'completed' || paymentStatus == 'manual_settled';
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

    // If marked as pending verification or paid by Payer, register a verification request
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
    final idx = settlements.indexWhere((s) => s['id'] == settlementId);
    if (idx != -1) {
      settlements[idx]['status'] = 'paid';
      settlements[idx]['isSettled'] = true;
      settlements[idx]['confirmedAt'] = DateTime.now().toIso8601String();
      await storage.saveTripSettlements(tripId, settlements);
    }

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
      MutationType.recordTripSettlement,
      {
        'id': settlementId,
        'tripId': tripId,
        'status': 'paid',
        'isSettled': true,
        'verificationId': verificationId,
      },
      idempotencyKey: 'cnf_$verificationId',
      backgroundApiClient: apiClient,
    );
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
      MutationType.recordTripSettlement,
      {
        'id': settlementId,
        'tripId': tripId,
        'status': 'disputed',
        'isSettled': false,
        'verificationId': verificationId,
      },
      idempotencyKey: 'dsp_$verificationId',
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
