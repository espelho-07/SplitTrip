import 'package:flutter/material.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';

class TripDetailViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;

  Trip? _trip;
  List<Expense> _expenses = [];
  BalanceSummary _balanceSummary = BalanceSummary.empty();
  bool _isLoading = false;
  String? _errorMessage;

  TripDetailViewModel({
    required this.tripRepo,
    required this.expenseRepo,
  });

  Trip? get trip => _trip;
  List<Expense> get expenses => _expenses;
  BalanceSummary get balanceSummary => _balanceSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTrip(String tripId, String currentUserId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _trip = await tripRepo.getTripById(tripId);
      if (_trip != null) {
        _expenses = await expenseRepo.getExpenses(tripId);
        _balanceSummary = await expenseRepo.getBalanceSummary(
          trip: _trip!,
          currentUserId: currentUserId,
        );
      } else {
        _errorMessage = 'Trip not found';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String currentUserId) async {
    if (_trip != null) {
      await loadTrip(_trip!.id, currentUserId);
    }
  }

  Future<void> addMember(String displayName, String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.addMember(
        tripId: _trip!.id,
        displayName: displayName,
      );
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> completeTrip(String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.updateLifecycle(
        tripId: _trip!.id,
        newLifecycle: TripLifecycle.completed,
      );
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> reopenTrip(String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.updateLifecycle(
        tripId: _trip!.id,
        newLifecycle: TripLifecycle.active,
      );
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsSettled(String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.updateLifecycle(
        tripId: _trip!.id,
        newLifecycle: TripLifecycle.settled,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String expenseId, String currentUserId) async {
    if (_trip == null) return;
    try {
      await expenseRepo.deleteExpense(tripId: _trip!.id, expenseId: expenseId);
      await loadTrip(_trip!.id, currentUserId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
