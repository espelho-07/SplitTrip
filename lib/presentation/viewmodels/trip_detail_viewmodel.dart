import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/realtime_client.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/trip.dart';

class TripDetailViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;
  final RealtimeClient? realtimeClient;

  Trip? _trip;
  List<Expense> _expenses = [];
  BalanceSummary _balanceSummary = BalanceSummary.empty();
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;

  StreamSubscription<RealtimeTripEvent>? _realtimeSubscription;

  TripDetailViewModel({
    required this.tripRepo,
    required this.expenseRepo,
    this.realtimeClient,
  }) {
    _subscribeToRealtimeEvents();
  }

  Trip? get trip => _trip;
  List<Expense> get expenses => _expenses;
  BalanceSummary get balanceSummary => _balanceSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _subscribeToRealtimeEvents() {
    if (realtimeClient == null) return;
    _realtimeSubscription = realtimeClient!.events.listen((event) {
      if (_trip == null || event.tripId != _trip!.id) return;

      if (_currentUserId != null) {
        // Automatically reconcile trip state on realtime push
        refresh(_currentUserId!);
      }
    });
  }

  Future<void> loadTrip(String tripId, String currentUserId) async {
    _currentUserId = currentUserId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Subscribe to WebSocket room
    realtimeClient?.subscribeToTrip(tripId);

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
      try {
        final updatedTrip = await tripRepo.getTripById(_trip!.id);
        if (updatedTrip != null) {
          _trip = updatedTrip;
          _expenses = await expenseRepo.getExpenses(_trip!.id);
          _balanceSummary = await expenseRepo.getBalanceSummary(
            trip: _trip!,
            currentUserId: currentUserId,
          );
          notifyListeners();
        }
      } catch (_) {
        // Silent background refresh failure
      }
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
      await refresh(currentUserId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_trip != null) {
      realtimeClient?.unsubscribeFromTrip(_trip!.id);
    }
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
