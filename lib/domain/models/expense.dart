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
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    title: json['title'] as String,
    amountInPaise: json['amountInPaise'] as int,
    category: ExpenseCategory.fromString(json['category'] as String? ?? 'general'),
    paidById: json['paidById'] as String,
    splits: (json['splits'] as List<dynamic>?)
            ?.map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    splitType: SplitType.fromString(json['splitType'] as String? ?? 'equal'),
    location: json['location'] as String?,
    receiptUrl: json['receiptUrl'] as String?,
    voiceTranscript: json['voiceTranscript'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    isDeleted: json['isDeleted'] as bool? ?? false,
  );
}
