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

    try {
      final res = await apiClient.post(
        '/trips/${expense.tripId}/expenses',
        body: expense.toJson(),
      );

      if (res is Map<String, dynamic> && res.containsKey('expense')) {
        final savedExpense = Expense.fromJson(res['expense'] as Map<String, dynamic>);
        final currentExpenses = getCachedExpenses(expense.tripId);
        currentExpenses.removeWhere((e) => e.id == savedExpense.id);
        currentExpenses.insert(0, savedExpense);
        await storage.saveExpenses(
          expense.tripId,
          currentExpenses.map((e) => e.toJson()).toList(),
        );
        return savedExpense;
      }
    } catch (_) {
      // Offline fallback: save locally and queue sync mutation
    }

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

    await syncService.enqueueMutation(
      MutationType.addExpense,
      expense.toJson(),
    );

    return expense;
  }

  /// Updates an existing expense after verifying deterministic zero-sum split equality.
  Future<Expense> updateExpense(Expense expense) async {
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
    }

    try {
      final res = await apiClient.put(
        '/trips/${expense.tripId}/expenses/${expense.id}',
        body: expense.toJson(),
      );

      if (res is Map<String, dynamic> && res.containsKey('expense')) {
        final savedExpense = Expense.fromJson(res['expense'] as Map<String, dynamic>);
        final currentExpenses = getCachedExpenses(expense.tripId);
        final idx = currentExpenses.indexWhere((e) => e.id == savedExpense.id);
        if (idx != -1) {
          currentExpenses[idx] = savedExpense;
          await storage.saveExpenses(
            expense.tripId,
            currentExpenses.map((e) => e.toJson()).toList(),
          );
        }
        _logLocalActivity(
          tripId: expense.tripId,
          type: 'expense_updated',
          description: 'Updated "${savedExpense.title}" for ₹${(savedExpense.amountInPaise / 100).toStringAsFixed(2)}',
          metadata: {'expenseId': savedExpense.id, 'amountInPaise': savedExpense.amountInPaise},
        );
        return savedExpense;
      }
    } catch (_) {
      // Offline fallback
    }

    final currentExpenses = getCachedExpenses(expense.tripId);
    final idx = currentExpenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      currentExpenses[idx] = expense;
      await storage.saveExpenses(
        expense.tripId,
        currentExpenses.map((e) => e.toJson()).toList(),
      );
    }

    _logLocalActivity(
      tripId: expense.tripId,
      type: 'expense_updated',
      description: 'Updated "${expense.title}" for ₹${(expense.amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {'expenseId': expense.id, 'amountInPaise': expense.amountInPaise},
    );

    await syncService.enqueueMutation(
      MutationType.updateExpense,
      expense.toJson(),
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

    try {
      await apiClient.delete('/trips/$tripId/expenses/$expenseId');
    } catch (_) {
      await syncService.enqueueMutation(
        MutationType.deleteExpense,
        {'tripId': tripId, 'expenseId': expenseId},
      );
    }
  }

  /// Computes the live balance summary for a trip.
  Future<BalanceSummary> getBalanceSummary({
    required Trip trip,
    required String currentUserId,
  }) async {
    try {
      final res = await apiClient.get('/trips/${trip.id}/expenses/balance/summary');
      if (res is Map<String, dynamic>) {
        return BalanceSummary.fromJson(res);
      }
    } catch (_) {
      // Offline fallback
    }

    final expenses = getCachedExpenses(trip.id);
    return BalanceEngine.calculateBalances(
      members: trip.members,
      expenses: expenses,
      currentUserId: currentUserId,
    );
  }

  /// Records a direct settlement payment between two members.
  Future<void> recordSettlement({
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    required int amountInPaise,
    String? settlementId,
    String? paymentReference,
    String? note,
  }) async {
    final id = settlementId ?? 'stl_loc_${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id': id,
      'tripId': tripId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'amountInPaise': amountInPaise,
      'paymentReference': paymentReference,
      'note': note,
      'isSettled': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Save locally
    final saved = storage.getSavedTripSettlements(tripId);
    saved.removeWhere((s) => s['id'] == id);
    saved.insert(0, payload);
    await storage.saveTripSettlements(tripId, saved);

    _logLocalActivity(
      tripId: tripId,
      type: 'settlement_recorded',
      description: 'Payment settled for ₹${(amountInPaise / 100).toStringAsFixed(2)}',
      metadata: {
        'settlementId': id,
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amountInPaise': amountInPaise,
      },
    );

    try {
      await apiClient.post(
        '/trips/$tripId/settlements',
        body: payload,
      );
    } catch (_) {
      // Offline fallback: queue for sync
      await syncService.enqueueMutation(
        MutationType.recordTripSettlement,
        payload,
      );
    }
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
