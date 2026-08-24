/// Expense splitting methods supported by the deterministic money engine.
enum SplitType {
  equal,
  exact,
  percentage,
  shares;

  String get displayName {
    switch (this) {
      case SplitType.equal:
        return 'Equally';
      case SplitType.exact:
        return 'Exact Amount';
      case SplitType.percentage:
        return 'By Percentage';
      case SplitType.shares:
        return 'By Shares';
    }
  }

  static SplitType fromString(String value) {
    return SplitType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SplitType.equal,
    );
  }
}
