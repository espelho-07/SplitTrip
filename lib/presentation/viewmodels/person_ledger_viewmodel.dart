import 'package:flutter/material.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/personal_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../domain/models/person_ledger_item.dart';
import '../../domain/models/personal_debt.dart';

class PersonLedgerViewModel extends ChangeNotifier {
  final PersonalRepository personalRepo;
  final ExpenseRepository expenseRepo;
  final TripRepository tripRepo;
  final LocalStorageService storage;

  String _personName = '';
  String? _personUserId;
  String? _personPhone;
  String? _currentUserId;

  List<PersonLedgerItem> _items = [];
  int _totalLentPaise = 0;
  int _totalBorrowedPaise = 0;
  int _netBalancePaise = 0;
  bool _isLoading = false;
  bool _isAutoBudgetingEnabled = false;

  String _selectedCategoryFilter = 'all'; // 'all', 'ipo', 'lending', 'trips', 'personal'

  PersonLedgerViewModel({
    required this.personalRepo,
    required this.expenseRepo,
    required this.tripRepo,
    required this.storage,
  });

  String get personName => _personName;
  String? get personUserId => _personUserId;
  String? get personPhone => _personPhone;
  List<PersonLedgerItem> get items => _items;
  String get selectedCategoryFilter => _selectedCategoryFilter;

  List<PersonLedgerItem> get filteredItems {
    switch (_selectedCategoryFilter) {
      case 'ipo':
        return _items.where((i) => i.isIpoFunding).toList();
      case 'lending':
        return _items.where((i) => !i.isIpoFunding && i.tripId == null).toList();
      case 'trips':
        return _items.where((i) => i.tripId != null).toList();
      case 'personal':
        return _items.where((i) => i.tripId == null).toList();
      case 'all':
      default:
        return _items;
    }
  }

  void setCategoryFilter(String filter) {
    if (_selectedCategoryFilter != filter) {
      _selectedCategoryFilter = filter;
      notifyListeners();
    }
  }

  int get totalLentPaise => _totalLentPaise;
  int get totalPaidPaise => _totalLentPaise;
  int get totalBorrowedPaise => _totalBorrowedPaise;
  int get totalReceivedPaise => _totalBorrowedPaise;
  int get netBalancePaise => _netBalancePaise;
  bool get isLoading => _isLoading;
  bool get isAutoBudgetingEnabled => _isAutoBudgetingEnabled;

  /// Dynamic natural language status for the relationship balance
  String get runningBalanceStatusText {
    if (_netBalancePaise > 0) {
      return '$_personName owes you';
    } else if (_netBalancePaise < 0) {
      return 'You owe $_personName';
    } else {
      return 'Settled / Even';
    }
  }

  // --- "This Month" Dynamic Insights ---
  int get thisMonthPaidPaise {
    final now = DateTime.now();
    return _items.where((item) {
      return item.isCreditToUser && item.date.year == now.year && item.date.month == now.month;
    }).fold<int>(0, (sum, item) => sum + item.amountInPaise);
  }

  int get thisMonthReceivedPaise {
    final now = DateTime.now();
    return _items.where((item) {
      return !item.isCreditToUser && item.date.year == now.year && item.date.month == now.month;
    }).fold<int>(0, (sum, item) => sum + item.amountInPaise);
  }

  int get thisMonthNetPaise => thisMonthPaidPaise - thisMonthReceivedPaise;

  Future<void> loadLedger({
    required String personName,
    String? personUserId,
    String? personPhone,
    required String currentUserId,
  }) async {
    _personName = personName;
    _personUserId = personUserId;
    _personPhone = personPhone;
    _currentUserId = currentUserId;
    _isLoading = true;

    // Load persisted Auto Budgeting toggle state (strictly defaults to OFF/false)
    _isAutoBudgetingEnabled = storage.isAutoBudgetingEnabled(_personName);

    notifyListeners();

    await _aggregateTransactions();

    _isLoading = false;
    notifyListeners();
  }

  /// Toggles and persists Auto Budgeting for this specific person relationship
  Future<void> toggleAutoBudgeting(bool enabled) async {
    _isAutoBudgetingEnabled = enabled;
    await storage.setAutoBudgetingEnabled(_personName, enabled);
    notifyListeners();
  }

  Future<void> _aggregateTransactions() async {
    final aggregated = <PersonLedgerItem>[];
    int lentSum = 0;
    int borrowedSum = 0;

    final targetNameLower = _personName.trim().toLowerCase();
    final savedUser = storage.getSavedUser();
    final currentUserNameLower = (savedUser?['displayName'] as String? ?? '').trim().toLowerCase();

    // 1. Unified Personal Debts (Lend / Borrow / Repayments)
    final debtsSummary = personalRepo.getCachedPersonalDebts();
    final matchingDebts = debtsSummary.debts.where((d) {
      final dName = d.personName.trim().toLowerCase();
      // Case A: Created by current user with target person
      if (d.userId == _currentUserId) {
        if (dName == targetNameLower) return true;
        if (_personUserId != null && dName == _personUserId!.toLowerCase()) return true;
      }
      // Case B: Created by target person with current user (bidirectional sync)
      if (_personUserId != null && d.userId == _personUserId) {
        if (dName == currentUserNameLower || (_currentUserId != null && dName == _currentUserId!.toLowerCase())) return true;
      }
      return false;
    }).toList();

    for (final d in matchingDebts) {
      final isCreatedByMe = d.userId == _currentUserId;
      // If created by me: lent is lent, borrowed is borrowed
      // If created by them: lent is borrowed for me, borrowed is lent for me
      final effectiveType = isCreatedByMe
          ? d.debtType
          : (d.debtType == PersonalDebtType.lent ? PersonalDebtType.borrowed : PersonalDebtType.lent);

      final isLent = effectiveType == PersonalDebtType.lent;
      final isIpo = d.description?.contains('(IPO Funding)') == true || d.description?.toLowerCase().contains('ipo') == true;
      final ipoTitle = isIpo ? (d.description?.replaceAll('(IPO Funding)', '').trim() ?? 'IPO') : null;

      if (isLent) {
        lentSum += d.initialAmountInPaise;
        aggregated.add(PersonLedgerItem(
          id: d.id,
          personName: d.personName,
          personUserId: _personUserId,
          type: PersonLedgerType.lent,
          amountInPaise: d.initialAmountInPaise,
          date: d.date,
          title: d.description?.isNotEmpty == true ? d.description! : 'Direct Loan',
          note: d.description,
          ipoName: ipoTitle,
          isSettled: d.isSettled,
          referenceId: d.id,
        ));

        // Repayments received from this person
        for (final r in d.repayments) {
          borrowedSum += r.amountInPaise;
          aggregated.add(PersonLedgerItem(
            id: r.id,
            personName: d.personName,
            type: PersonLedgerType.repaymentReceived,
            amountInPaise: r.amountInPaise,
            date: r.date,
            title: 'Repayment Received',
            note: r.note,
            isSettled: true,
            referenceId: d.id,
          ));
        }
      } else {
        borrowedSum += d.initialAmountInPaise;
        aggregated.add(PersonLedgerItem(
          id: d.id,
          personName: d.personName,
          personUserId: _personUserId,
          type: PersonLedgerType.borrowed,
          amountInPaise: d.initialAmountInPaise,
          date: d.date,
          title: d.description?.isNotEmpty == true ? d.description! : 'Borrowed from $_personName',
          note: d.description,
          ipoName: ipoTitle,
          isSettled: d.isSettled,
          referenceId: d.id,
        ));

        // Repayments paid back to this person
        for (final r in d.repayments) {
          lentSum += r.amountInPaise;
          aggregated.add(PersonLedgerItem(
            id: r.id,
            personName: d.personName,
            type: PersonLedgerType.repaymentPaid,
            amountInPaise: r.amountInPaise,
            date: r.date,
            title: 'Repayment Paid',
            note: r.note,
            isSettled: true,
            referenceId: d.id,
          ));
        }
      }
    }

    // 2. Trip Expenses involving this person
    final cachedTrips = tripRepo.getCachedTrips();
    for (final trip in cachedTrips) {
      final matchingMember = trip.members.where((m) {
        if (_personUserId != null && m.userId == _personUserId) return true;
        return m.displayName.trim().toLowerCase() == targetNameLower;
      }).firstOrNull;

      if (matchingMember == null) continue;

      final currentMember = trip.members.where((m) => m.userId == _currentUserId).firstOrNull;
      final currentMemberId = currentMember?.id ?? _currentUserId;

      final expenses = expenseRepo.getCachedExpenses(trip.id);
      for (final exp in expenses) {
        if (exp.isDeleted) continue;

        // Case A: Current user paid -> Person owes user for their split
        if (exp.paidById == currentMemberId || exp.paidById == _currentUserId) {
          final personSplit = exp.splits.where((s) => s.memberId == matchingMember.id).firstOrNull;
          if (personSplit != null && personSplit.amountInPaise > 0) {
            lentSum += personSplit.amountInPaise;
            aggregated.add(PersonLedgerItem(
              id: '${exp.id}_${matchingMember.id}',
              personName: _personName,
              personUserId: matchingMember.userId,
              personMemberId: matchingMember.id,
              type: PersonLedgerType.tripSplitOwedToYou,
              amountInPaise: personSplit.amountInPaise,
              date: exp.createdAt,
              title: exp.title,
              note: 'Trip: ${trip.name}',
              tripId: trip.id,
              tripName: trip.name,
              isSettled: false,
              referenceId: exp.id,
            ));
          }
        }

        // Case B: Person paid -> Current user owes person for their split
        else if (exp.paidById == matchingMember.id || (_personUserId != null && exp.paidById == _personUserId)) {
          final userSplit = exp.splits.where((s) => s.memberId == currentMemberId || s.memberId == _currentUserId).firstOrNull;
          if (userSplit != null && userSplit.amountInPaise > 0) {
            borrowedSum += userSplit.amountInPaise;
            aggregated.add(PersonLedgerItem(
              id: '${exp.id}_$currentMemberId',
              personName: _personName,
              personUserId: matchingMember.userId,
              personMemberId: matchingMember.id,
              type: PersonLedgerType.tripSplitYouOwe,
              amountInPaise: userSplit.amountInPaise,
              date: exp.createdAt,
              title: exp.title,
              note: 'Trip: ${trip.name}',
              tripId: trip.id,
              tripName: trip.name,
              isSettled: false,
              referenceId: exp.id,
            ));
          }
        }
      }

      // 3. Trip Direct Settlements
      final settlements = expenseRepo.getCachedSettlements(trip.id);
      for (final s in settlements) {
        final fromId = s['fromMemberId'] as String?;
        final toId = s['toMemberId'] as String?;
        final amt = (s['amountInPaise'] as int?) ?? 0;
        final sDate = s['createdAt'] != null ? DateTime.tryParse(s['createdAt'] as String) ?? DateTime.now() : DateTime.now();

        if (fromId == currentMemberId && toId == matchingMember.id) {
          lentSum += amt;
          aggregated.add(PersonLedgerItem(
            id: s['id'] as String? ?? 'stl_${DateTime.now().millisecondsSinceEpoch}',
            personName: _personName,
            type: PersonLedgerType.tripSettlementPaid,
            amountInPaise: amt,
            date: sDate,
            title: 'Settlement Payment Sent',
            note: 'Trip: ${trip.name}',
            tripId: trip.id,
            tripName: trip.name,
            isSettled: true,
          ));
        } else if (fromId == matchingMember.id && toId == currentMemberId) {
          borrowedSum += amt;
          aggregated.add(PersonLedgerItem(
            id: s['id'] as String? ?? 'stl_${DateTime.now().millisecondsSinceEpoch}',
            personName: _personName,
            type: PersonLedgerType.tripSettlementReceived,
            amountInPaise: amt,
            date: sDate,
            title: 'Settlement Payment Received',
            note: 'Trip: ${trip.name}',
            tripId: trip.id,
            tripName: trip.name,
            isSettled: true,
          ));
        }
      }
    }

    // 4. Payment Verifications (UPI / Real-time Verification items)
    final verifications = storage.getSavedPaymentVerifications();
    for (final v in verifications) {
      final payerUserId = v['payerUserId'] as String?;
      final receiverUserId = v['receiverUserId'] as String?;
      final payerName = (v['payerName'] as String?)?.trim().toLowerCase() ?? '';
      final receiverName = (v['receiverName'] as String?)?.trim().toLowerCase() ?? '';
      final amt = (v['amountInPaise'] as int?) ?? 0;
      final status = v['status'] as String? ?? 'pending_verification';
      final vDate = v['createdAt'] != null ? DateTime.tryParse(v['createdAt'] as String) ?? DateTime.now() : DateTime.now();

      final isPayerMe = payerUserId == _currentUserId || (payerName.isNotEmpty && payerName == currentUserNameLower);
      final isReceiverMe = receiverUserId == _currentUserId || (receiverName.isNotEmpty && receiverName == currentUserNameLower);
      final isPayerTarget = (_personUserId != null && payerUserId == _personUserId) || payerName == targetNameLower;
      final isReceiverTarget = (_personUserId != null && receiverUserId == _personUserId) || receiverName == targetNameLower;

      if (isPayerMe && isReceiverTarget) {
        aggregated.add(PersonLedgerItem(
          id: v['id'] as String? ?? 'pv_${DateTime.now().millisecondsSinceEpoch}',
          personName: _personName,
          type: status == 'verified' ? PersonLedgerType.paymentVerified : PersonLedgerType.paymentPendingVerification,
          amountInPaise: amt,
          date: vDate,
          title: status == 'verified' ? 'Payment Verified ✓' : 'Payment Sent (Pending Confirmation)',
          note: v['tripName'] != null ? 'Trip: ${v['tripName']}' : 'Direct Settle Up',
          isSettled: status == 'verified',
        ));
      } else if (isReceiverMe && isPayerTarget) {
        aggregated.add(PersonLedgerItem(
          id: v['id'] as String? ?? 'pv_${DateTime.now().millisecondsSinceEpoch}',
          personName: _personName,
          type: status == 'verified' ? PersonLedgerType.paymentVerified : PersonLedgerType.paymentPendingVerification,
          amountInPaise: amt,
          date: vDate,
          title: status == 'verified' ? 'Payment Received & Verified ✓' : 'Payment Received (Please Verify)',
          note: v['tripName'] != null ? 'Trip: ${v['tripName']}' : 'Direct Settle Up',
          isSettled: status == 'verified',
        ));
      }
    }

    // Sort by date ascending for a chat/timeline view (oldest to newest)
    aggregated.sort((a, b) => a.date.compareTo(b.date));

    _items = aggregated;
    _totalLentPaise = lentSum;
    _totalBorrowedPaise = borrowedSum;
    _netBalancePaise = lentSum - borrowedSum;
  }

  Future<void> addLendTransaction({
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    if (_currentUserId == null || amountInPaise <= 0) return;
    await personalRepo.createPersonalDebt(
      userId: _currentUserId!,
      personName: _personName,
      debtType: PersonalDebtType.lent,
      amountInPaise: amountInPaise,
      description: note,
      date: date ?? DateTime.now(),
    );
    await _aggregateTransactions();
    notifyListeners();
  }

  Future<void> addBorrowTransaction({
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    if (_currentUserId == null || amountInPaise <= 0) return;
    await personalRepo.createPersonalDebt(
      userId: _currentUserId!,
      personName: _personName,
      debtType: PersonalDebtType.borrowed,
      amountInPaise: amountInPaise,
      description: note,
      date: date ?? DateTime.now(),
    );
    await _aggregateTransactions();
    notifyListeners();
  }

  /// Records a full or partial settlement transaction
  Future<void> settleBalance({
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    if (_currentUserId == null || amountInPaise <= 0) return;

    // If You owe Person (net < 0): you pay person -> creates a "lent" / payment from you
    // If Person owes You (net > 0): person pays you -> creates a "borrowed" / payment received
    if (_netBalancePaise < 0) {
      await personalRepo.createPersonalDebt(
        userId: _currentUserId!,
        personName: _personName,
        debtType: PersonalDebtType.lent,
        amountInPaise: amountInPaise,
        description: note?.isNotEmpty == true ? note : 'Settlement to $_personName',
        date: date ?? DateTime.now(),
      );
    } else if (_netBalancePaise > 0) {
      await personalRepo.createPersonalDebt(
        userId: _currentUserId!,
        personName: _personName,
        debtType: PersonalDebtType.borrowed,
        amountInPaise: amountInPaise,
        description: note?.isNotEmpty == true ? note : 'Settlement from $_personName',
        date: date ?? DateTime.now(),
      );
    }

    await _aggregateTransactions();
    notifyListeners();
  }

  /// Updates an existing debt transaction
  Future<void> updateDebtTransaction(
    String debtId, {
    required int newAmountInPaise,
    String? newNote,
    DateTime? newDate,
  }) async {
    final cached = personalRepo.getCachedPersonalDebts().debts;
    final index = cached.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final existing = cached[index];
      final updated = existing.copyWith(
        initialAmountInPaise: newAmountInPaise,
        remainingAmountInPaise: newAmountInPaise,
        description: newNote ?? existing.description,
        date: newDate ?? existing.date,
        updatedAt: DateTime.now(),
      );
      await personalRepo.updatePersonalDebt(updated);
      await _aggregateTransactions();
      notifyListeners();
    }
  }

  /// Deletes a transaction from the relationship
  Future<void> deleteTransaction(PersonLedgerItem item) async {
    if (item.referenceId != null) {
      await personalRepo.deletePersonalDebt(item.referenceId!);
      await _aggregateTransactions();
      notifyListeners();
    }
  }
}
