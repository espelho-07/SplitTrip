/// Represents supported currency configurations with strict integer smallest-unit representation.
class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final String flagEmoji;
  final int decimalDigits;
  final String subunitName;
  final String locale;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flagEmoji,
    this.decimalDigits = 2,
    required this.subunitName,
    required this.locale,
  });

  static const AppCurrency inr = AppCurrency(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    flagEmoji: '🇮🇳',
    decimalDigits: 2,
    subunitName: 'Paise',
    locale: 'en_IN',
  );

  static const AppCurrency usd = AppCurrency(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    flagEmoji: '🇺🇸',
    decimalDigits: 2,
    subunitName: 'Cents',
    locale: 'en_US',
  );

  static const AppCurrency eur = AppCurrency(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    flagEmoji: '🇪🇺',
    decimalDigits: 2,
    subunitName: 'Cents',
    locale: 'de_DE',
  );

  static const AppCurrency gbp = AppCurrency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    flagEmoji: '🇬🇧',
    decimalDigits: 2,
    subunitName: 'Pence',
    locale: 'en_GB',
  );

  static const List<AppCurrency> supportedCurrencies = [inr, usd, eur, gbp];

  static AppCurrency fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.trim().toUpperCase(),
      orElse: () => inr,
    );
  }
}
