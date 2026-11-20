import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/realtime_client.dart';
import '../../core/utils/error_formatter.dart';
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
import '../../data/services/local_storage_service.dart';

class TripDetailViewModel extends ChangeNotifier {
  final TripRepository tripRepo;
  final ExpenseRepository expenseRepo;
  final RealtimeClient? realtimeClient;
  final LocalStorageService? storage;

  Trip? _trip;
  List<Expense> _expenses = [];
  BalanceSummary _balanceSummary = BalanceSummary.empty();
  List<ActivityLog> _activityLogs = [];
  List<JourneyStop> _journeyStops = [];
  List<TripMemory> _tripMemories = [];
  List<JourneyMoment> _journeyMoments = [];
  bool _isLoading = false;
  bool _isLoadingActivity = false;
  bool _isCompleting = false;
  String? _errorMessage;
  String? _currentUserId;

  // Search & Filtering State
  String _searchQuery = '';
  String? _selectedCategory;

  StreamSubscription<RealtimeTripEvent>? _realtimeSubscription;
  final StreamController<Map<String, dynamic>> _notificationEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationEvents => _notificationEventController.stream;

  TripDetailViewModel({
    required this.tripRepo,
    required this.expenseRepo,
    this.storage,
    this.realtimeClient,
  }) {
    storage?.addOnClearDataListener(clearData);
    _subscribeToRealtimeEvents();
  }

  void clearData() {
    _trip = null;
    _expenses = [];
    _balanceSummary = BalanceSummary.empty();
    _activityLogs = [];
    _journeyStops = [];
    _tripMemories = [];
    _journeyMoments = [];
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();
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
  bool get isCompleting => _isCompleting;
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

      // ── Settlement lifecycle events (Bug 1 fix) ─────────────────────────────
      // Each event carries a 'notification' sub-map with recipientUserId.
      // Only emit to the notification stream when the current user IS the recipient.

      if (event.type == 'settlement_marked_paid' ||
          event.type == 'settlement_recorded') {
        // Receiver (toUser) must confirm the payment
        final notifData = _extractNotifData(event);
        if (notifData != null) {
          final recipientUserId = notifData['recipientUserId'] as String?;
          if (recipientUserId != null && recipientUserId == _currentUserId) {
            final settlementId = notifData['settlementId'] as String? ?? event.data['settlementId'] as String? ?? event.eventId;
            expenseRepo.storage.addPaymentVerification({
              'id': 'pvr_$settlementId',
              'settlementId': settlementId,
              'tripId': event.tripId,
              'tripName': notifData['tripName'] as String? ?? _trip?.name ?? 'Trip',
              'payerMemberId': notifData['payerMemberId'],
              'payerUserId': notifData['payerUserId'],
              'payerName': notifData['payerName'] ?? 'A friend',
              'receiverMemberId': notifData['recipientMemberId'],
              'receiverUserId': _currentUserId,
              'receiverName': notifData['receiverName'] ?? 'You',
              'amountInPaise': notifData['amountInPaise'] ?? 0,
              'paymentMethod': 'Direct',
              'status': 'pending_verification',
              'markedAt': DateTime.now().toIso8601String(),
            });

            _notificationEventController.add({
              ...notifData,
              'eventType': event.type,
            });
          }
        }
        _recomputeLocalBalances();
        _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
        notifyListeners();
        return;
      }

      if (event.type == 'settlement_confirmed') {
        // Update local settlement in storage immediately!
        final settlementId = event.data['settlementId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['id'] as String? : null);
        final fromMemberId = event.data['fromMemberId'] as String? ??
            event.data['payerMemberId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['fromMemberId'] as String? : null);
        final toMemberId = event.data['toMemberId'] as String? ??
            event.data['receiverMemberId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['toMemberId'] as String? : null);
        final amt = int.tryParse(event.data['amountInPaise']?.toString() ??
            (event.data['settlement'] is Map ? event.data['settlement']['amountInPaise']?.toString() ?? '0' : '0')) ?? 0;

        if (_trip != null) {
          final saved = expenseRepo.getCachedSettlements(_trip!.id);
          bool found = false;
          final nowStr = DateTime.now().toIso8601String();
          for (int i = 0; i < saved.length; i++) {
            final s = saved[i];
            final matchesId = settlementId != null && s['id'] == settlementId;
            final matchesPair = fromMemberId != null && toMemberId != null &&
                s['fromMemberId'] == fromMemberId && s['toMemberId'] == toMemberId;
            if (matchesId || matchesPair) {
              saved[i]['status'] = 'confirmed';
              saved[i]['isSettled'] = true;
              saved[i]['confirmedAt'] = nowStr;
              found = true;
            }
          }
          if (!found && settlementId != null) {
            saved.insert(0, {
              'id': settlementId,
              'tripId': _trip!.id,
              'fromMemberId': fromMemberId,
              'toMemberId': toMemberId,
              'amountInPaise': amt,
              'status': 'confirmed',
              'isSettled': true,
              'confirmedAt': nowStr,
              'createdAt': nowStr,
            });
          }
          expenseRepo.storage.saveTripSettlements(_trip!.id, saved);
        }

        // Payer (fromUser) gets notified that receiver confirmed
        final notifData = _extractNotifData(event);
        if (notifData != null) {
          final recipientUserId = notifData['payerUserId'] as String? ??
              notifData['recipientUserId'] as String?;
          if (recipientUserId != null && recipientUserId == _currentUserId) {
            _notificationEventController.add({
              ...notifData,
              'eventType': event.type,
            });
          }
        }
        _recomputeLocalBalances();
        if (_trip != null) {
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
        }
        notifyListeners();
        return;
      }

      if (event.type == 'settlement_disputed') {
        // Payer (fromUser) gets notified that receiver disputed
        final notifData = _extractNotifData(event);
        if (notifData != null) {
          final recipientUserId = notifData['payerUserId'] as String? ??
              notifData['recipientUserId'] as String?;
          if (recipientUserId != null && recipientUserId == _currentUserId) {
            _notificationEventController.add({
              ...notifData,
              'eventType': event.type,
            });
          }
        }
        _recomputeLocalBalances();
        _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
        notifyListeners();
        return;
      }

      if (event.type == 'payment_proof_submitted') {
        // Receiver gets notified that payer submitted proof
        final notifData = _extractNotifData(event);
        if (notifData != null) {
          final recipientUserId = notifData['recipientUserId'] as String?;
          if (recipientUserId != null && recipientUserId == _currentUserId) {
            _notificationEventController.add({
              ...notifData,
              'eventType': event.type,
            });
          }
        }
        notifyListeners();
        return;
      }

      // ── Trip lifecycle events ───────────────────────────────────────────────
      if (event.type == 'trip_completed' || event.type == 'lifecycle_updated') {
        if (event.data['trip'] is Map<String, dynamic>) {
          _trip = Trip.fromJson(event.data['trip'] as Map<String, dynamic>);
          // Also persist to local cache so it survives app restart
          tripRepo.getTripById(_trip!.id); // triggers cache update
          _recomputeLocalBalances();
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
          notifyListeners();
          return;
        }
      }

      // ── Expense delta events (in-memory instant apply) ──────────────────────
      if (event.type == 'expense_added') {
        if (event.data['expense'] is Map<String, dynamic>) {
          final expense = Expense.fromJson(event.data['expense'] as Map<String, dynamic>);
          _expenses.removeWhere((e) => e.id == expense.id);
          _expenses.insert(0, expense);
          _recomputeLocalBalances();
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
          notifyListeners();
          return;
        }
      } else if (event.type == 'expense_updated') {
        if (event.data['expense'] is Map<String, dynamic>) {
          final expense = Expense.fromJson(event.data['expense'] as Map<String, dynamic>);
          final idx = _expenses.indexWhere((e) => e.id == expense.id);
          if (idx != -1) {
            _expenses[idx] = expense;
          } else {
            _expenses.insert(0, expense);
          }
          _recomputeLocalBalances();
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
          notifyListeners();
          return;
        }
      } else if (event.type == 'expense_deleted') {
        final expId = event.entityId ?? (event.data['expenseId'] as String?);
        if (expId != null) {
          _expenses.removeWhere((e) => e.id == expId);
          _recomputeLocalBalances();
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
          notifyListeners();
          return;
        }
      } else if (event.type == 'member_joined' ||
          event.type == 'member_added' ||
          event.type == 'member_renamed' ||
          event.type == 'member_removed' ||
          event.type == 'members_merged') {
        if (event.data['trip'] is Map<String, dynamic>) {
          _trip = Trip.fromJson(event.data['trip'] as Map<String, dynamic>);
        } else if (_trip != null) {
          _trip = tripRepo.getCachedTripById(_trip!.id);
        }
        if (_trip != null) {
          _expenses = expenseRepo.getCachedExpenses(_trip!.id);
        }
        _recomputeLocalBalances();
        if (_trip != null) {
          _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
        }
        notifyListeners();
        return;
      }

      if (_currentUserId != null) {
        _recomputeLocalBalances();
        notifyListeners();
      }

    });
  }

  /// Extracts the notification payload from a realtime event.
  /// Supports both flat data and nested 'notification' sub-maps.
  Map<String, dynamic>? _extractNotifData(RealtimeTripEvent event) {
    if (event.data['notification'] is Map<String, dynamic>) {
      return event.data['notification'] as Map<String, dynamic>;
    }
    // Fallback: treat the top-level data as the notification payload
    if (event.data.containsKey('recipientUserId') ||
        event.data.containsKey('payerName')) {
      return event.data;
    }
    return null;
  }

  void _recomputeLocalBalances() {
    if (_trip != null && _currentUserId != null) {
      final cachedSettlements = expenseRepo.getCachedSettlements(_trip!.id);
      _balanceSummary = BalanceEngine.calculateBalances(
        members: _trip!.members,
        expenses: _expenses,
        settlements: cachedSettlements,
        currentUserId: _currentUserId!,
      );
    }
  }


  void hydrateLocally(String tripId, String currentUserId) {
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
      final cachedSettlements = expenseRepo.getCachedSettlements(tripId);
      _balanceSummary = BalanceEngine.calculateBalances(
        members: cachedTrip.members,
        expenses: _expenses,
        settlements: cachedSettlements,
        currentUserId: currentUserId,
      );
      notifyListeners();
    }
  }

  Future<void> loadTrip(String tripId, String currentUserId) async {
    // If switching away from a previous active trip, unsubscribe from its socket room
    if (_trip != null && _trip!.id != tripId) {
      realtimeClient?.unsubscribeFromTrip(_trip!.id);
    }

    hydrateLocally(tripId, currentUserId);

    _isLoading = _trip == null;
    _errorMessage = null;
    notifyListeners();

    // Ensure connection is active and subscribe to trip WebSocket room
    if (realtimeClient != null) {
      if (!realtimeClient!.isConnected) {
        realtimeClient!.connect();
      }
      realtimeClient!.subscribeToTrip(tripId);
    }

    startHeartbeat(tripId);

    try {
      final results = await Future.wait([
        tripRepo.getTripById(tripId),
        expenseRepo.getExpenses(tripId),
        tripRepo.getJourneyMoments(tripId),
      ]);
      final remoteTrip = results[0] as Trip?;
      final remoteExpenses = results[1] as List<Expense>;
      final remoteMoments = results[2] as List<JourneyMoment>;

      if (remoteTrip != null) {
        _trip = remoteTrip;
        _expenses = remoteExpenses;
        _journeyStops = tripRepo.getCachedJourneyStops(tripId);
        _tripMemories = tripRepo.getCachedTripMemories(tripId);
        _journeyMoments = remoteMoments;
        final cachedSettlements = expenseRepo.getCachedSettlements(tripId);
        _balanceSummary = BalanceEngine.calculateBalances(
          members: remoteTrip.members,
          expenses: remoteExpenses,
          settlements: cachedSettlements,
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
        final results = await Future.wait([
          tripRepo.getTripById(_trip!.id),
          expenseRepo.getExpenses(_trip!.id),
          tripRepo.getJourneyMoments(_trip!.id),
        ]);
        final updatedTrip = results[0] as Trip?;
        final updatedExpenses = results[1] as List<Expense>;
        final updatedMoments = results[2] as List<JourneyMoment>;

        if (updatedTrip != null) {
          _trip = updatedTrip;
          _expenses = updatedExpenses;
          _journeyMoments = updatedMoments;
          final cachedSettlements = expenseRepo.getCachedSettlements(_trip!.id);
          _balanceSummary = BalanceEngine.calculateBalances(
            members: updatedTrip.members,
            expenses: updatedExpenses,
            settlements: cachedSettlements,
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
    String? settlementId,
    String? paymentReference,
    String? recipientUpiId,
    String? fromName,
    String? toName,
    String? note,
    String paymentStatus = 'paid',
    required String currentUserId,
    String? fromUserId,
    String? toUserId,
  }) async {
    if (_trip == null) return;
    try {
      await expenseRepo.recordSettlement(
        tripId: _trip!.id,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amountInPaise: amountInPaise,
        settlementId: settlementId,
        paymentReference: paymentReference,
        recipientUpiId: recipientUpiId,
        fromName: fromName,
        toName: toName,
        note: note,
        paymentStatus: paymentStatus,
        tripName: _trip!.name,
        fromUserId: fromUserId,
        toUserId: toUserId,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      await refresh(currentUserId);
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
    }
  }

  /// Settle all remaining debt transfers in one tap and mark the trip as settled.
  Future<void> settleAllRemainingDues(
    String currentUserId, {
    bool completeTrip = true,
  }) async {
    if (_trip == null) return;
    try {
      final settlements = List.of(_balanceSummary.simplifiedSettlements);
      for (final s in settlements) {
        final fromMember = _trip!.members.where((m) => m.id == s.fromMemberId).firstOrNull;
        final toMember = _trip!.members.where((m) => m.id == s.toMemberId).firstOrNull;
        await expenseRepo.recordSettlement(
          tripId: _trip!.id,
          fromMemberId: s.fromMemberId,
          toMemberId: s.toMemberId,
          amountInPaise: s.amountInPaise,
          fromName: fromMember?.displayName ?? 'Member',
          toName: toMember?.displayName ?? 'Member',
          fromUserId: fromMember?.userId,
          toUserId: toMember?.userId,
          tripName: _trip!.name,
          paymentStatus: 'paid',
          paymentReference: 'settle_all_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      if ((completeTrip ||
              _trip!.lifecycleState == TripLifecycle.settling ||
              _trip!.lifecycleState == TripLifecycle.completing) &&
          _trip!.isCreator(currentUserId)) {
        await markAsSettled(currentUserId);
      }
      await refresh(currentUserId);
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
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
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> renameMember(String memberId, String newDisplayName, String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.renameMember(
        tripId: _trip!.id,
        memberId: memberId,
        newDisplayName: newDisplayName,
      );
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeMember(String memberId, String currentUserId) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.removeMember(
        tripId: _trip!.id,
        memberId: memberId,
      );
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> mergeMembers({
    required String sourceMemberId,
    required String canonicalMemberId,
    required String currentUserId,
    String? operationId,
  }) async {
    if (_trip == null) return;
    try {
      _trip = await tripRepo.mergeMembers(
        tripId: _trip!.id,
        sourceMemberId: sourceMemberId,
        canonicalMemberId: canonicalMemberId,
        operationId: operationId,
      );
      _expenses = expenseRepo.getCachedExpenses(_trip!.id);
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: _trip!,
        currentUserId: currentUserId,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
      rethrow;
    }
  }


  /// Atomically completes the trip via direct server call.
  /// Uses the /complete endpoint (not the sync queue) so the server persists
  /// lifecycleState: 'completed' immediately — survives app restarts.
  Future<void> completeTrip(String currentUserId) async {
    if (_trip == null) return;
    _isCompleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Call the atomic server completion endpoint directly (not via sync queue)
      final completedTrip = await tripRepo.completeTrip(
        tripId: _trip!.id,
        completionMode: 'NORMAL',
      );
      _trip = completedTrip;
      _balanceSummary = await expenseRepo.getBalanceSummary(
        trip: completedTrip,
        currentUserId: currentUserId,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
    } finally {
      _isCompleting = false;
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
      _errorMessage = KithErrorFormatter.format(e);
      notifyListeners();
    }
  }

  Future<void> markAsSettled(String currentUserId) async {
    if (_trip == null) return;
    if (!_trip!.isCreator(currentUserId)) {
      // Only the trip creator can settle or complete this trip
      return;
    }
    try {
      _trip = await tripRepo.updateLifecycle(
        tripId: _trip!.id,
        newLifecycle: TripLifecycle.settled,
      );
      _activityLogs = tripRepo.getCachedActivityLogs(_trip!.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
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
      _errorMessage = KithErrorFormatter.format(e);
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
      _errorMessage = KithErrorFormatter.format(e);
    } finally {
      if (!_isDisposed) {
        _isLoadingActivity = false;
        notifyListeners();
      }
    }
  }

  Timer? _heartbeatTimer;

  /// Starts periodic presence heartbeat for [tripId] while actively viewing the trip.
  void startHeartbeat(String tripId) {
    _heartbeatTimer?.cancel();
    tripRepo.sendHeartbeat(tripId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isDisposed && _trip != null && _trip!.id == tripId) {
        tripRepo.sendHeartbeat(tripId);
      }
    });
  }

  /// Stops periodic presence heartbeat.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Unsubscribes from the active trip room when navigating away from TripDetailView.
  void unsubscribeCurrentTrip() {
    stopHeartbeat();
    if (_trip != null) {
      realtimeClient?.unsubscribeFromTrip(_trip!.id);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopHeartbeat();
    storage?.removeOnClearDataListener(clearData);
    if (_trip != null) {
      realtimeClient?.unsubscribeFromTrip(_trip!.id);
    }
    _realtimeSubscription?.cancel();
    _notificationEventController.close();
    super.dispose();
  }
}
