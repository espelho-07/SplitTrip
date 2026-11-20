/// Production-grade temporal expression extractor for voice expenses.
/// Extracts relative dates (e.g. "aaj", "today", "kal", "yesterday", "parso",
/// "last night", day names) into valid [DateTime] objects without external dependencies.
class ExpenseDateExtractor {
  const ExpenseDateExtractor._();

  /// Extracts the intended expense date from speech.
  /// Defaults to `DateTime.now()` if no explicit past indicator is present.
  static DateTime? extractDate(String text, {DateTime? referenceDate}) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;
    final now = referenceDate ?? DateTime.now();

    // 1. Check for "Day before yesterday" / "parso"
    if (RegExp(r'\b(?:parso|parson|day\s+before\s+yesterday)\b').hasMatch(lower)) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
    }

    // 2. Check for "Yesterday" / "kal" / "last night" / "kal raat"
    // Note: In Hindi, "kal" can mean yesterday or tomorrow. For expense splitting,
    // past tense indicators ("diye the", "kharch hue", "bhara tha", "paid") or absence
    // of future markers reliably indicates yesterday.
    if (RegExp(r'\b(?:yesterday|kal\s+raat|last\s+night|beeta\s+hua\s+kal)\b').hasMatch(lower) ||
        (RegExp(r'\bkal\b').hasMatch(lower) && !RegExp(r'\b(?:aane\s+wala|kal\s+denge|kal\s+karenge)\b').hasMatch(lower))) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    }

    // 3. Check for "Today" / "aaj" / "tonight" / "aaj raat"
    if (RegExp(r'\b(?:today|aaj|tonight|aaj\s+raat)\b').hasMatch(lower)) {
      return DateTime(now.year, now.month, now.day);
    }

    // 4. Weekday mentions (e.g. "monday ko", "somwar ko", "on sunday")
    final weekday = _matchWeekday(lower);
    if (weekday != null) {
      // Find closest preceding occurrence of that weekday
      int daysAgo = (now.weekday - weekday) % 7;
      if (daysAgo <= 0) daysAgo += 7;
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
    }

    return null;
  }

  static int? _matchWeekday(String lower) {
    if (RegExp(r'\b(?:monday|somwar|somvaar)\b').hasMatch(lower)) return DateTime.monday;
    if (RegExp(r'\b(?:tuesday|mangalwar|mangalvaar)\b').hasMatch(lower)) return DateTime.tuesday;
    if (RegExp(r'\b(?:wednesday|budhwar|budhvaar)\b').hasMatch(lower)) return DateTime.wednesday;
    if (RegExp(r'\b(?:thursday|guruwar|guruvaar|veervar)\b').hasMatch(lower)) return DateTime.thursday;
    if (RegExp(r'\b(?:friday|shukrawar|shukravaar)\b').hasMatch(lower)) return DateTime.friday;
    if (RegExp(r'\b(?:saturday|shaniwar|shanivaar)\b').hasMatch(lower)) return DateTime.saturday;
    if (RegExp(r'\b(?:sunday|ravivar|ravivaar|itwar|itvaar)\b').hasMatch(lower)) return DateTime.sunday;
    return null;
  }

  /// Removes temporal words from transcript so they don't pollute the expense title.
  static String cleanTemporalKeywords(String text) {
    return text.replaceAll(
      RegExp(
        r'\b(?:today|aaj|yesterday|kal|parso|parson|tonight|aaj\s+raat|last\s+night|'
        r'somwar|mangalwar|budhwar|guruwar|shukrawar|shaniwar|ravivar|itwar|'
        r'monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ),
      ' ',
    );
  }
}
