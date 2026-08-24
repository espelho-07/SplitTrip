import 'package:flutter/material.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/engine/balance_engine.dart';
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

  /// Optimistically adds a newly created/joined trip into memory and updates balances instantly
  void addTripLocally(Trip trip, String currentUserId) {
    _trips.removeWhere((t) => t.id == trip.id);
    _trips.insert(0, trip);
    _computeLocalBalances(_trips, currentUserId);
    notifyListeners();
  }

  void _computeLocalBalances(List<Trip> tripsList, String currentUserId) {
    _tripBalances.clear();
    int netSum = 0;
    for (final trip in tripsList) {
      final cachedExpenses = expenseRepo.getCachedExpenses(trip.id);
      final summary = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: cachedExpenses,
        currentUserId: currentUserId,
      );
      _tripBalances[trip.id] = summary;
      netSum += summary.currentUserNetBalanceInPaise;
    }
    _overallNetBalanceInPaise = netSum;
  }

  Future<void> loadTrips(String currentUserId) async {
    // 1. FAST LOCAL HYDRATION: Render cached trips immediately (< 5ms)
    final cachedTrips = tripRepo.getCachedTrips();
    if (cachedTrips.isNotEmpty && _trips.isEmpty) {
      _trips = cachedTrips;
      _computeLocalBalances(_trips, currentUserId);
      notifyListeners();
    }

    _isLoading = _trips.isEmpty;
    _errorMessage = null;
    notifyListeners();

    try {
      // 2. Non-blocking network sync
      final remoteTrips = await tripRepo.getTrips();
      _trips = remoteTrips;
      _computeLocalBalances(_trips, currentUserId);
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
