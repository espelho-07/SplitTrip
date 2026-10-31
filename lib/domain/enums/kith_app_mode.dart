/// Defines the primary application mode in KITH's Dual Mode architecture:
/// 1. [trip]: Dedicated group trip management, expenses, splits, and settlements.
/// 2. [financial]: Dedicated personal financial management (Section A) and IPO manager (Section B).
enum KithAppMode {
  trip(
    key: 'trip',
    title: 'Trip Mode',
    shortLabel: 'Trips',
    description: 'Group trips, expense splitting, invite codes & settlements',
  ),
  financial(
    key: 'financial',
    title: 'Financial Mode',
    shortLabel: 'Finance',
    description: 'Personal expenses, ledger, loans & IPO allotments',
  );

  final String key;
  final String title;
  final String shortLabel;
  final String description;

  const KithAppMode({
    required this.key,
    required this.title,
    required this.shortLabel,
    required this.description,
  });

  bool get isTrip => this == KithAppMode.trip;
  bool get isFinancial => this == KithAppMode.financial;

  static KithAppMode fromKey(String? key) {
    if (key == 'financial') {
      return KithAppMode.financial;
    }
    return KithAppMode.trip;
  }
}
