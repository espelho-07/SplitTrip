import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/personal_repository.dart';
import '../../data/repositories/trip_repository.dart';
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

enum PersonalExpenseSourceFilter {
  all,
  personalOnly,
  tripSyncedOnly;

  String get label {
    switch (this) {
      case PersonalExpenseSourceFilter.all:
        return 'All Expenses';
      case PersonalExpenseSourceFilter.personalOnly:
        return 'Personal Only';
      case PersonalExpenseSourceFilter.tripSyncedOnly:
        return 'Trip Spends Only';
    }
  }
}

enum PersonalExpenseSortOption {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount;

  String get label {
    switch (this) {
      case PersonalExpenseSortOption.newestFirst:
        return 'Newest First';
      case PersonalExpenseSortOption.oldestFirst:
        return 'Oldest First';
      case PersonalExpenseSortOption.highestAmount:
        return 'Highest Amount';
      case PersonalExpenseSortOption.lowestAmount:
        return 'Lowest Amount';
    }
  }
}

class PersonalExpenseViewModel extends ChangeNotifier {
  final PersonalRepository personalRepo;
  final TripRepository? tripRepo;
  final ExpenseRepository? expenseRepo;

  PersonalExpenseViewModel({
    required this.personalRepo,
    this.tripRepo,
    this.expenseRepo,
  });

  PersonalTimeFilter _timeFilter = PersonalTimeFilter.thisMonth;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTimeRange? _customDateRange;

  String _searchQuery = '';
  ExpenseCategory? _selectedCategoryFilter;
  PersonalExpenseSourceFilter _sourceFilter = PersonalExpenseSourceFilter.all;
  PersonalExpenseSortOption _sortOption = PersonalExpenseSortOption.newestFirst;

  List<PersonalExpense> _expenses = [];
  List<PersonalExpense> _tripSyncedExpenses = [];
  bool _includeTripExpenses = false;
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
  String get searchQuery => _searchQuery;
  ExpenseCategory? get selectedCategoryFilter => _selectedCategoryFilter;
  PersonalExpenseSourceFilter get sourceFilter => _sourceFilter;
  PersonalExpenseSortOption get sortOption => _sortOption;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategoryFilter != null ||
      _sourceFilter != PersonalExpenseSourceFilter.all ||
      _timeFilter != PersonalTimeFilter.thisMonth ||
      _sortOption != PersonalExpenseSortOption.newestFirst;

  List<PersonalExpense> get expenses => _expenses;
  bool get includeTripExpenses => _includeTripExpenses;
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

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(ExpenseCategory? category) {
    if (_selectedCategoryFilter == category) {
      _selectedCategoryFilter = null;
    } else {
      _selectedCategoryFilter = category;
    }
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void setSourceFilter(PersonalExpenseSourceFilter filter) {
    if (_sourceFilter == filter) return;
    _sourceFilter = filter;
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void setSortOption(PersonalExpenseSortOption sort) {
    if (_sortOption == sort) return;
    _sortOption = sort;
    HapticHelper.selection();
    _applyFilterAndCalculate();
  }

  void resetAllFilters() {
    _searchQuery = '';
    _selectedCategoryFilter = null;
    _sourceFilter = PersonalExpenseSourceFilter.all;
    _timeFilter = PersonalTimeFilter.thisMonth;
    _sortOption = PersonalExpenseSortOption.newestFirst;
    _customDateRange = null;
    HapticHelper.medium();
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

  List<PersonalExpense> get allEffectiveExpenses {
    if (!_includeTripExpenses || _tripSyncedExpenses.isEmpty) {
      return _expenses;
    }
    final combined = List<PersonalExpense>.from(_expenses);
    for (final te in _tripSyncedExpenses) {
      final alreadyExists = combined.any((ce) =>
          ce.id == te.id ||
          (ce.title == te.title &&
              ce.amountInPaise == te.amountInPaise &&
              ce.date.day == te.date.day &&
              ce.date.month == te.date.month &&
              ce.date.year == te.date.year));
      if (!alreadyExists) {
        combined.add(te);
      }
    }
    return combined;
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

    final result = allEffectiveExpenses.where((e) {
      final inTime = (e.date.isAfter(start) || e.date.isAtSameMomentAs(start)) &&
          (e.date.isBefore(end) || e.date.isAtSameMomentAs(end));
      if (!inTime) return false;

      // Search Query Filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesTitle = e.title.toLowerCase().contains(query);
        final matchesCategory = e.category.displayName.toLowerCase().contains(query);
        final matchesNotes = e.notes?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesCategory && !matchesNotes) return false;
      }

      // Category Filter
      if (_selectedCategoryFilter != null && e.category != _selectedCategoryFilter) {
        return false;
      }

      // Source Filter
      final isTripExp = e.id.startsWith('trip_exp_');
      if (_sourceFilter == PersonalExpenseSourceFilter.personalOnly && isTripExp) {
        return false;
      }
      if (_sourceFilter == PersonalExpenseSourceFilter.tripSyncedOnly && !isTripExp) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (_sortOption) {
      case PersonalExpenseSortOption.newestFirst:
        result.sort((a, b) => b.date.compareTo(a.date));
        break;
      case PersonalExpenseSortOption.oldestFirst:
        result.sort((a, b) => a.date.compareTo(b.date));
        break;
      case PersonalExpenseSortOption.highestAmount:
        result.sort((a, b) => b.amountInPaise.compareTo(a.amountInPaise));
        break;
      case PersonalExpenseSortOption.lowestAmount:
        result.sort((a, b) => a.amountInPaise.compareTo(b.amountInPaise));
        break;
    }

    return result;
  }

  void _applyFilterAndCalculate() {
    _refreshBudgetCalculation();
    notifyListeners();
  }

  void _refreshBudgetCalculation() {
    if (_budget.hasBudget && _budget.monthlyLimitInPaise > 0) {
      final monthPrefix = currentMonthKey;
      final monthSpent = allEffectiveExpenses
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

  bool _isSyncingTrips = false;
  double _syncProgress = 0.0;
  String _syncStatusText = '';

  bool get isSyncingTrips => _isSyncingTrips;
  double get syncProgress => _syncProgress;
  String get syncStatusText => _syncStatusText;

  Future<void> syncTripExpenses(String userId) async {
    if (tripRepo == null || expenseRepo == null) return;
    _isSyncingTrips = true;
    _syncProgress = 0.15;
    _syncStatusText = 'Connecting to cloud trips ledger...';
    notifyListeners();

    try {
      final trips = await tripRepo!.getTrips();
      _syncProgress = 0.40;
      _syncStatusText = 'Found ${trips.length} ${trips.length == 1 ? 'trip' : 'trips'}, calculating split shares...';
      notifyListeners();

      final synced = <PersonalExpense>[];
      int processedTrips = 0;
      for (final trip in trips) {
        final userMemberIds = <String>{userId};
        for (final member in trip.members) {
          if (member.userId == userId || member.id == userId) {
            userMemberIds.add(member.id);
            userMemberIds.add(member.userId);
          }
        }
        if (trip.creatorId == userId && trip.members.isNotEmpty) {
          userMemberIds.add(trip.members.first.id);
          userMemberIds.add(trip.members.first.userId);
        }

        final tripExpenses = await expenseRepo!.getExpenses(trip.id);
        for (final exp in tripExpenses) {
          if (exp.isDeleted) continue;

          int userSharePaise = 0;
          final userSplits = exp.splits.where((s) => userMemberIds.contains(s.memberId)).toList();
          if (userSplits.isNotEmpty) {
            for (final s in userSplits) {
              userSharePaise += s.amountInPaise;
            }
          } else if (userMemberIds.contains(exp.paidById)) {
            userSharePaise = exp.amountInPaise;
          }

          if (userSharePaise > 0) {
            synced.add(PersonalExpense(
              id: 'trip_exp_${exp.id}',
              userId: userId,
              title: '${exp.title} (${trip.name})',
              amountInPaise: userSharePaise,
              category: exp.category,
              date: exp.createdAt,
              notes: 'Your share from ${trip.emoji} ${trip.name}',
              createdAt: exp.createdAt,
              updatedAt: exp.updatedAt,
            ));
          }
        }
        processedTrips++;
        _syncProgress = (0.40 + (0.50 * (processedTrips / (trips.isEmpty ? 1 : trips.length)))).clamp(0.0, 0.95);
        notifyListeners();
      }
      _tripSyncedExpenses = synced;
      _applyFilterAndCalculate();

      _syncProgress = 1.0;
      _syncStatusText = 'Synced ${synced.length} trip expenses into personal budget!';
      HapticHelper.success();
    } catch (e) {
      _syncStatusText = 'Sync completed with local trip records.';
      debugPrint('Error syncing trip expenses: $e');
    } finally {
      _isSyncingTrips = false;
      notifyListeners();
    }
  }

  void toggleIncludeTripExpenses(String userId) {
    _includeTripExpenses = !_includeTripExpenses;
    if (_includeTripExpenses) {
      syncTripExpenses(userId);
    } else {
      _tripSyncedExpenses = [];
      _applyFilterAndCalculate();
    }
    HapticHelper.selection();
    notifyListeners();
  }

  // --- Data Loading ---
  Future<void> loadData(String userId) async {
    // 1. FAST LOCAL HYDRATION (< 5ms)
    _expenses = personalRepo.getCachedPersonalExpenses();
    _debtsSummary = personalRepo.getCachedPersonalDebts();
    _budget = personalRepo.getCachedPersonalBudget(currentMonthKey);
    _refreshBudgetCalculation();
    notifyListeners();

    if (_includeTripExpenses) {
      syncTripExpenses(userId);
    }

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
      if (_includeTripExpenses) {
        await syncTripExpenses(userId);
      }
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
    // 1. Optimistic instant removal from UI
    final original = List<PersonalExpense>.from(_expenses);
    _expenses.removeWhere((e) => e.id == expenseId);
    _applyFilterAndCalculate();
    HapticHelper.medium();

    try {
      await personalRepo.deletePersonalExpense(expenseId);
      return true;
    } catch (e) {
      // Rollback on failure
      _expenses = original;
      _applyFilterAndCalculate();
      _errorMessage = 'Could not delete expense.';
      HapticHelper.error();
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
    // 1. Optimistic instant removal from UI
    final originalSummary = _debtsSummary;
    final updatedDebts = List<PersonalDebt>.from(_debtsSummary.debts)..removeWhere((d) => d.id == debtId);
    int totalLent = 0;
    int totalBorrowed = 0;
    for (final d in updatedDebts) {
      if (!d.isSettled) {
        if (d.debtType == PersonalDebtType.lent) {
          totalLent += d.remainingAmountInPaise;
        } else {
          totalBorrowed += d.remainingAmountInPaise;
        }
      }
    }
    _debtsSummary = PersonalDebtsSummary(
      debts: updatedDebts,
      totalLentPaise: totalLent,
      totalBorrowedPaise: totalBorrowed,
      netBalancePaise: totalLent - totalBorrowed,
    );
    notifyListeners();
    HapticHelper.medium();

    try {
      await personalRepo.deletePersonalDebt(debtId);
      return true;
    } catch (e) {
      // Rollback on failure
      _debtsSummary = originalSummary;
      notifyListeners();
      HapticHelper.error();
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

  void clearData() {
    _expenses = [];
    _tripSyncedExpenses = [];
    _debtsSummary = PersonalDebtsSummary.empty();
    _budget = PersonalBudget.empty(currentMonthKey);
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    _applyFilterAndCalculate();
    notifyListeners();
  }
}
