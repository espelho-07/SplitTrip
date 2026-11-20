import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/engine/multi_expense_voice_parser.dart';
import '../../domain/enums/expense_category.dart';
import '../../domain/enums/split_type.dart';
import '../../domain/models/expense_draft.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_member.dart';

/// Represents a mutable, discrete expense draft item in the Voice Review flow.
class VoiceReviewItem {
  final String id;
  String title;
  int amountInPaise;
  ExpenseCategory category;
  String? payerMemberId;
  String? payerName;
  List<String> participantMemberIds;
  SplitType splitType;
  List<String> unresolvedFields;
  List<TripMember> candidatePayers;
  String? ambiguityMessage;
  String rawInput;
  DateTime? expenseDate;
  String currency;

  VoiceReviewItem({
    required this.id,
    required this.title,
    required this.amountInPaise,
    required this.category,
    this.payerMemberId,
    this.payerName,
    this.participantMemberIds = const [],
    this.splitType = SplitType.equal,
    this.unresolvedFields = const [],
    this.candidatePayers = const [],
    this.ambiguityMessage,
    this.rawInput = '',
    this.expenseDate,
    this.currency = 'INR',
  });

  bool get isReady =>
      amountInPaise > 0 &&
      title.trim().isNotEmpty &&
      payerMemberId != null &&
      participantMemberIds.isNotEmpty &&
      unresolvedFields.isEmpty;

  VoiceReviewItem copyWith({
    String? id,
    String? title,
    int? amountInPaise,
    ExpenseCategory? category,
    String? payerMemberId,
    String? payerName,
    List<String>? participantMemberIds,
    SplitType? splitType,
    List<String>? unresolvedFields,
    List<TripMember>? candidatePayers,
    String? ambiguityMessage,
    String? rawInput,
    DateTime? expenseDate,
    String? currency,
  }) {
    return VoiceReviewItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      category: category ?? this.category,
      payerMemberId: payerMemberId ?? this.payerMemberId,
      payerName: payerName ?? this.payerName,
      participantMemberIds: participantMemberIds ?? this.participantMemberIds,
      splitType: splitType ?? this.splitType,
      unresolvedFields: unresolvedFields ?? this.unresolvedFields,
      candidatePayers: candidatePayers ?? this.candidatePayers,
      ambiguityMessage: ambiguityMessage ?? this.ambiguityMessage,
      rawInput: rawInput ?? this.rawInput,
      expenseDate: expenseDate ?? this.expenseDate,
      currency: currency ?? this.currency,
    );
  }

  ExpenseDraft toDraft() {
    return ExpenseDraft(
      amountInPaise: amountInPaise,
      title: title.trim(),
      category: category,
      payerMemberId: payerMemberId,
      payerName: payerName,
      participantMemberIds: participantMemberIds,
      splitType: splitType,
      confidence: isReady ? 1.0 : 0.5,
      rawInput: rawInput,
      source: ExpenseDraftSource.voice,
      unresolvedFields: unresolvedFields,
      candidatePayers: candidatePayers,
      ambiguityMessage: ambiguityMessage,
      expenseDate: expenseDate,
      currency: currency,
    );
  }
}

/// ViewModel governing the Voice Review and Multi-Expense Correction experience.
class VoiceReviewViewModel extends ChangeNotifier {
  final Uuid _uuid;
  final Trip? trip;
  final List<TripMember> members;
  final String? currentUserId;

  String _transcript;
  List<VoiceReviewItem> _items = [];

  VoiceReviewViewModel({
    required String initialTranscript,
    List<ExpenseDraft> initialDrafts = const [],
    this.trip,
    this.members = const [],
    this.currentUserId,
    Uuid? uuid,
  })  : _transcript = initialTranscript,
        _uuid = uuid ?? const Uuid() {
    if (initialDrafts.isNotEmpty) {
      _items = initialDrafts.map((d) => _fromDraft(d)).toList();
    } else {
      reparse(_transcript);
    }
  }

  String get transcript => _transcript;
  List<VoiceReviewItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

  /// Total sum of all items in paise (strictly integer arithmetic).
  int get totalInPaise => _items.fold<int>(0, (sum, item) => sum + item.amountInPaise);

  /// True if all items are ready for batch confirmation.
  bool get isValid => _items.isNotEmpty && _items.every((item) => item.isReady);

  /// Reparses the transcript using [MultiExpenseVoiceParser].
  void reparse(String newTranscript) {
    _transcript = newTranscript.trim();
    final drafts = MultiExpenseVoiceParser.parse(
      _transcript,
      members: members,
      currentUserId: currentUserId,
    );
    _items = drafts.map((d) => _fromDraft(d)).toList();
    notifyListeners();
  }

  void updateTitle(String id, String newTitle) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].title = newTitle;
      notifyListeners();
    }
  }

  void updateAmount(String id, int newAmountInPaise) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].amountInPaise = newAmountInPaise;
      if (newAmountInPaise > 0) {
        _items[idx].unresolvedFields.remove('amount');
        if (_items[idx].unresolvedFields.isEmpty) {
          _items[idx].ambiguityMessage = null;
        }
      }
      notifyListeners();
    }
  }

  void updateCategory(String id, ExpenseCategory newCategory) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].category = newCategory;
      notifyListeners();
    }
  }

  void updatePayer(String id, String memberId, String memberName) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].payerMemberId = memberId;
      _items[idx].payerName = memberName;
      _items[idx].unresolvedFields.remove('payer_ambiguity');
      _items[idx].candidatePayers = const [];
      if (_items[idx].unresolvedFields.isEmpty) {
        _items[idx].ambiguityMessage = null;
      }
      notifyListeners();
    }
  }

  void updateParticipants(String id, List<String> participantIds) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].participantMemberIds = participantIds;
      if (participantIds.isNotEmpty) {
        _items[idx].unresolvedFields.remove('participants');
      }
      notifyListeners();
    }
  }

  void updateDate(String id, DateTime newDate) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].expenseDate = newDate;
      notifyListeners();
    }
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void addItem({
    String title = 'Expense',
    int amountInPaise = 0,
    ExpenseCategory category = ExpenseCategory.general,
  }) {
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ?? members.firstOrNull;
    final allMemberIds = members.map((m) => m.id).toList();

    final newItem = VoiceReviewItem(
      id: _uuid.v4(),
      title: title,
      amountInPaise: amountInPaise,
      category: category,
      payerMemberId: selfMember?.id,
      payerName: selfMember?.displayName ?? 'You',
      participantMemberIds: allMemberIds,
      splitType: SplitType.equal,
      unresolvedFields: amountInPaise <= 0 ? ['amount'] : [],
      rawInput: 'Manually added',
    );

    _items.add(newItem);
    notifyListeners();
  }

  List<ExpenseDraft> toExpenseDrafts() {
    return _items.map((i) => i.toDraft()).toList();
  }

  VoiceReviewItem _fromDraft(ExpenseDraft draft) {
    // If payer is missing but we have self member, set self member
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ?? members.firstOrNull;
    final payerId = draft.payerMemberId ?? selfMember?.id;
    final payerName = draft.payerName ?? selfMember?.displayName ?? 'You';

    // If participants are empty, default to all members
    final participantIds = draft.participantMemberIds.isNotEmpty
        ? draft.participantMemberIds
        : members.map((m) => m.id).toList();

    return VoiceReviewItem(
      id: _uuid.v4(),
      title: draft.title,
      amountInPaise: draft.amountInPaise,
      category: draft.category,
      payerMemberId: payerId,
      payerName: payerName,
      participantMemberIds: participantIds,
      splitType: draft.splitType,
      unresolvedFields: List<String>.from(draft.unresolvedFields),
      candidatePayers: List<TripMember>.from(draft.candidatePayers),
      ambiguityMessage: draft.ambiguityMessage,
      rawInput: draft.rawInput,
      expenseDate: draft.expenseDate,
      currency: draft.currency ?? trip?.currencyCode ?? 'INR',
    );
  }
}
