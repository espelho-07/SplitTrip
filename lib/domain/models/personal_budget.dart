/// Represents a lightweight monthly budget for personal expenses.
class PersonalBudget {
  final String monthYear; // Format: YYYY-MM
  final int monthlyLimitInPaise;
  final int spentInPaise;
  final int remainingInPaise;
  final bool hasBudget;
  final int percentageUsed;

  const PersonalBudget({
    required this.monthYear,
    required this.monthlyLimitInPaise,
    required this.spentInPaise,
    required this.remainingInPaise,
    required this.hasBudget,
    required this.percentageUsed,
  });

  factory PersonalBudget.empty(String monthYear) => PersonalBudget(
        monthYear: monthYear,
        monthlyLimitInPaise: 0,
        spentInPaise: 0,
        remainingInPaise: 0,
        hasBudget: false,
        percentageUsed: 0,
      );

  factory PersonalBudget.fromJson(Map<String, dynamic> json) {
    return PersonalBudget(
      monthYear: json['monthYear'] as String? ?? json['month_year'] as String? ?? '',
      monthlyLimitInPaise: (json['monthlyLimitInPaise'] ?? json['monthly_limit_in_paise'] as num? ?? 0).toInt(),
      spentInPaise: (json['spentInPaise'] ?? json['spent_in_paise'] as num? ?? 0).toInt(),
      remainingInPaise: (json['remainingInPaise'] ?? json['remaining_in_paise'] as num? ?? 0).toInt(),
      hasBudget: json['hasBudget'] as bool? ?? ((json['monthlyLimitInPaise'] ?? 0) > 0),
      percentageUsed: (json['percentageUsed'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monthYear': monthYear,
      'monthlyLimitInPaise': monthlyLimitInPaise,
      'spentInPaise': spentInPaise,
      'remainingInPaise': remainingInPaise,
      'hasBudget': hasBudget,
      'percentageUsed': percentageUsed,
    };
  }
}
