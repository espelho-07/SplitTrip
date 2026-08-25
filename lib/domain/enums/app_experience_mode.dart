enum AppExperienceMode {
  all('all', 'Trips & Expenses', 'Full experience with personal finance and group trips'),
  tripsOnly('trips_only', 'Trips Only', 'Focused purely on group trips, splits & settlements');

  final String key;
  final String title;
  final String description;

  const AppExperienceMode(this.key, this.title, this.description);

  static AppExperienceMode fromKey(String? key) {
    if (key == 'trips_only') return AppExperienceMode.tripsOnly;
    return AppExperienceMode.all;
  }
}
