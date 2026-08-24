import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/engine/money_engine.dart';
import '../../domain/engine/voice_parser.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/enums/split_type.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_split.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';

class AddExpenseViewModel extends ChangeNotifier {
  final ExpenseRepository expenseRepo;
  final Uuid _uuid = const Uuid();

  int _currentTab = 2; // 0: Voice, 1: Scan, 2: Manual (default)

  // Form State
  String _title = '';
  int _amountInPaise = 0;
  ExpenseCategory _category = ExpenseCategory.general;
  String _paidById = '';
  SplitType _splitType = SplitType.equal;

  // Split configurations
  final Set<String> _selectedParticipantMemberIds = {};
  final Map<String, int> _exactAmountsInPaise = {};
  final Map<String, int> _shares = {};
  final Map<String, double> _percentages = {};

  // Voice State
  bool _isListening = false;
  String _voiceTranscript = '';
  VoiceExpenseIntent? _parsedIntent;

  bool _isSaving = false;
  String? _errorMessage;

  AddExpenseViewModel({required this.expenseRepo});

  int get currentTab => _currentTab;
  String get title => _title;
  int get amountInPaise => _amountInPaise;
  ExpenseCategory get category => _category;
  String get paidById => _paidById;
  SplitType get splitType => _splitType;
  Set<String> get selectedParticipantMemberIds => _selectedParticipantMemberIds;
  Map<String, int> get exactAmountsInPaise => _exactAmountsInPaise;
  Map<String, int> get shares => _shares;
  Map<String, double> get percentages => _percentages;

  bool get isListening => _isListening;
  String get voiceTranscript => _voiceTranscript;
  VoiceExpenseIntent? get parsedIntent => _parsedIntent;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  bool get isValid => _amountInPaise > 0 && _title.trim().isNotEmpty && _selectedParticipantMemberIds.isNotEmpty;

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void init({
    required Trip trip,
    required String currentUserId,
  }) {
    // Default payer to current user
    final currentMember = trip.members.where((m) => m.userId == currentUserId).firstOrNull;
    _paidById = currentMember?.id ?? (trip.members.isNotEmpty ? trip.members.first.id : '');

    // Default participants to all trip members
    _selectedParticipantMemberIds.clear();
    _selectedParticipantMemberIds.addAll(trip.members.map((m) => m.id));

    // Default shares & percentages
    _shares.clear();
    _percentages.clear();
    _exactAmountsInPaise.clear();

    for (final member in trip.members) {
      _shares[member.id] = 1;
      _percentages[member.id] = 100.0 / (trip.members.isEmpty ? 1 : trip.members.length);
    }

    _title = '';
    _amountInPaise = 0;
    _category = ExpenseCategory.general;
    _splitType = SplitType.equal;
    _isListening = false;
    _voiceTranscript = '';
    _parsedIntent = null;
    _errorMessage = null;

    notifyListeners();
  }

  void setTitle(String val) {
    _title = val;
    notifyListeners();
  }

  void setAmountInPaise(int val) {
    _amountInPaise = val;
    notifyListeners();
  }

  void setCategory(ExpenseCategory cat) {
    _category = cat;
    notifyListeners();
  }

  void setPayer(String memberId) {
    _paidById = memberId;
    notifyListeners();
  }

  void setSplitType(SplitType type) {
    _splitType = type;
    notifyListeners();
  }

  void toggleParticipant(String memberId) {
    if (_selectedParticipantMemberIds.contains(memberId)) {
      if (_selectedParticipantMemberIds.length > 1) {
        _selectedParticipantMemberIds.remove(memberId);
      }
    } else {
      _selectedParticipantMemberIds.add(memberId);
    }
    notifyListeners();
  }

  void setMemberExactAmount(String memberId, int paise) {
    _exactAmountsInPaise[memberId] = paise;
    notifyListeners();
  }

  void setMemberShare(String memberId, int share) {
    _shares[memberId] = share < 1 ? 1 : share;
    notifyListeners();
  }

  // --- Voice Processing ---
  void startVoiceListening() {
    _isListening = true;
    _voiceTranscript = '';
    _parsedIntent = null;
    notifyListeners();
  }

  void stopVoiceListeningWithTranscript(String transcript, List<TripMember> tripMembers) {
    _isListening = false;
    _voiceTranscript = transcript;
    _parsedIntent = VoiceIntentParser.parse(transcript);

    if (_parsedIntent != null && _parsedIntent!.amountInPaise > 0) {
      _amountInPaise = _parsedIntent!.amountInPaise;
      _title = _parsedIntent!.title;
      _category = _parsedIntent!.category;
      _splitType = _parsedIntent!.splitType;

      // Match payer if specified by name
      if (_parsedIntent!.specifiedPayerName != null) {
        final match = tripMembers.where((m) =>
            m.displayName.toLowerCase().contains(_parsedIntent!.specifiedPayerName!.toLowerCase())).firstOrNull;
        if (match != null) {
          _paidById = match.id;
        }
      }

      // Match participants if specific
      if (!_parsedIntent!.forAllParticipants && _parsedIntent!.specifiedParticipantNames.isNotEmpty) {
        _selectedParticipantMemberIds.clear();
        for (final name in _parsedIntent!.specifiedParticipantNames) {
          final match = tripMembers.where((m) =>
              m.displayName.toLowerCase().contains(name.toLowerCase())).firstOrNull;
          if (match != null) {
            _selectedParticipantMemberIds.add(match.id);
          }
        }
        // Include payer in participants if not already
        if (!_selectedParticipantMemberIds.contains(_paidById)) {
          _selectedParticipantMemberIds.add(_paidById);
        }
      }
    }

    notifyListeners();
  }

  /// Calculates the final list of splits based on active split mode.
  List<ExpenseSplit> computeFinalSplits() {
    final participantList = _selectedParticipantMemberIds.toList();

    switch (_splitType) {
      case SplitType.equal:
        return MoneyEngine.calculateEqualSplits(
          totalPaise: _amountInPaise,
          participantMemberIds: participantList,
          priorityMemberId: _paidById,
        );

      case SplitType.exact:
        return participantList.map((id) {
          return ExpenseSplit(
            memberId: id,
            amountInPaise: _exactAmountsInPaise[id] ?? 0,
          );
        }).toList();

      case SplitType.percentage:
        final activePercents = <String, double>{};
        for (final id in participantList) {
          activePercents[id] = _percentages[id] ?? (100.0 / participantList.length);
        }
        return MoneyEngine.calculatePercentageSplits(
          totalPaise: _amountInPaise,
          percentages: activePercents,
        );

      case SplitType.shares:
        final activeShares = <String, int>{};
        for (final id in participantList) {
          activeShares[id] = _shares[id] ?? 1;
        }
        return MoneyEngine.calculateSharesSplits(
          totalPaise: _amountInPaise,
          shares: activeShares,
        );
    }
  }

  Future<Expense?> saveExpense(String tripId) async {
    if (!isValid) {
      _errorMessage = 'Please enter a valid title, amount, and at least one participant';
      notifyListeners();
      return null;
    }

    final splits = computeFinalSplits();
    final isValidSum = MoneyEngine.validateSplits(_amountInPaise, splits);

    if (!isValidSum) {
      _errorMessage = 'Split total must equal total expense amount';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final expense = Expense(
        id: _uuid.v4(),
        tripId: tripId,
        title: _title.trim(),
        amountInPaise: _amountInPaise,
        category: _category,
        paidById: _paidById,
        splits: splits,
        splitType: _splitType,
        voiceTranscript: _voiceTranscript.isNotEmpty ? _voiceTranscript : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await expenseRepo.addExpense(expense);
      return saved;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
