import 'package:flutter/material.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/trip.dart';

class HomeViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;

  List<Trip> _trips = [];
  final Map<String, BalanceSummary> _tripBalances = {};
  int _overallNetBalanceInPaise = 0;
  bool _isLoading = false;
  String? _errorMessage;

  HomeViewModel({
    required this.tripRepo,
    required this.expenseRepo,
  });

  List<Trip> get trips => _trips;
  Map<String, BalanceSummary> get tripBalances => _tripBalances;
  int get overallNetBalanceInPaise => _overallNetBalanceInPaise;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTrips(String currentUserId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _trips = await tripRepo.getTrips();
      _tripBalances.clear();

      int netSum = 0;
      for (final trip in _trips) {
        final summary = await expenseRepo.getBalanceSummary(
          trip: trip,
          currentUserId: currentUserId,
        );
        _tripBalances[trip.id] = summary;
        netSum += summary.currentUserNetBalanceInPaise;
      }
      _overallNetBalanceInPaise = netSum;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String currentUserId) async {
    await loadTrips(currentUserId);
  }
}
