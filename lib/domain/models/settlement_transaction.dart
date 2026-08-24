/// A simplified direct settlement between two members.
class SettlementTransaction {
  final String fromMemberId;
  final String toMemberId;
  final int amountInPaise;
  final bool isSettled;
  final DateTime? settledAt;
  final String? paymentReference;

  const SettlementTransaction({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountInPaise,
    this.isSettled = false,
    this.settledAt,
    this.paymentReference,
  });

  SettlementTransaction copyWith({
    String? fromMemberId,
    String? toMemberId,
    int? amountInPaise,
    bool? isSettled,
    DateTime? settledAt,
    String? paymentReference,
  }) {
    return SettlementTransaction(
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }

  Map<String, dynamic> toJson() => {
    'fromMemberId': fromMemberId,
    'toMemberId': toMemberId,
    'amountInPaise': amountInPaise,
    'isSettled': isSettled,
    'settledAt': settledAt?.toIso8601String(),
    'paymentReference': paymentReference,
  };

  factory SettlementTransaction.fromJson(Map<String, dynamic> json) => SettlementTransaction(
    fromMemberId: json['fromMemberId'] as String,
    toMemberId: json['toMemberId'] as String,
    amountInPaise: json['amountInPaise'] as int,
    isSettled: json['isSettled'] as bool? ?? false,
    settledAt: json['settledAt'] != null
        ? DateTime.parse(json['settledAt'] as String)
        : null,
    paymentReference: json['paymentReference'] as String?,
  );
}
