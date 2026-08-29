import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/realtime_client.dart';
import '../../core/utils/error_formatter.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/engine/balance_engine.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/trip.dart';

class HomeViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;
  final RealtimeClient? realtimeClient;

  List<Trip> _trips = [];
  final Map<String, BalanceSummary> _tripBalances = {};
  int _overallNetBalanceInPaise = 0;
  int _totalSpentOnTripsInPaise = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;
  StreamSubscription? _realtimeSubscription;

  HomeViewModel({
    required this.tripRepo,
    required this.expenseRepo,
    this.realtimeClient,
  }) {
    _subscribeToRealtimeEvents();
  }

  List<Trip> get trips => _trips;
  Map<String, BalanceSummary> get tripBalances => _tripBalances;
  int get overallNetBalanceInPaise => _overallNetBalanceInPaise;
  int get totalSpentOnTripsInPaise => _totalSpentOnTripsInPaise;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _subscribeToRealtimeEvents() {
    if (realtimeClient == null) return;
    _realtimeSubscription = realtimeClient!.events.listen((event) {
      if (_currentUserId == null) return;

      if (event.type == 'trip_created' || event.type == 'trip_joined') {
        if (event.data['trip'] is Map<String, dynamic>) {
          final trip = Trip.fromJson(event.data['trip'] as Map<String, dynamic>);
          addTripLocally(trip, _currentUserId!);
        }
      } else if (event.type == 'member_joined' || event.type == 'lifecycle_updated') {
        if (event.data['trip'] is Map<String, dynamic>) {
          final trip = Trip.fromJson(event.data['trip'] as Map<String, dynamic>);
          _updateTripInPlace(trip, _currentUserId!);
        }
      } else if (event.type == 'expense_added' ||
          event.type == 'expense_updated' ||
          event.type == 'expense_deleted' ||
          event.type == 'settlement_recorded') {
        // Recompute balances locally from updated cache
        _computeLocalBalances(_trips, _currentUserId!);
        notifyListeners();
      }
    });
  }

  void _updateTripInPlace(Trip trip, String currentUserId) {
    final idx = _trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      _trips[idx] = trip;
    } else {
      _trips.insert(0, trip);
    }
    _computeLocalBalances(_trips, currentUserId);
    notifyListeners();
  }

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
    int totalSpent = 0;

    for (final trip in tripsList) {
      final cachedExpenses = expenseRepo.getCachedExpenses(trip.id);
      final cachedSettlements = expenseRepo.getCachedSettlements(trip.id);
      final summary = BalanceEngine.calculateBalances(
        members: trip.members,
        expenses: cachedExpenses,
        settlements: cachedSettlements,
        currentUserId: currentUserId,
      );
      _tripBalances[trip.id] = summary;
      netSum += summary.currentUserNetBalanceInPaise;

      // Compute user's actual consumed share across all expenses in this trip
      final memberIds = <String>{currentUserId};
      for (final m in trip.members) {
        if (m.userId == currentUserId || m.id == currentUserId) {
          memberIds.add(m.id);
          memberIds.add(m.userId);
        }
      }
      if (trip.creatorId == currentUserId && trip.members.isNotEmpty) {
        memberIds.add(trip.members.first.id);
      }

      for (final exp in cachedExpenses) {
        if (exp.isDeleted) continue;
        for (final split in exp.splits) {
          if (memberIds.contains(split.memberId)) {
            totalSpent += split.amountInPaise;
          }
        }
      }
    }

    _overallNetBalanceInPaise = netSum;
    _totalSpentOnTripsInPaise = totalSpent;
  }

  Future<void> loadTrips(String currentUserId) async {
    _currentUserId = currentUserId;

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

      // Hydrate expenses for each trip so balances are immediately available
      for (final trip in remoteTrips) {
        try {
          await expenseRepo.getExpenses(trip.id);
        } catch (_) {}
      }

      _computeLocalBalances(_trips, currentUserId);
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String currentUserId) async {
    await loadTrips(currentUserId);
  }

  void clearData() {
    _trips = [];
    _tripBalances.clear();
    _overallNetBalanceInPaise = 0;
    _totalSpentOnTripsInPaise = 0;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

