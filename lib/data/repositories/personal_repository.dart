import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/models/personal_budget.dart';
import '../../domain/models/personal_debt.dart';
import '../../domain/models/personal_expense.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

class PersonalRepository {
  final LocalStorageService storage;
  final SyncService syncService;
  final ApiClient apiClient;

  PersonalRepository({
    required this.storage,
    required this.syncService,
    required this.apiClient,
  });

  // ==========================================
  // 1. Personal Expenses
  // ==========================================

  List<PersonalExpense> getCachedPersonalExpenses({
    DateTime? startDate,
    DateTime? endDate,
    ExpenseCategory? category,
  }) {
    final rawList = storage.getSavedPersonalExpenses();
    var list = rawList
        .map((j) => PersonalExpense.fromJson(j))
        .where((e) => !e.isDeleted)
        .toList();

    if (startDate != null) {
      list = list.where((e) => e.date.isAfter(startDate) || e.date.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      list = list.where((e) => e.date.isBefore(endDate) || e.date.isAtSameMomentAs(endDate)).toList();
    }
    if (category != null && category != ExpenseCategory.general) {
      list = list.where((e) => e.category == category).toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<PersonalExpense>> getPersonalExpenses({
    DateTime? startDate,
    DateTime? endDate,
    ExpenseCategory? category,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (category != null) queryParams['category'] = category.name;

      final res = await apiClient.get('/personal/expenses', queryParams: queryParams);
      if (res is Map<String, dynamic> && res['expenses'] is List) {
        final list = (res['expenses'] as List)
            .map((j) => PersonalExpense.fromJson(j as Map<String, dynamic>))
            .toList();

        // Update local storage
        await storage.savePersonalExpenses(list.map((e) => e.toJson()).toList());
        return list;
      }
    } catch (_) {
      // Offline fallback
    }
    return getCachedPersonalExpenses(
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
  }

  Future<PersonalExpense> createPersonalExpense({
    required String userId,
    required String title,
    required int amountInPaise,
    ExpenseCategory category = ExpenseCategory.general,
    DateTime? date,
    String? notes,
    String? voiceTranscript,
    String? receiptUrl,
  }) async {
    final id = 'pexp_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}';
    final now = DateTime.now();

    final expense = PersonalExpense(
      id: id,
      userId: userId,
      title: title,
      amountInPaise: amountInPaise,
      category: category,
      date: date ?? now,
      notes: notes,
      voiceTranscript: voiceTranscript,
      receiptUrl: receiptUrl,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Save locally immediately (< 2ms)
    final cached = getCachedPersonalExpenses();
    cached.insert(0, expense);
    await storage.savePersonalExpenses(cached.map((e) => e.toJson()).toList());

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.createPersonalExpense,
      expense.toJson(),
      idempotencyKey: expense.id,
      backgroundApiClient: apiClient,
    );

    return expense;
  }

  Future<PersonalExpense> updatePersonalExpense(PersonalExpense expense) async {
    // 1. Update locally
    final cached = getCachedPersonalExpenses();
    final index = cached.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      cached[index] = expense;
      await storage.savePersonalExpenses(cached.map((e) => e.toJson()).toList());
    }

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.updatePersonalExpense,
      expense.toJson(),
      idempotencyKey: expense.id,
      backgroundApiClient: apiClient,
    );

    return expense;
  }

  Future<void> deletePersonalExpense(String expenseId) async {
    // 1. Remove locally
    final cached = getCachedPersonalExpenses();
    cached.removeWhere((e) => e.id == expenseId);
    await storage.savePersonalExpenses(cached.map((e) => e.toJson()).toList());

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.deletePersonalExpense,
      {'id': expenseId},
      idempotencyKey: 'del_pexp_$expenseId',
      backgroundApiClient: apiClient,
    );
  }

  // ==========================================
  // 2. Personal Debts (Lending & Borrowing)
  // ==========================================

  PersonalDebtsSummary getCachedPersonalDebts() {
    final rawList = storage.getSavedPersonalDebts();
    final list = rawList
        .map((j) => PersonalDebt.fromJson(j))
        .where((d) => !d.isDeleted)
        .toList();

    int totalLent = 0;
    int totalBorrowed = 0;

    for (final d in list) {
      if (!d.isSettled) {
        if (d.debtType == PersonalDebtType.lent) {
          totalLent += d.remainingAmountInPaise;
        } else {
          totalBorrowed += d.remainingAmountInPaise;
        }
      }
    }

    return PersonalDebtsSummary(
      debts: list,
      totalLentPaise: totalLent,
      totalBorrowedPaise: totalBorrowed,
      netBalancePaise: totalLent - totalBorrowed,
    );
  }

  Future<PersonalDebtsSummary> getPersonalDebts() async {
    try {
      final res = await apiClient.get('/personal/debts');
      if (res is Map<String, dynamic>) {
        final summary = PersonalDebtsSummary.fromJson(res);
        await storage.savePersonalDebts(summary.debts.map((d) => d.toJson()).toList());
        return summary;
      }
    } catch (_) {
      // Offline fallback
    }
    return getCachedPersonalDebts();
  }

  Future<PersonalDebt> createPersonalDebt({
    required String userId,
    required String personName,
    required PersonalDebtType debtType,
    required int amountInPaise,
    String? description,
    DateTime? date,
    DateTime? dueDate,
  }) async {
    final id = 'pdebt_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}';
    final now = DateTime.now();

    final debt = PersonalDebt(
      id: id,
      userId: userId,
      personName: personName,
      debtType: debtType,
      initialAmountInPaise: amountInPaise,
      remainingAmountInPaise: amountInPaise,
      description: description,
      date: date ?? now,
      dueDate: dueDate,
      isSettled: false,
      isDeleted: false,
      repayments: const [],
      createdAt: now,
      updatedAt: now,
    );

    // 1. Save locally
    final cached = getCachedPersonalDebts().debts;
    cached.insert(0, debt);
    await storage.savePersonalDebts(cached.map((d) => d.toJson()).toList());

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.createPersonalDebt,
      debt.toJson(),
      idempotencyKey: debt.id,
      backgroundApiClient: apiClient,
    );

    return debt;
  }

  Future<PersonalDebt> recordDebtRepayment({
    required String userId,
    required String debtId,
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    final repaymentId = 'prepay_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}';
    final now = DateTime.now();

    final repayment = PersonalRepayment(
      id: repaymentId,
      debtId: debtId,
      userId: userId,
      amountInPaise: amountInPaise,
      date: date ?? now,
      note: note,
      createdAt: now,
    );

    // 1. Update locally
    final cachedDebts = getCachedPersonalDebts().debts;
    final index = cachedDebts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final existing = cachedDebts[index];
      final newRepayments = List<PersonalRepayment>.from(existing.repayments)..add(repayment);
      final totalRepaid = newRepayments.fold<int>(0, (sum, r) => sum + r.amountInPaise);
      final remaining = (existing.initialAmountInPaise - totalRepaid).clamp(0, existing.initialAmountInPaise);
      final isSettled = remaining == 0;

      final updatedDebt = existing.copyWith(
        remainingAmountInPaise: remaining,
        isSettled: isSettled,
        repayments: newRepayments,
        updatedAt: now,
      );
      cachedDebts[index] = updatedDebt;
      await storage.savePersonalDebts(cachedDebts.map((d) => d.toJson()).toList());
    }

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.recordPersonalRepayment,
      {
        'id': repaymentId,
        'debtId': debtId,
        'amountInPaise': amountInPaise,
        'note': note,
        'date': (date ?? now).toIso8601String(),
      },
      idempotencyKey: repaymentId,
      backgroundApiClient: apiClient,
    );

    return cachedDebts[index];
  }

  Future<PersonalDebt> updatePersonalDebt(PersonalDebt debt) async {
    final cached = getCachedPersonalDebts().debts;
    final index = cached.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      cached[index] = debt;
      await storage.savePersonalDebts(cached.map((d) => d.toJson()).toList());
    }

    await syncService.enqueueMutation(
      MutationType.updatePersonalDebt,
      debt.toJson(),
      idempotencyKey: 'upd_pdebt_${debt.id}',
      backgroundApiClient: apiClient,
    );

    return debt;
  }

  Future<void> deletePersonalDebt(String debtId) async {
    // 1. Remove locally
    final cached = getCachedPersonalDebts().debts;
    cached.removeWhere((d) => d.id == debtId);
    await storage.savePersonalDebts(cached.map((d) => d.toJson()).toList());

    // 2. Push to background sync queue
    await syncService.enqueueMutation(
      MutationType.deletePersonalDebt,
      {'id': debtId},
      idempotencyKey: 'del_pdebt_$debtId',
      backgroundApiClient: apiClient,
    );
  }

  // ==========================================
  // 3. Personal Budgets
  // ==========================================

  PersonalBudget getCachedPersonalBudget(String monthYear) {
    final raw = storage.getSavedPersonalBudget(monthYear);
    if (raw != null) {
      return PersonalBudget.fromJson(raw);
    }
    return PersonalBudget.empty(monthYear);
  }

  Future<PersonalBudget> getPersonalBudget(String monthYear) async {
    try {
      final res = await apiClient.get('/personal/budget', queryParams: {'month': monthYear});
      if (res is Map<String, dynamic>) {
        final budget = PersonalBudget.fromJson(res);
        await storage.savePersonalBudget(monthYear, budget.toJson());
        return budget;
      }
    } catch (_) {
      // Offline fallback
    }
    return getCachedPersonalBudget(monthYear);
  }

  Future<PersonalBudget> setPersonalBudget(String monthYear, int limitInPaise) async {
    final cachedExpenses = getCachedPersonalExpenses();
    final monthPrefix = monthYear; // "YYYY-MM"

    final spent = cachedExpenses
        .where((e) => e.date.toIso8601String().startsWith(monthPrefix))
        .fold<int>(0, (sum, e) => sum + e.amountInPaise);

    final budget = PersonalBudget(
      monthYear: monthYear,
      monthlyLimitInPaise: limitInPaise,
      spentInPaise: spent,
      remainingInPaise: (limitInPaise - spent).clamp(0, limitInPaise),
      hasBudget: limitInPaise > 0,
      percentageUsed: limitInPaise > 0 ? ((spent / limitInPaise) * 100).round().clamp(0, 100) : 0,
    );

    await storage.savePersonalBudget(monthYear, budget.toJson());

    await syncService.enqueueMutation(
      MutationType.setPersonalBudget,
      {'monthYear': monthYear, 'monthlyLimitInPaise': limitInPaise},
      idempotencyKey: 'budget_$monthYear',
      backgroundApiClient: apiClient,
    );

    return budget;
  }
}

