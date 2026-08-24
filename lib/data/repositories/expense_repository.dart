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

  ExpenseRepository({
    required this.storage,
    required this.syncService,
  });

  /// Loads all expenses recorded for a specific trip.
  Future<List<Expense>> getExpenses(String tripId) async {
    final raw = storage.getSavedExpenses(tripId);
    return raw.map((json) => Expense.fromJson(json)).toList();
  }

  /// Adds a new expense to the trip after verifying deterministic zero-sum split equality.
  Future<Expense> addExpense(Expense expense) async {
    // Deterministic validation
    final isValid = MoneyEngine.validateSplits(expense.amountInPaise, expense.splits);
    if (!isValid) {
      throw ArgumentError('The sum of expense splits must strictly equal the total expense amount');
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
    final currentExpenses = await getExpenses(tripId);
    final index = currentExpenses.indexWhere((e) => e.id == expenseId);
    if (index != -1) {
      currentExpenses.removeAt(index);
      await storage.saveExpenses(
        tripId,
        currentExpenses.map((e) => e.toJson()).toList(),
      );

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
    final expenses = await getExpenses(trip.id);
    return BalanceEngine.calculateBalances(
      members: trip.members,
      expenses: expenses,
      currentUserId: currentUserId,
    );
  }
}
