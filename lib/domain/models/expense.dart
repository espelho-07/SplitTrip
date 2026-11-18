import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import 'expense_split.dart';

/// Immutable Expense entity.
/// All monetary math is stored in integer paise.
class Expense {
  final String id;
  final String tripId;
  final String title;
  final int amountInPaise;
  final ExpenseCategory category;
  final String paidById;
  final Map<String, int>? paidByMap;
  final List<ExpenseSplit> splits;
  final SplitType splitType;
  final String? location;
  final String? receiptUrl;
  final String? voiceTranscript;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amountInPaise,
    required this.category,
    required this.paidById,
    this.paidByMap,
    required this.splits,
    this.splitType = SplitType.equal,
    this.location,
    this.receiptUrl,
    this.voiceTranscript,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Expense copyWith({
    String? id,
    String? tripId,
    String? title,
    int? amountInPaise,
    ExpenseCategory? category,
    String? paidById,
    Map<String, int>? paidByMap,
    List<ExpenseSplit>? splits,
    SplitType? splitType,
    String? location,
    String? receiptUrl,
    String? voiceTranscript,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      category: category ?? this.category,
      paidById: paidById ?? this.paidById,
      paidByMap: paidByMap ?? this.paidByMap,
      splits: splits ?? this.splits,
      splitType: splitType ?? this.splitType,
      location: location ?? this.location,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'amountInPaise': amountInPaise,
    'category': category.name,
    'paidById': paidById,
    if (paidByMap != null && paidByMap!.isNotEmpty) 'paidByMap': paidByMap,
    'splits': splits.map((s) => s.toJson()).toList(),
    'splitType': splitType.name,
    if (location != null && location!.isNotEmpty) 'location': location,
    'receiptUrl': receiptUrl,
    'voiceTranscript': voiceTranscript,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: (json['id'] ?? '').toString(),
    tripId: (json['tripId'] ?? json['trip_id'] ?? '').toString(),
    title: (json['title'] ?? 'Expense').toString(),
    amountInPaise: (json['amountInPaise'] as num?)?.toInt() ??
        (json['amount_in_paise'] as num?)?.toInt() ??
        ((json['amount'] as num?)?.toDouble() != null ? ((json['amount'] as num).toDouble() * 100).round() : 0),
    category: ExpenseCategory.fromString((json['category'] ?? 'general').toString()),
    paidById: (json['paidById'] ?? json['paid_by_id'] ?? json['paidByMemberId'])?.toString() ??
        (json['paidByMap'] is Map && (json['paidByMap'] as Map).isNotEmpty
            ? (json['paidByMap'] as Map).keys.first.toString()
            : ''),
    paidByMap: json['paidByMap'] != null && json['paidByMap'] is Map
        ? (json['paidByMap'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
        : (json['paid_by_map'] != null && json['paid_by_map'] is Map
            ? (json['paid_by_map'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
            : null),
    splits: (json['splits'] as List<dynamic>?)
            ?.map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    splitType: SplitType.fromString((json['splitType'] ?? json['split_type'] ?? 'equal').toString()),
    location: json['location'] as String?,
    receiptUrl: (json['receiptUrl'] ?? json['receipt_url']) as String?,
    voiceTranscript: (json['voiceTranscript'] ?? json['voice_transcript']) as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : (json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now()),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now() : DateTime.now()),
    isDeleted: (json['isDeleted'] ?? json['is_deleted']) as bool? ?? false,
  );
}
