import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/voice_speech_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/error_formatter.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/engine/money_engine.dart';
import '../../domain/engine/receipt_parser_engine.dart';
import '../../domain/engine/voice_parser.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/enums/split_type.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_draft.dart';
import '../../domain/models/expense_split.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';

class AddExpenseViewModel extends ChangeNotifier {
  final ExpenseRepository expenseRepo;
  final VoiceSpeechService _speechService = VoiceSpeechService();
  final Uuid _uuid = const Uuid();

  int _currentTab = 2; // 0: Voice, 1: Scan, 2: Manual (default)

  // Form State
  String _title = '';
  int _amountInPaise = 0;
  ExpenseCategory _category = ExpenseCategory.general;
  bool _userExplicitlySelectedCategory = false;
  String _location = '';
  String _paidById = '';
  bool _isMultiplePayers = false;
  final Map<String, int> _payerAmountsInPaise = {};
  SplitType _splitType = SplitType.equal;

  // Split configurations
  final Set<String> _selectedParticipantMemberIds = {};
  final Map<String, int> _exactAmountsInPaise = {};
  final Map<String, int> _shares = {};
  final Map<String, double> _percentages = {};

  // Voice & OCR State
  bool _isListening = false;
  String _voiceTranscript = '';
  String? _receiptUrl;
  VoiceExpenseIntent? _parsedIntent;
  ExpenseDraft? _activeDraft;
  bool _isEditMode = false;
  String? _editingExpenseId;
  String? _draftExpenseId;
  DateTime? _createdAt;

  DateTime? get createdAt => _createdAt;
  String? get receiptUrl => _receiptUrl;

  void setReceiptUrl(String? url) {
    _receiptUrl = url;
    notifyListeners();
  }

  void setDate(DateTime date) {
    _createdAt = date;
    notifyListeners();
  }

  bool _isSaving = false;
  String? _errorMessage;

  AddExpenseViewModel({required this.expenseRepo});

  int get currentTab => _currentTab;
  bool get isEditMode => _isEditMode;
  String? get editingExpenseId => _editingExpenseId;
  String get title => _title;
  int get amountInPaise => _amountInPaise;
  ExpenseCategory get category => _category;
  bool get userExplicitlySelectedCategory => _userExplicitlySelectedCategory;
  String get location => _location;
  String get paidById => _paidById;
  bool get isMultiplePayers => _isMultiplePayers;
  Map<String, int> get payerAmountsInPaise => _payerAmountsInPaise;

  void toggleMultiplePayers(bool value) {
    _isMultiplePayers = value;
    if (_isMultiplePayers) {
      if (_payerAmountsInPaise.isEmpty) {
        final primaryPayer = _paidById.isNotEmpty ? _paidById : '';
        if (primaryPayer.isNotEmpty) {
          _payerAmountsInPaise[primaryPayer] = _amountInPaise;
        }
      } else if (_payerAmountsInPaise.length == 1) {
        _payerAmountsInPaise[_payerAmountsInPaise.keys.first] = _amountInPaise;
      }
    } else {
      if (_payerAmountsInPaise.isNotEmpty) {
        String primaryPayer = _payerAmountsInPaise.keys.first;
        int maxAmt = -1;
        for (final entry in _payerAmountsInPaise.entries) {
          if (entry.value > maxAmt) {
            maxAmt = entry.value;
            primaryPayer = entry.key;
          }
        }
        _paidById = primaryPayer;
      }
      _payerAmountsInPaise.clear();
    }
    notifyListeners();
  }

  void togglePayerSelection(String memberId) {
    if (!_isMultiplePayers) {
      _paidById = memberId;
      notifyListeners();
      return;
    }

    if (_payerAmountsInPaise.containsKey(memberId)) {
      if (_payerAmountsInPaise.length <= 1) return;
      _payerAmountsInPaise.remove(memberId);
    } else {
      _payerAmountsInPaise[memberId] = 0;
    }

    distributeEqualAmongPayers();
  }

  void distributeEqualAmongPayers() {
    if (_payerAmountsInPaise.isEmpty) return;

    if (_amountInPaise <= 0) {
      for (final pid in _payerAmountsInPaise.keys) {
        _payerAmountsInPaise[pid] = 0;
      }
      notifyListeners();
      return;
    }

    final payers = _payerAmountsInPaise.keys.toList();
    final base = _amountInPaise ~/ payers.length;
    var rem = _amountInPaise % payers.length;

    for (final pid in payers) {
      _payerAmountsInPaise[pid] = base + (rem > 0 ? 1 : 0);
      if (rem > 0) rem--;
    }
    notifyListeners();
  }

  void setPayerAmount(String memberId, int amountInPaise) {
    _payerAmountsInPaise[memberId] = amountInPaise < 0 ? 0 : amountInPaise;
    notifyListeners();
  }

  void removePayer(String memberId) {
    if (_payerAmountsInPaise.length <= 1) return;
    _payerAmountsInPaise.remove(memberId);
    distributeEqualAmongPayers();
  }

  int get totalPayerAllocatedPaise => _payerAmountsInPaise.values.fold(0, (sum, val) => sum + val);
  int get remainingPayerPaise => _amountInPaise - totalPayerAllocatedPaise;
  bool get isPayerAllocationBalanced => _isMultiplePayers ? totalPayerAllocatedPaise == _amountInPaise : true;

  SplitType get splitType => _splitType;
  Set<String> get selectedParticipantMemberIds => _selectedParticipantMemberIds;
  Map<String, int> get exactAmountsInPaise => _exactAmountsInPaise;
  Map<String, int> get shares => _shares;
  Map<String, double> get percentages => _percentages;

  int get exactAllocatedPaise => _selectedParticipantMemberIds.fold(0, (sum, id) => sum + (_exactAmountsInPaise[id] ?? 0));
  int get exactRemainingPaise => _amountInPaise - exactAllocatedPaise;
  double get totalAllocatedPercentage => _selectedParticipantMemberIds.fold(0.0, (sum, id) => sum + (_percentages[id] ?? 0.0));

  bool get isListening => _isListening;
  String get voiceTranscript => _voiceTranscript;
  VoiceExpenseIntent? get parsedIntent => _parsedIntent;
  ExpenseDraft? get activeDraft => _activeDraft;
  VoiceSpeechService get speechService => _speechService;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  bool get isValid => _amountInPaise > 0 && _selectedParticipantMemberIds.isNotEmpty;

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void init({
    required Trip trip,
    required String currentUserId,
  }) {
    _isEditMode = false;
    _editingExpenseId = null;
    _createdAt = null;
    _currentTab = 2; // Default to Manual tab
    _title = '';
    _amountInPaise = 0;
    _category = ExpenseCategory.general;
    _userExplicitlySelectedCategory = false;
    _location = '';
    _splitType = SplitType.equal;

    // Default payer to current user
    final currentMember = trip.members.where((m) => m.userId == currentUserId).firstOrNull;
    _paidById = currentMember?.id ?? (trip.members.isNotEmpty ? trip.members.first.id : '');
    _isMultiplePayers = false;
    _payerAmountsInPaise.clear();

    // Default participants to all trip members
    _selectedParticipantMemberIds.clear();
    _selectedParticipantMemberIds.addAll(trip.members.map((m) => m.id));

    // Default shares & percentages
    _shares.clear();
    _percentages.clear();
    _exactAmountsInPaise.clear();

    for (final member in trip.members) {
      _shares[member.id] = 1;
      _percentages[member.id] = 100.0 / trip.members.length;
    }

    _isListening = false;
    _voiceTranscript = '';
    _receiptUrl = null;
    _parsedIntent = null;
    _activeDraft = null;
    _errorMessage = null;

    notifyListeners();
  }

  void initFromContext({
    required Trip trip,
    required String currentUserId,
    String? preselectedMemberId,
    String? preselectedPayerId,
    ExpenseCategory? category,
    int? initialAmountInPaise,
    String? initialTitle,
    String? initialReceiptUrl,
    SplitType? splitType,
  }) {
    init(trip: trip, currentUserId: currentUserId);
    if (initialReceiptUrl != null && initialReceiptUrl.isNotEmpty) {
      _receiptUrl = initialReceiptUrl;
    }
    if (initialTitle != null && initialTitle.isNotEmpty) {
      _title = initialTitle;
      final predicted = ExpenseCategory.predictFromTitle(initialTitle);
      if (predicted != null && category == null) {
        _category = predicted;
      }
    }
    if (initialAmountInPaise != null && initialAmountInPaise > 0) {
      _amountInPaise = initialAmountInPaise;
    }
    if (category != null) {
      _category = category;
      _userExplicitlySelectedCategory = true;
    }
    if (splitType != null) {
      _splitType = splitType;
    }
    if (preselectedPayerId != null && preselectedPayerId.isNotEmpty) {
      _paidById = preselectedPayerId;
    }

    // If a specific member is pre-selected for a 1-on-1 split context:
    if (preselectedMemberId != null && preselectedMemberId.isNotEmpty) {
      final currentMember = trip.members.where((m) => m.userId == currentUserId).firstOrNull;
      final currentMemberId = currentMember?.id ?? currentUserId;
      _selectedParticipantMemberIds.clear();
      _selectedParticipantMemberIds.add(currentMemberId);
      _selectedParticipantMemberIds.add(preselectedMemberId);
    }
    notifyListeners();
  }

  void initForEdit({
    required Expense expense,
    required Trip trip,
    required String currentUserId,
  }) {
    _isEditMode = true;
    _editingExpenseId = expense.id;
    _createdAt = expense.createdAt;
    _title = expense.title;
    _amountInPaise = expense.amountInPaise;
    _category = expense.category;
    _userExplicitlySelectedCategory = true;
    _location = expense.location ?? '';
    _paidById = expense.paidById;
    if (expense.paidByMap != null && expense.paidByMap!.isNotEmpty) {
      _isMultiplePayers = true;
      _payerAmountsInPaise.clear();
      _payerAmountsInPaise.addAll(expense.paidByMap!);
    } else {
      _isMultiplePayers = false;
      _payerAmountsInPaise.clear();
    }
    _splitType = expense.splitType;
    _currentTab = 2; // Manual edit tab

    _selectedParticipantMemberIds.clear();
    _selectedParticipantMemberIds.addAll(expense.splits.map((s) => s.memberId));

    _exactAmountsInPaise.clear();
    _shares.clear();
    _percentages.clear();

    // Populate split allocations from existing expense
    for (final split in expense.splits) {
      _exactAmountsInPaise[split.memberId] = split.amountInPaise;
      _shares[split.memberId] = split.shares ?? 1;
      _percentages[split.memberId] = split.percentage ?? (100.0 / expense.splits.length);
    }

    for (final member in trip.members) {
      if (!_shares.containsKey(member.id)) _shares[member.id] = 1;
      if (!_percentages.containsKey(member.id)) _percentages[member.id] = 100.0 / trip.members.length;
    }

    _isListening = false;
    _voiceTranscript = '';
    _receiptUrl = expense.receiptUrl;
    _parsedIntent = null;
    _activeDraft = null;
    _errorMessage = null;

    notifyListeners();
  }

  /// Ingests structured and user-confirmed [ReceiptData], pre-populating
  /// merchant name, verified total in paise, predicted category, receipt date,
  /// receipt number notes, and receipt attachment file path.
  void applyReceiptData(ReceiptData receipt) {
    if (receipt.merchant.name != null && receipt.merchant.name!.trim().isNotEmpty) {
      _title = receipt.merchant.name!.trim();
    }
    final total = receipt.summary.totalInPaise ?? receipt.calculatedTotalInPaise;
    if (total > 0) {
      setAmountInPaise(total);
    }
    _receiptUrl = receipt.imagePath;
    if (receipt.predictedCategory != null) {
      _category = receipt.predictedCategory!;
      _userExplicitlySelectedCategory = true;
    }
    if (receipt.receipt.date != null) {
      _createdAt = receipt.receipt.date;
    }
    if (receipt.merchant.address != null && receipt.merchant.address!.trim().isNotEmpty) {
      _location = receipt.merchant.address!.trim();
    }
    if (receipt.receipt.receiptNumber != null && receipt.receipt.receiptNumber!.trim().isNotEmpty) {
      _voiceTranscript = 'Receipt #${receipt.receipt.receiptNumber!.trim()}';
    }
    _currentTab = 2; // Switch to manual form tab
    notifyListeners();
  }

  void setTitle(String value, {bool autoPredictCategory = true}) {
    _title = value;
    if (autoPredictCategory && !_userExplicitlySelectedCategory) {
      final predicted = ExpenseCategory.predictFromTitle(value);
      if (predicted != null) {
        _category = predicted;
      }
    }
    notifyListeners();
  }

  void setAmountInPaise(int value) {
    _amountInPaise = value < 0 ? 0 : value;
    if (_isMultiplePayers && _payerAmountsInPaise.isNotEmpty) {
      if (_payerAmountsInPaise.length == 1) {
        _payerAmountsInPaise[_payerAmountsInPaise.keys.first] = _amountInPaise;
      } else {
        // If payers have not been customized yet (all 0) or are balanced, automatically re-distribute
        final allZero = _payerAmountsInPaise.values.every((v) => v == 0);
        if (allZero) {
          distributeEqualAmongPayers();
          return;
        }
      }
    }
    notifyListeners();
  }

  void setCategory(ExpenseCategory cat, {bool explicit = true}) {
    _category = cat;
    if (explicit) {
      _userExplicitlySelectedCategory = true;
    }
    notifyListeners();
  }

  void setLocation(String value) {
    _location = value;
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

  void toggleParticipant(String memberId, {bool allowEmpty = true}) {
    if (_selectedParticipantMemberIds.contains(memberId)) {
      if (allowEmpty || _selectedParticipantMemberIds.length > 1) {
        _selectedParticipantMemberIds.remove(memberId);
      }
    } else {
      _selectedParticipantMemberIds.add(memberId);
    }
    notifyListeners();
  }

  void selectAllParticipants(List<String> memberIds) {
    _selectedParticipantMemberIds.clear();
    _selectedParticipantMemberIds.addAll(memberIds);
    notifyListeners();
  }

  void unselectAllParticipants() {
    _selectedParticipantMemberIds.clear();
    notifyListeners();
  }

  void setMemberExactAmount(String memberId, int paise) {
    _exactAmountsInPaise[memberId] = paise < 0 ? 0 : paise;
    notifyListeners();
  }

  void setMemberPercentage(String memberId, double percent) {
    _percentages[memberId] = percent < 0 ? 0 : percent;
    notifyListeners();
  }

  void setMemberShare(String memberId, int share) {
    _shares[memberId] = share < 1 ? 1 : share;
    notifyListeners();
  }

  // --- Voice & OCR Intelligence ---
  /// Silently stops any active voice listening - call from view dispose()
  /// to prevent notifyListeners() firing into a dead widget tree.
  void cancelVoice() {
    if (_isListening) {
      _isListening = false;
      _speechService.stopListening().ignore();
      // Do NOT call notifyListeners() here - the widget may already be disposed
    }
  }

  Future<bool> startLiveVoiceListening({
    required Function(ExpenseDraft draft) onDraftReady,
    required List<TripMember> tripMembers,
    required String currentUserId,
  }) async {
    _isListening = true;
    _voiceTranscript = '';
    _parsedIntent = null;
    _activeDraft = null;
    if (hasListeners) notifyListeners();

    final started = await _speechService.startListening(
      onResult: (words, isFinal) {
        _voiceTranscript = words;
        if (hasListeners) notifyListeners();

        if (isFinal && words.trim().isNotEmpty) {
          final draft = parseVoiceToDraft(words, tripMembers, currentUserId);
          onDraftReady(draft);
        }
      },
    );

    if (!started) {
      _isListening = false;
      if (hasListeners) notifyListeners();
    }

    return started;
  }

  Future<void> stopLiveVoiceListening({
    required List<TripMember> tripMembers,
    required String currentUserId,
    Function(ExpenseDraft draft)? onDraftReady,
  }) async {
    _isListening = false;
    await _speechService.stopListening();
    if (hasListeners) notifyListeners();

    if (_voiceTranscript.trim().isNotEmpty) {
      final draft = parseVoiceToDraft(_voiceTranscript, tripMembers, currentUserId);
      onDraftReady?.call(draft);
    }
  }

  void startVoiceListening() {
    _isListening = true;
    _voiceTranscript = '';
    _parsedIntent = null;
    _activeDraft = null;
    notifyListeners();
  }

  ExpenseDraft parseVoiceToDraft(String transcript, List<TripMember> tripMembers, String currentUserId) {
    _isListening = false;
    _voiceTranscript = transcript;
    _parsedIntent = VoiceIntentParser.parse(transcript);

    final draft = VoiceIntentParser.parseToDraft(transcript, tripMembers, currentUserId);
    _activeDraft = draft;

    applyDraft(draft);
    return draft;
  }

  /// Parses voice transcript into multiple discrete [ExpenseDraft]s for batch confirmation.
  List<ExpenseDraft> parseMultipleVoiceDrafts(String transcript, List<TripMember> tripMembers, String currentUserId) {
    _isListening = false;
    _voiceTranscript = transcript;
    return VoiceIntentParser.parseMultipleToDrafts(transcript, tripMembers, currentUserId);
  }

  ExpenseDraft parseReceiptToDraft(String ocrText, List<TripMember> tripMembers, String currentUserId) {
    final draft = ReceiptParserEngine.parseToDraft(ocrText, tripMembers, currentUserId);
    _activeDraft = draft;

    applyDraft(draft);
    return draft;
  }

  void applyDraft(ExpenseDraft draft) {
    if (draft.amountInPaise > 0) {
      _amountInPaise = draft.amountInPaise;
    }
    if (draft.title.isNotEmpty) {
      _title = draft.title;
    }
    _category = draft.category;
    _userExplicitlySelectedCategory = true;
    _splitType = draft.splitType;

    if (draft.payerMemberId != null && draft.payerMemberId!.isNotEmpty) {
      _paidById = draft.payerMemberId!;
    }

    if (draft.participantMemberIds.isNotEmpty) {
      _selectedParticipantMemberIds.clear();
      _selectedParticipantMemberIds.addAll(draft.participantMemberIds);
    }

    if (draft.expenseDate != null) {
      _createdAt = draft.expenseDate;
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

  Future<Expense?> saveConfirmedDraft(String tripId, ExpenseDraft draft) async {
    applyDraft(draft);
    return saveExpense(tripId);
  }

  /// Atomically batches and persists multiple confirmed [ExpenseDraft]s extracted from Voice AI.
  Future<List<Expense>> saveMultipleConfirmedDrafts(String tripId, List<ExpenseDraft> drafts) async {
    final created = <Expense>[];
    for (final draft in drafts) {
      applyDraft(draft);
      final expense = await saveExpense(tripId);
      if (expense != null) {
        created.add(expense);
      }
    }
    return created;
  }

  Future<Expense?> saveExpense(String tripId) async {
    if (_isSaving) return null;

    if (!isValid) {
      _errorMessage = 'Please enter a valid amount and select at least one participant';
      notifyListeners();
      return null;
    }

    final effectiveTitle = _title.trim().isNotEmpty
        ? _title.trim()
        : (_category.displayName.isNotEmpty ? _category.displayName : 'Expense');

    final splits = computeFinalSplits();
    final isValidSum = MoneyEngine.validateSplits(_amountInPaise, splits);

    if (!isValidSum) {
      _errorMessage = 'Split total must strictly equal total expense amount';
      notifyListeners();
      return null;
    }

    final effectivePaidByMap = _isMultiplePayers && _payerAmountsInPaise.isNotEmpty
        ? Map<String, int>.from(_payerAmountsInPaise)
        : null;

    if (effectivePaidByMap != null) {
      final totalPaidByMembers = effectivePaidByMap.values.fold(0, (sum, val) => sum + val);
      if (totalPaidByMembers != _amountInPaise) {
        final paidFormatted = CurrencyFormatter.formatPaise(totalPaidByMembers);
        final totalFormatted = CurrencyFormatter.formatPaise(_amountInPaise);
        _errorMessage = 'Total paid by members ($paidFormatted) must strictly equal total expense amount ($totalFormatted)';
        notifyListeners();
        return null;
      }
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isEditMode && _editingExpenseId != null) {
        final updatedExpense = Expense(
          id: _editingExpenseId!,
          tripId: tripId,
          title: effectiveTitle,
          amountInPaise: _amountInPaise,
          category: _category,
          location: _location.trim().isNotEmpty ? _location.trim() : null,
          receiptUrl: _receiptUrl,
          paidById: _paidById.isNotEmpty ? _paidById : (effectivePaidByMap?.keys.first ?? ''),
          paidByMap: effectivePaidByMap,
          splits: splits,
          splitType: _splitType,
          voiceTranscript: _voiceTranscript.isNotEmpty ? _voiceTranscript : null,
          createdAt: _createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final saved = await expenseRepo.updateExpense(updatedExpense);
        return saved;
      } else {
        _draftExpenseId ??= _uuid.v4();
        final expense = Expense(
          id: _draftExpenseId!,
          tripId: tripId,
          title: effectiveTitle,
          amountInPaise: _amountInPaise,
          category: _category,
          location: _location.trim().isNotEmpty ? _location.trim() : null,
          receiptUrl: _receiptUrl,
          paidById: _paidById.isNotEmpty ? _paidById : (effectivePaidByMap?.keys.first ?? ''),
          paidByMap: effectivePaidByMap,
          splits: splits,
          splitType: _splitType,
          voiceTranscript: _voiceTranscript.isNotEmpty ? _voiceTranscript : null,
          createdAt: _createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final saved = await expenseRepo.addExpense(expense);
        _draftExpenseId = null;
        return saved;
      }
    } catch (e) {
      _errorMessage = KithErrorFormatter.format(e);
      return null;
    } finally {
      _isSaving = false;
      if (hasListeners) notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed && hasListeners) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
