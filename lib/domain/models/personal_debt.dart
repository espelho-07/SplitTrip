enum PersonalDebtType {
  lent, // I lent money to someone -> They owe me
  borrowed; // I borrowed money from someone -> I owe them

  static PersonalDebtType fromString(String? type) {
    if (type == 'borrowed') return PersonalDebtType.borrowed;
    return PersonalDebtType.lent;
  }
}

/// Represents a partial or full repayment toward a personal debt.
class PersonalRepayment {
  final String id;
  final String debtId;
  final String userId;
  final int amountInPaise;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const PersonalRepayment({
    required this.id,
    required this.debtId,
    required this.userId,
    required this.amountInPaise,
    required this.date,
    this.note,
    required this.createdAt,
  });

  factory PersonalRepayment.fromJson(Map<String, dynamic> json) {
    return PersonalRepayment(
      id: json['id'] as String,
      debtId: json['debtId'] as String? ?? json['debt_id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      amountInPaise: (json['amountInPaise'] ?? json['amount_in_paise'] as num).toInt(),
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debtId': debtId,
      'userId': userId,
      'amountInPaise': amountInPaise,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Represents a direct peer-to-peer lending or borrowing record.
class PersonalDebt {
  final String id;
  final String userId;
  final String personName;
  final PersonalDebtType debtType;
  final int initialAmountInPaise;
  final int remainingAmountInPaise;
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  final bool isSettled;
  final bool isDeleted;
  final List<PersonalRepayment> repayments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalDebt({
    required this.id,
    required this.userId,
    required this.personName,
    required this.debtType,
    required this.initialAmountInPaise,
    required this.remainingAmountInPaise,
    this.description,
    required this.date,
    this.dueDate,
    this.isSettled = false,
    this.isDeleted = false,
    this.repayments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  PersonalDebt copyWith({
    String? id,
    String? userId,
    String? personName,
    PersonalDebtType? debtType,
    int? initialAmountInPaise,
    int? remainingAmountInPaise,
    String? description,
    DateTime? date,
    DateTime? dueDate,
    bool? isSettled,
    bool? isDeleted,
    List<PersonalRepayment>? repayments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalDebt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      personName: personName ?? this.personName,
      debtType: debtType ?? this.debtType,
      initialAmountInPaise: initialAmountInPaise ?? this.initialAmountInPaise,
      remainingAmountInPaise: remainingAmountInPaise ?? this.remainingAmountInPaise,
      description: description ?? this.description,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      isSettled: isSettled ?? this.isSettled,
      isDeleted: isDeleted ?? this.isDeleted,
      repayments: repayments ?? this.repayments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PersonalDebt.fromJson(Map<String, dynamic> json) {
    return PersonalDebt(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      personName: json['personName'] as String? ?? json['person_name'] as String? ?? '',
      debtType: PersonalDebtType.fromString(json['debtType'] as String? ?? json['debt_type'] as String?),
      initialAmountInPaise: (json['initialAmountInPaise'] ?? json['initial_amount_in_paise'] as num).toInt(),
      remainingAmountInPaise: (json['remainingAmountInPaise'] ?? json['remaining_amount_in_paise'] as num).toInt(),
      description: json['description'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      isSettled: json['isSettled'] ?? json['is_settled'] as bool? ?? false,
      isDeleted: json['isDeleted'] ?? json['is_deleted'] as bool? ?? false,
      repayments: (json['repayments'] as List<dynamic>?)
              ?.map((r) => PersonalRepayment.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
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
      'personName': personName,
      'debtType': debtType.name,
      'initialAmountInPaise': initialAmountInPaise,
      'remainingAmountInPaise': remainingAmountInPaise,
      'description': description,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isSettled': isSettled,
      'isDeleted': isDeleted,
      'repayments': repayments.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Aggregate summary of all lending and borrowing.
class PersonalDebtsSummary {
  final List<PersonalDebt> debts;
  final int totalLentPaise; // Others owe me
  final int totalBorrowedPaise; // I owe others
  final int netBalancePaise;

  const PersonalDebtsSummary({
    required this.debts,
    required this.totalLentPaise,
    required this.totalBorrowedPaise,
    required this.netBalancePaise,
  });

  factory PersonalDebtsSummary.empty() => const PersonalDebtsSummary(
        debts: [],
        totalLentPaise: 0,
        totalBorrowedPaise: 0,
        netBalancePaise: 0,
      );

  factory PersonalDebtsSummary.fromJson(Map<String, dynamic> json) {
    return PersonalDebtsSummary(
      debts: (json['debts'] as List<dynamic>?)
              ?.map((d) => PersonalDebt.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      totalLentPaise: (json['totalLentPaise'] ?? json['total_lent_paise'] as num? ?? 0).toInt(),
      totalBorrowedPaise: (json['totalBorrowedPaise'] ?? json['total_borrowed_paise'] as num? ?? 0).toInt(),
      netBalancePaise: (json['netBalancePaise'] ?? json['net_balance_paise'] as num? ?? 0).toInt(),
    );
  }
}
