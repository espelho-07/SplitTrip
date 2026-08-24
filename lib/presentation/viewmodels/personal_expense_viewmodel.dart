import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import '../../data/repositories/personal_repository.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/models/personal_budget.dart';
import '../../domain/models/personal_debt.dart';
import '../../domain/models/personal_expense.dart';

enum PersonalTimeFilter {
  today,
  thisWeek,
  thisMonth,
  custom;

  String get label {
    switch (this) {
      case PersonalTimeFilter.today:
        return 'Today';
      case PersonalTimeFilter.thisWeek:
        return 'This week';
      case PersonalTimeFilter.thisMonth:
        return 'This month';
      case PersonalTimeFilter.custom:
        return 'Custom';
    }
  }
}

class PersonalExpenseViewModel extends ChangeNotifier {
  final PersonalRepository personalRepo;

  PersonalExpenseViewModel({required this.personalRepo});

  PersonalTimeFilter _timeFilter = PersonalTimeFilter.thisMonth;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTimeRange? _customDateRange;

  List<PersonalExpense> _expenses = [];
  PersonalDebtsSummary _debtsSummary = PersonalDebtsSummary.empty();
  PersonalBudget _budget = PersonalBudget.empty(
    '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
  );

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Getters
  PersonalTimeFilter get timeFilter => _timeFilter;
  DateTime get selectedMonth => _selectedMonth;
  DateTimeRange? get customDateRange => _customDateRange;
  List<PersonalExpense> get expenses => _expenses;
  PersonalDebtsSummary get debtsSummary => _debtsSummary;
  PersonalBudget get budget => _budget;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  String get currentMonthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  // --- Filtering & Navigation ---
  void setTimeFilter(PersonalTimeFilter filter) {
    if (_timeFilter == filter) return;
    _timeFilter = filter;
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    _timeFilter = PersonalTimeFilter.thisMonth;
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    _timeFilter = PersonalTimeFilter.thisMonth;
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void setCustomDateRange(DateTimeRange range) {
    _customDateRange = range;
    _timeFilter = PersonalTimeFilter.custom;
    _applyFilterAndCalculate();
  }

  // --- Calculations ---
  int get totalSpentInPaise {
    return _filteredExpenses.fold<int>(0, (sum, e) => sum + e.amountInPaise);
  }

  int get averageSpentPerDayInPaise {
    if (_filteredExpenses.isEmpty) return 0;
    final now = DateTime.now();
    int days;

    switch (_timeFilter) {
      case PersonalTimeFilter.today:
        days = 1;
        break;
      case PersonalTimeFilter.thisWeek:
        days = (now.weekday).clamp(1, 7);
        break;
      case PersonalTimeFilter.thisMonth:
        // If current month, use elapsed days; if past month, use total days in that month
        final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
        if (isCurrentMonth) {
          days = now.day.clamp(1, 31);
        } else {
          days = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
        }
        break;
      case PersonalTimeFilter.custom:
        if (_customDateRange != null) {
          days = _customDateRange!.duration.inDays + 1;
        } else {
          days = 1;
        }
        break;
    }

    if (days <= 0) days = 1;
    return (totalSpentInPaise / days).round();
  }

  Map<ExpenseCategory, int> get categoryTotalsInPaise {
    final map = <ExpenseCategory, int>{};
    for (final e in _filteredExpenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amountInPaise;
    }
    return map;
  }

  List<PersonalExpense> get filteredExpenses => _filteredExpenses;

  List<PersonalExpense> get _filteredExpenses {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_timeFilter) {
      case PersonalTimeFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PersonalTimeFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PersonalTimeFilter.thisMonth:
        start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
        break;
      case PersonalTimeFilter.custom:
        if (_customDateRange != null) {
          start = _customDateRange!.start;
          end = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
        } else {
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
        break;
    }

    return _expenses.where((e) {
      return (e.date.isAfter(start) || e.date.isAtSameMomentAs(start)) &&
          (e.date.isBefore(end) || e.date.isAtSameMomentAs(end));
    }).toList();
  }

  void _applyFilterAndCalculate() {
    _refreshBudgetCalculation();
    notifyListeners();
  }

  void _refreshBudgetCalculation() {
    if (_budget.hasBudget && _budget.monthlyLimitInPaise > 0) {
      final monthPrefix = currentMonthKey;
      final monthSpent = _expenses
          .where((e) => e.date.toIso8601String().startsWith(monthPrefix))
          .fold<int>(0, (sum, e) => sum + e.amountInPaise);

      final remaining = _budget.monthlyLimitInPaise - monthSpent;
      final percentage = ((monthSpent / _budget.monthlyLimitInPaise) * 100).round();

      _budget = PersonalBudget(
        monthYear: currentMonthKey,
        monthlyLimitInPaise: _budget.monthlyLimitInPaise,
        spentInPaise: monthSpent,
        remainingInPaise: remaining,
        hasBudget: true,
        percentageUsed: percentage,
      );
    }
  }

  // --- Data Loading ---
  Future<void> loadData(String userId) async {
    // 1. FAST LOCAL HYDRATION (< 5ms)
    _expenses = personalRepo.getCachedPersonalExpenses();
    _debtsSummary = personalRepo.getCachedPersonalDebts();
    _budget = personalRepo.getCachedPersonalBudget(currentMonthKey);
    _refreshBudgetCalculation();
    notifyListeners();

    _isLoading = _expenses.isEmpty && _debtsSummary.debts.isEmpty;
    _errorMessage = null;

    try {
      final remoteExpenses = await personalRepo.getPersonalExpenses();
      final remoteDebts = await personalRepo.getPersonalDebts();
      final remoteBudget = await personalRepo.getPersonalBudget(currentMonthKey);

      _expenses = remoteExpenses;
      _debtsSummary = remoteDebts;
      _budget = remoteBudget;
      _refreshBudgetCalculation();
    } catch (e) {
      if (_expenses.isEmpty) {
        _errorMessage = 'Operating offline. Saved data loaded.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Mutations ---
  Future<PersonalExpense?> addExpense({
    required String userId,
    required String title,
    required int amountInPaise,
    ExpenseCategory category = ExpenseCategory.general,
    DateTime? date,
    String? notes,
    String? voiceTranscript,
  }) async {
    if (_isSaving) return null;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final expense = await personalRepo.createPersonalExpense(
        userId: userId,
        title: title,
        amountInPaise: amountInPaise,
        category: category,
        date: date,
        notes: notes,
        voiceTranscript: voiceTranscript,
      );

      _expenses.insert(0, expense);
      _applyFilterAndCalculate();
      HapticHelper.success();
      return expense;
    } catch (e) {
      _errorMessage = 'Could not save expense. Please retry.';
      HapticHelper.error();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateExpense(PersonalExpense expense) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    try {
      await personalRepo.updatePersonalExpense(expense);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
      }
      _applyFilterAndCalculate();
      HapticHelper.success();
      return true;
    } catch (e) {
      _errorMessage = 'Could not update expense.';
      HapticHelper.error();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      await personalRepo.deletePersonalExpense(expenseId);
      _expenses.removeWhere((e) => e.id == expenseId);
      _applyFilterAndCalculate();
      HapticHelper.medium();
      return true;
    } catch (e) {
      _errorMessage = 'Could not delete expense.';
      return false;
    }
  }

  // --- Lending & Borrowing ---
  Future<PersonalDebt?> addDebt({
    required String userId,
    required String personName,
    required PersonalDebtType debtType,
    required int amountInPaise,
    String? description,
    DateTime? date,
    DateTime? dueDate,
  }) async {
    if (_isSaving) return null;
    _isSaving = true;
    notifyListeners();

    try {
      final debt = await personalRepo.createPersonalDebt(
        userId: userId,
        personName: personName,
        debtType: debtType,
        amountInPaise: amountInPaise,
        description: description,
        date: date,
        dueDate: dueDate,
      );

      _debtsSummary = personalRepo.getCachedPersonalDebts();
      HapticHelper.success();
      return debt;
    } catch (e) {
      _errorMessage = 'Could not save lending record.';
      HapticHelper.error();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> recordRepayment({
    required String userId,
    required String debtId,
    required int amountInPaise,
    String? note,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    try {
      await personalRepo.recordDebtRepayment(
        userId: userId,
        debtId: debtId,
        amountInPaise: amountInPaise,
        note: note,
      );

      _debtsSummary = personalRepo.getCachedPersonalDebts();
      HapticHelper.success();
      return true;
    } catch (e) {
      _errorMessage = 'Could not record repayment.';
      HapticHelper.error();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    try {
      await personalRepo.deletePersonalDebt(debtId);
      _debtsSummary = personalRepo.getCachedPersonalDebts();
      HapticHelper.medium();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Budget ---
  Future<bool> setMonthlyBudget(int limitInPaise) async {
    try {
      _budget = await personalRepo.setPersonalBudget(currentMonthKey, limitInPaise);
      _refreshBudgetCalculation();
      HapticHelper.success();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not set monthly budget.';
      return false;
    }
  }
}
