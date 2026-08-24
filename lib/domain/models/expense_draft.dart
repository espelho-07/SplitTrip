import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import 'trip_member.dart';

enum ExpenseDraftSource {
  voice,
  receiptOcr,
  manual,
}

/// Intermediate structured expense representation extracted from AI, Voice, or OCR.
/// Requires explicit user confirmation and deterministic MoneyEngine validation before persistence.
class ExpenseDraft {
  final int amountInPaise;
  final String title;
  final ExpenseCategory category;
  final String? payerMemberId;
  final String? payerName;
  final List<String> participantMemberIds;
  final SplitType splitType;
  final double confidence;
  final String rawInput;
  final ExpenseDraftSource source;
  final List<String> unresolvedFields;
  final List<TripMember> candidatePayers;
  final String? ambiguityMessage;

  const ExpenseDraft({
    required this.amountInPaise,
    required this.title,
    required this.category,
    this.payerMemberId,
    this.payerName,
    this.participantMemberIds = const [],
    this.splitType = SplitType.equal,
    required this.confidence,
    required this.rawInput,
    required this.source,
    this.unresolvedFields = const [],
    this.candidatePayers = const [],
    this.ambiguityMessage,
  });

  bool get isReadyForConfirmation =>
      amountInPaise > 0 &&
      title.trim().isNotEmpty &&
      payerMemberId != null &&
      participantMemberIds.isNotEmpty &&
      unresolvedFields.isEmpty;

  ExpenseDraft copyWith({
    int? amountInPaise,
    String? title,
    ExpenseCategory? category,
    String? payerMemberId,
    String? payerName,
    List<String>? participantMemberIds,
    SplitType? splitType,
    double? confidence,
    String? rawInput,
    ExpenseDraftSource? source,
    List<String>? unresolvedFields,
    List<TripMember>? candidatePayers,
    String? ambiguityMessage,
  }) {
    return ExpenseDraft(
      amountInPaise: amountInPaise ?? this.amountInPaise,
      title: title ?? this.title,
      category: category ?? this.category,
      payerMemberId: payerMemberId ?? this.payerMemberId,
      payerName: payerName ?? this.payerName,
      participantMemberIds: participantMemberIds ?? this.participantMemberIds,
      splitType: splitType ?? this.splitType,
      confidence: confidence ?? this.confidence,
      rawInput: rawInput ?? this.rawInput,
      source: source ?? this.source,
      unresolvedFields: unresolvedFields ?? this.unresolvedFields,
      candidatePayers: candidatePayers ?? this.candidatePayers,
      ambiguityMessage: ambiguityMessage ?? this.ambiguityMessage,
    );
  }
}
