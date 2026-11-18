/// Represents a single member's allocated share of an expense.
/// Stored in integer paise to avoid any rounding/fractional drift.
class ExpenseSplit {
  final String memberId;
  final int amountInPaise;
  final double? percentage;
  final int? shares;

  const ExpenseSplit({
    required this.memberId,
    required this.amountInPaise,
    this.percentage,
    this.shares,
  });

  ExpenseSplit copyWith({
    String? memberId,
    int? amountInPaise,
    double? percentage,
    int? shares,
  }) {
    return ExpenseSplit(
      memberId: memberId ?? this.memberId,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
    );
  }

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'amountInPaise': amountInPaise,
    'percentage': percentage,
    'shares': shares,
  };

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
    memberId: (json['memberId'] ?? json['member_id'] ?? '').toString(),
    amountInPaise: (json['amountInPaise'] as num?)?.toInt() ??
        (json['amount_in_paise'] as num?)?.toInt() ??
        ((json['amount'] as num?)?.toDouble() != null ? ((json['amount'] as num).toDouble() * 100).round() : 0),
    percentage: (json['percentage'] as num?)?.toDouble(),
    shares: json['shares'] as int?,
  );
}
