import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/realtime_client.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/engine/balance_engine.dart';
import '../../domain/enums/trip_lifecycle.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/journey_moment.dart';
import '../../domain/models/journey_stop.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_memory.dart';

class TripDetailViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;
  final RealtimeClient? realtimeClient;

  Trip? _trip;
  List<Expense> _expenses = [];
  BalanceSummary _balanceSummary = BalanceSummary.empty();
  List<ActivityLog> _activityLogs = [];
  List<JourneyStop> _journeyStops = [];
  List<TripMemory> _tripMemories = [];
  List<JourneyMoment> _journeyMoments = [];
  bool _isLoading = false;
  bool _isLoadingActivity = false;
  String? _errorMessage;
  String? _currentUserId;

  // Search & Filtering State
  String _searchQuery = '';
  String? _selectedCategory;

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
  List<ActivityLog> get activityLogs => _activityLogs;
  List<JourneyStop> get journeyStops => _journeyStops;
  List<TripMemory> get tripMemories => _tripMemories;
  List<JourneyMoment> get journeyMoments => _journeyMoments;
  bool get isLoading => _isLoading;
  bool get isLoadingActivity => _isLoadingActivity;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  List<Expense> get filteredExpenses {
    return _expenses.where((expense) {
      // Category filter
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        if (expense.category.name.toLowerCase() != _selectedCategory!.toLowerCase()) {
          return false;
        }
      }

      // Text search filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesTitle = expense.title.toLowerCase().contains(query);
        final payer = _trip?.members.where((m) => m.id == expense.paidById).firstOrNull;
        final matchesPayer = payer?.displayName.toLowerCase().contains(query) ?? false;
        return matchesTitle || matchesPayer;
      }

      return true;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    notifyListeners();
  }

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

    // 1. FAST LOCAL HYDRATION: Render cached trip & expenses instantly (< 5ms)
    final cachedTrip = tripRepo.getCachedTripById(tripId);
    if (cachedTrip != null) {
      _trip = cachedTrip;
      _expenses = expenseRepo.getCachedExpenses(tripId);
      _activityLogs = tripRepo.getCachedActivityLogs(tripId);
      _journeyStops = tripRepo.getCachedJourneyStops(tripId);
      _tripMemories = tripRepo.getCachedTripMemories(tripId);
      _journeyMoments = tripRepo.getCachedJourneyMoments(tripId);
      _balanceSummary = BalanceEngine.calculateBalances(
        members: cachedTrip.members,
        expenses: _expenses,
        currentUserId: currentUserId,
      );
      notifyListeners();
    }

    _isLoading = _trip == null;
    _errorMessage = null;
    notifyListeners();

    // Subscribe to WebSocket room non-blocking
    realtimeClient?.subscribeToTrip(tripId);

    try {
      final remoteTrip = await tripRepo.getTripById(tripId);
      if (remoteTrip != null) {
        _trip = remoteTrip;
        _expenses = await expenseRepo.getExpenses(tripId);
        _journeyStops = tripRepo.getCachedJourneyStops(tripId);
        _tripMemories = tripRepo.getCachedTripMemories(tripId);
        _journeyMoments = await tripRepo.getJourneyMoments(tripId);
        _balanceSummary = await expenseRepo.getBalanceSummary(
          trip: remoteTrip,
          currentUserId: currentUserId,
        );
        await fetchActivityLogs();
      } else if (_trip == null) {
        _errorMessage = 'Trip not found';
      }
    } catch (e) {
      if (_trip == null) {
        _errorMessage = 'Could not load trip. Operating offline.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String currentUserId) async {
    if (_trip != null) {
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      _journeyStops = tripRepo.getCachedJourneyStops(_trip!.id);
      _tripMemories = tripRepo.getCachedTripMemories(_trip!.id);
      _journeyMoments = tripRepo.getCachedJourneyMoments(_trip!.id);
      try {
        final updatedTrip = await tripRepo.getTripById(_trip!.id);
        if (updatedTrip != null) {
          _trip = updatedTrip;
          _expenses = await expenseRepo.getExpenses(_trip!.id);
          _journeyMoments = await tripRepo.getJourneyMoments(_trip!.id);
          _balanceSummary = await expenseRepo.getBalanceSummary(
            trip: _trip!,
            currentUserId: currentUserId,
          );
          await fetchActivityLogs();
          notifyListeners();
        }
      } catch (_) {
        // Silent background refresh failure
      }
    }
  }

  Future<void> recordSettlement({
    required String fromMemberId,
    required String toMemberId,
    required int amountInPaise,
    String? paymentReference,
    String? note,
    required String currentUserId,
  }) async {
    if (_trip == null) return;
    try {
      await expenseRepo.recordSettlement(
        tripId: _trip!.id,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amountInPaise: amountInPaise,
        paymentReference: paymentReference,
        note: note,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      await refresh(currentUserId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
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
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
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
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
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
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
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
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
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
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      await refresh(currentUserId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addJourneyStop(JourneyStop stop) async {
    if (_trip == null) return;
    await tripRepo.addOrUpdateJourneyStop(_trip!.id, stop);
    _journeyStops = tripRepo.getCachedJourneyStops(_trip!.id);
    notifyListeners();
  }

  Future<void> deleteJourneyStop(String stopId) async {
    if (_trip == null) return;
    await tripRepo.deleteJourneyStop(_trip!.id, stopId);
    _journeyStops = tripRepo.getCachedJourneyStops(_trip!.id);
    notifyListeners();
  }

  Future<void> addTripMemory(TripMemory memory) async {
    if (_trip == null) return;
    await tripRepo.addOrUpdateTripMemory(_trip!.id, memory);
    _tripMemories = tripRepo.getCachedTripMemories(_trip!.id);
    notifyListeners();
  }

  Future<void> deleteTripMemory(String memoryId) async {
    if (_trip == null) return;
    await tripRepo.deleteTripMemory(_trip!.id, memoryId);
    _tripMemories = tripRepo.getCachedTripMemories(_trip!.id);
    notifyListeners();
  }

  Future<void> addJourneyMoment(JourneyMoment moment) async {
    if (_trip == null) return;
    await tripRepo.addOrUpdateJourneyMoment(_trip!.id, moment);
    _journeyMoments = tripRepo.getCachedJourneyMoments(_trip!.id);
    notifyListeners();
  }

  Future<void> updateJourneyMoment(JourneyMoment moment) async {
    if (_trip == null) return;
    await tripRepo.addOrUpdateJourneyMoment(_trip!.id, moment);
    _journeyMoments = tripRepo.getCachedJourneyMoments(_trip!.id);
    notifyListeners();
  }

  Future<void> deleteJourneyMoment(String momentId) async {
    if (_trip == null) return;
    await tripRepo.deleteJourneyMoment(_trip!.id, momentId);
    _journeyMoments = tripRepo.getCachedJourneyMoments(_trip!.id);
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> fetchActivityLogs() async {
    if (_trip == null || _isDisposed) return;
    _isLoadingActivity = true;
    notifyListeners();
    try {
      _activityLogs = await tripRepo.getActivityLogs(_trip!.id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!_isDisposed) {
        _isLoadingActivity = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_trip != null) {
      realtimeClient?.unsubscribeFromTrip(_trip!.id);
    }
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
