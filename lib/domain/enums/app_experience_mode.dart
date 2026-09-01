enum AppExperienceMode {
  tripsOnly('trips_only', 'Trips Only', 'Focused purely on group trips, splits & settlements'),
  tripsAndExpenses('trips_expenses', 'Trips + Expenses', 'Group trips plus personal expense tracking & lending/borrowing'),
  tripsAndIpo('trips_ipo', 'Trips + IPO Manager', 'Group trips plus dedicated IPO applications, accounts & allotment ledger'),
  all('all', 'All Features', 'Complete Kith experience with trips, personal expenses, and IPO manager');

  final String key;
  final String title;
  final String description;

  const AppExperienceMode(this.key, this.title, this.description);

  bool get includesTrips => true;
  bool get includesExpenses => this == AppExperienceMode.tripsAndExpenses || this == AppExperienceMode.all;
  bool get includesIpo => this == AppExperienceMode.tripsAndIpo || this == AppExperienceMode.all;

  static AppExperienceMode fromKey(String? key) {
    switch (key) {
      case 'trips_only':
        return AppExperienceMode.tripsOnly;
      case 'trips_expenses':
        return AppExperienceMode.tripsAndExpenses;
      case 'trips_ipo':
        return AppExperienceMode.tripsAndIpo;
      case 'all':
      default:
        return AppExperienceMode.all;
    }
  }
}
