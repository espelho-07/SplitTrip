import '../enums/expense_category.dart';

/// Represents an individual personal expense.
/// Strictly uses integer paise precision for money calculations.
class PersonalExpense {
  final String id;
  final String userId;
  final String title;
  final int amountInPaise;
  final ExpenseCategory category;
  final DateTime date;
  final String? notes;
  final String? voiceTranscript;
  final String? receiptUrl;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalExpense({
    required this.id,
    required this.userId,
    required this.title,
    required this.amountInPaise,
    this.category = ExpenseCategory.general,
    required this.date,
    this.notes,
    this.voiceTranscript,
    this.receiptUrl,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  PersonalExpense copyWith({
    String? id,
    String? userId,
    String? title,
    int? amountInPaise,
    ExpenseCategory? category,
    DateTime? date,
    String? notes,
    String? voiceTranscript,
    String? receiptUrl,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalExpense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PersonalExpense.fromJson(Map<String, dynamic> json) {
    return PersonalExpense(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      title: json['title'] as String,
      amountInPaise: (json['amountInPaise'] ?? json['amount_in_paise'] as num).toInt(),
      category: ExpenseCategory.fromName(json['category'] as String?),
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      notes: json['notes'] as String?,
      voiceTranscript: json['voiceTranscript'] ?? json['voice_transcript'] as String?,
      receiptUrl: json['receiptUrl'] ?? json['receipt_url'] as String?,
      isDeleted: json['isDeleted'] ?? json['is_deleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amountInPaise': amountInPaise,
      'category': category.name,
      'date': date.toIso8601String(),
      'notes': notes,
      'voiceTranscript': voiceTranscript,
      'receiptUrl': receiptUrl,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
