import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../../domain/engine/balance_engine.dart';
import '../../domain/engine/money_engine.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/enums/split_type.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_split.dart';
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

    final raw = storage.getSavedExpenses(tripId);
    return raw.map((json) => Expense.fromJson(json)).toList();
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
        final currentExpenses = await getExpenses(expense.tripId);
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

    final currentExpenses = await getExpenses(expense.tripId);
    currentExpenses.insert(0, expense);

    await storage.saveExpenses(
      expense.tripId,
      currentExpenses.map((e) => e.toJson()).toList(),
    );

    await syncService.enqueueMutation(
      MutationType.addExpense,
      expense.toJson(),
    );

    return expense;
  }

  /// Deletes or soft-deletes an expense.
  Future<void> deleteExpense({
    required String tripId,
    required String expenseId,
  }) async {
    try {
      await apiClient.delete('/trips/$tripId/expenses/$expenseId');
    } catch (_) {
      await syncService.enqueueMutation(
        MutationType.deleteExpense,
        {'tripId': tripId, 'expenseId': expenseId},
      );
    }

    final currentExpenses = await getExpenses(tripId);
    final index = currentExpenses.indexWhere((e) => e.id == expenseId);
    if (index != -1) {
      currentExpenses.removeAt(index);
      await storage.saveExpenses(
        tripId,
        currentExpenses.map((e) => e.toJson()).toList(),
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

    final expenses = await getExpenses(trip.id);
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
    String? paymentReference,
    String? note,
  }) async {
    // 1. Create a zero-sum settlement expense locally
    final settlementExpense = Expense(
      id: 'settlement_${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      title: 'Settlement Payment',
      amountInPaise: amountInPaise,
      category: ExpenseCategory.general,
      paidById: fromMemberId,
      splits: [
        ExpenseSplit(
          memberId: toMemberId,
          amountInPaise: amountInPaise,
        ),
      ],
      splitType: SplitType.exact,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final currentExpenses = await getExpenses(tripId);
    currentExpenses.insert(0, settlementExpense);
    await storage.saveExpenses(
      tripId,
      currentExpenses.map((e) => e.toJson()).toList(),
    );

    // 2. Transmit to remote or enqueue offline mutation
    try {
      await apiClient.post(
        '/trips/$tripId/settlements',
        body: {
          'fromMemberId': fromMemberId,
          'toMemberId': toMemberId,
          'amountInPaise': amountInPaise,
          'paymentReference': paymentReference,
          'note': note,
        },
      );
    } catch (_) {
      await syncService.enqueueMutation(
        MutationType.addExpense,
        settlementExpense.toJson(),
      );
    }
  }
}
