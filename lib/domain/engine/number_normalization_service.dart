/// Comprehensive spoken number and currency normalization service for Indian English,
/// Hindi, and Hinglish natural language speech.
///
/// Converts spoken quantities (e.g. "teen sau pachaas", "barah sau", "dedh hazar",
/// "twelve hundred", "five hundred", "2.5k", "₹1,200") into exact integer paise.
class NumberNormalizationService {
  const NumberNormalizationService._();

  // Basic units (1-10) in Hindi & English
  static const Map<String, int> _units = {
    'zero': 0, 'shunya': 0,
    'ek': 1, 'one': 1,
    'do': 2, 'two': 2,
    'teen': 3, 'three': 3,
    'char': 4, 'chaar': 4, 'four': 4,
    'panch': 5, 'paanch': 5, 'five': 5,
    'che': 6, 'chhe': 6, 'six': 6,
    'saat': 7, 'seven': 7,
    'aath': 8, 'eight': 8,
    'nau': 9, 'nine': 9,
    'das': 10, 'ten': 10,
  };

  // Teens (11-19) in Hindi & English
  static const Map<String, int> _teens = {
    'gyarah': 11, 'eleven': 11,
    'barah': 12, 'twelve': 12,
    'terah': 13, 'thirteen': 13,
    'chaudah': 14, 'fourteen': 14,
    'pandrah': 15, 'fifteen': 15,
    'solah': 16, 'sixteen': 16,
    'satrah': 17, 'seventeen': 17,
    'atharah': 18, 'eighteen': 18,
    'unnis': 19, 'nineteen': 19,
  };

  // Tens (20-90) in Hindi & English
  static const Map<String, int> _tens = {
    'bees': 20, 'twenty': 20,
    'tees': 30, 'thirty': 30,
    'chalees': 40, 'chaalees': 40, 'forty': 40,
    'pachas': 50, 'pachaas': 50, 'fifty': 50,
    'saath': 60, 'sixty': 60,
    'sattar': 70, 'seventy': 70,
    'assi': 80, 'eighty': 80,
    'nabbe': 90, 'ninety': 90,
  };

  // Intermediate Hindi numerals (21-99 common)
  static const Map<String, int> _hindiCompounds = {
    'ikkees': 21, 'baees': 22, 'teis': 23, 'chaubees': 24, 'pachees': 25,
    'chhabees': 26, 'sattaees': 27, 'atthaees': 28, 'untees': 29,
    'ikattees': 31, 'battees': 32, 'taintees': 33, 'chauntees': 34, 'paintees': 35,
    'chhattees': 36, 'saintees': 37, 'adhtees': 38, 'untaalees': 39,
    'iktalees': 41, 'bayalees': 42, 'taintalees': 43, 'chauwalees': 44, 'paintalees': 45,
    'chhiyalees': 46, 'saintalees': 47, 'adtalees': 48, 'unchaas': 49,
    'ikkyawan': 51, 'bawan': 52, 'tirepan': 53, 'chouwan': 54, 'pachpan': 55,
    'chhappan': 56, 'sattavan': 57, 'atthaavan': 58, 'unsath': 59,
    'iksath': 61, 'baasath': 62, 'tirsath': 63, 'chaunsath': 64, 'painsath': 65,
    'chhiyaasath': 66, 'sadsath': 67, 'adsath': 68, 'unhattar': 69,
    'ikhattar': 71, 'bahattar': 72, 'tihattar': 73, 'chauhattar': 74, 'pachhattar': 75,
    'chhihattar': 76, 'sathattar': 77, 'athhattar': 78, 'unasi': 79,
    'ikyasi': 81, 'bayasi': 82, 'tiryasi': 83, 'chaurasi': 84, 'pachyasi': 85,
    'chhiyasi': 86, 'sattasi': 87, 'atthasi': 88, 'navasi': 89,
    'ikyanve': 91, 'banve': 92, 'tiranve': 93, 'chauranve': 94, 'pachanve': 95,
    'chhiyanve': 96, 'sattanve': 97, 'anthanve': 98, 'ninyanve': 99,
  };

  /// Extracts the expense amount from natural spoken text in integer paise.
  /// Returns `null` if no valid financial quantity is found.
  static int? extractAmountInPaise(String transcript) {
    final lower = transcript.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // 1. Check for special Indian fraction terms ("dedh hazar" = 1500, "dhai hazar" = 2500, etc.)
    final specialFraction = _matchSpecialFractions(lower);
    if (specialFraction != null) return specialFraction;

    // 2. Check for 'k' notation: "4k", "2.5k", "6.5 K"
    final kMatch = RegExp(r'\b(\d+(?:\.\d+)?)\s*[kK]\b').firstMatch(lower);
    if (kMatch != null) {
      final val = double.tryParse(kMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // 3. Check for "lakh" / "lac" / "crore"
    final lakhMatch = RegExp(r'\b(\d+(?:\.\d+)?)\s*(?:lakh|lac|lakhs|lacs)\b').firstMatch(lower);
    if (lakhMatch != null) {
      final val = double.tryParse(lakhMatch.group(1)!);
      if (val != null) return (val * 100000 * 100).round();
    }
    final croreMatch = RegExp(r'\b(\d+(?:\.\d+)?)\s*(?:crore|cr)\b').firstMatch(lower);
    if (croreMatch != null) {
      final val = double.tryParse(croreMatch.group(1)!);
      if (val != null) return (val * 10000000 * 100).round();
    }

    // 4. Check for "hazar" / "thousand" with digits: "5 hazar", "12 thousand"
    final hazarDigitMatch = RegExp(r'\b(\d+(?:\.\d+)?)\s*(?:hazar|hazaar|thousand)\b').firstMatch(lower);
    if (hazarDigitMatch != null) {
      final val = double.tryParse(hazarDigitMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // 5. Check for "sau" / "hundred" with digits: "5 sau", "12 hundred", "15 sau"
    final sauDigitMatch = RegExp(r'\b(\d+)\s*(?:sau|hundred)\b').firstMatch(lower);
    if (sauDigitMatch != null) {
      final val = int.tryParse(sauDigitMatch.group(1)!);
      if (val != null) {
        // Also check if followed by tens/units e.g. "5 sau 50", "12 hundred 50"
        final remainder = lower.substring(sauDigitMatch.end).trim();
        final tensMatch = RegExp(r'^(?:aur\s+|and\s+)?(\d{1,2})\b').firstMatch(remainder);
        if (tensMatch != null) {
          final tensVal = int.tryParse(tensMatch.group(1)!);
          if (tensVal != null) {
            return ((val * 100) + tensVal) * 100;
          }
        }
        return val * 100 * 100;
      }
    }

    // 6. Check for fully spoken words (e.g. "barah sau", "teen sau pachaas", "paanch sau", "one thousand five hundred")
    final spokenWordAmount = _parseSpokenWords(lower);
    if (spokenWordAmount != null && spokenWordAmount > 0) {
      return spokenWordAmount;
    }

    // 7. Standard numerical digits (e.g. "₹1,200", "500 rs", "1200 rupees", "350 ka toll")
    // Ensure we don't accidentally match participant counts like "chaaron mein", "4 logo mein"
    final digitPattern = RegExp(
      r'(?:₹|rs\.?|inr|\$)?\s*\b(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:rupees|rupee|rupaye|rupya|inr|rs|bucks)?\b',
      caseSensitive: false,
    );

    final allDigitMatches = digitPattern.allMatches(lower);
    for (final match in allDigitMatches) {
      final rawNum = match.group(1);
      if (rawNum != null) {
        // Check surrounding context: Is this a participant specifier e.g. "4 logon mein" or "4 members"?
        final afterMatch = lower.substring(match.end, (match.end + 15).clamp(0, lower.length));
        if (RegExp(r'^\s*(?:logon|logo|people|members|mein|me|among|divided)\b').hasMatch(afterMatch)) {
          // This is a participant count, not the expense amount
          continue;
        }

        final cleaned = rawNum.replaceAll(',', '');
        final val = double.tryParse(cleaned);
        if (val != null && val > 0) {
          return (val * 100).round();
        }
      }
    }

    return null;
  }

  /// Handles special Indian fractional terms.
  static int? _matchSpecialFractions(String text) {
    // Dedh hazar = 1,500
    if (RegExp(r'\b(?:dedh|dhed)\s+(?:hazar|hazaar|thousand)\b').hasMatch(text)) {
      return 1500 * 100;
    }
    // Dhai hazar = 2,500
    if (RegExp(r'\b(?:dhai|dhaai)\s+(?:hazar|hazaar|thousand)\b').hasMatch(text)) {
      return 2500 * 100;
    }
    // Saade teen hazar = 3,500
    if (RegExp(r'\b(?:sade|saade)\s+(?:teen|three)\s+(?:hazar|hazaar|thousand)\b').hasMatch(text)) {
      return 3500 * 100;
    }
    // Saade char hazar = 4,500
    if (RegExp(r'\b(?:sade|saade)\s+(?:char|chaar|four)\s+(?:hazar|hazaar|thousand)\b').hasMatch(text)) {
      return 4500 * 100;
    }
    // Saade panch hazar = 5,500
    if (RegExp(r'\b(?:sade|saade)\s+(?:panch|paanch|five)\s+(?:hazar|hazaar|thousand)\b').hasMatch(text)) {
      return 5500 * 100;
    }

    // Dedh sau = 150
    if (RegExp(r'\b(?:dedh|dhed)\s+(?:sau|hundred)\b').hasMatch(text)) {
      return 150 * 100;
    }
    // Dhai sau = 250
    if (RegExp(r'\b(?:dhai|dhaai)\s+(?:sau|hundred)\b').hasMatch(text)) {
      return 250 * 100;
    }
    // Saade teen sau = 350
    if (RegExp(r'\b(?:sade|saade)\s+(?:teen|three)\s+(?:sau|hundred)\b').hasMatch(text)) {
      return 350 * 100;
    }
    // Saade char sau = 450
    if (RegExp(r'\b(?:sade|saade)\s+(?:char|chaar|four)\s+(?:sau|hundred)\b').hasMatch(text)) {
      return 450 * 100;
    }

    return null;
  }

  /// Parses spoken Hindi and English numeric phrases into integer paise.
  static int? _parseSpokenWords(String text) {
    // 1. Check for spoken thousand phrases: e.g. "do hazar paanch sau", "one thousand five hundred", "ek hazar"
    final thousandMatch = RegExp(
      r'\b([a-zA-Z]+)\s+(?:hazar|hazaar|thousand)\b(?:\s+(?:aur\s+|and\s+)?([a-zA-Z\s]+))?',
    ).firstMatch(text);

    if (thousandMatch != null) {
      final leadingWord = thousandMatch.group(1)?.toLowerCase();
      final thousandsMultiplier = _wordToNumber(leadingWord);

      if (thousandsMultiplier != null) {
        int total = thousandsMultiplier * 1000;
        final remainder = thousandMatch.group(2)?.trim().toLowerCase();

        if (remainder != null && remainder.isNotEmpty) {
          // Check if remainder has hundreds/tens e.g. "paanch sau", "five hundred", "five hundred fifty"
          final subSau = _parseSauPhrase(remainder);
          if (subSau != null) {
            total += subSau;
          } else {
            final subTens = _wordToNumber(remainder.split(RegExp(r'\s+')).first);
            if (subTens != null) total += subTens;
          }
        }
        return total * 100;
      }
    }

    // 2. Check for spoken hundred phrases: e.g. "barah sau", "paanch sau", "teen sau pachaas", "twelve hundred"
    final sauAmount = _parseSauPhrase(text);
    if (sauAmount != null && sauAmount > 0) {
      return sauAmount * 100;
    }

    // 3. Check for standalone single words (e.g. "pachaas", "fifty", "sau", "hundred")
    final standaloneWords = text.split(RegExp(r'\s+'));
    for (int i = 0; i < standaloneWords.length; i++) {
      final w = standaloneWords[i].replaceAll(RegExp(r'[^\w]'), '');
      if (w == 'sau' || w == 'hundred') {
        return 100 * 100;
      }
      final numVal = _wordToNumber(w);
      if (numVal != null && numVal >= 20) {
        // If followed by unit e.g. "chalees panch" = 45 or "fifty five" = 55
        if (i + 1 < standaloneWords.length) {
          final nextW = standaloneWords[i + 1].replaceAll(RegExp(r'[^\w]'), '');
          final unitVal = _units[nextW];
          if (unitVal != null) {
            return (numVal + unitVal) * 100;
          }
        }
        return numVal * 100;
      }
    }

    return null;
  }

  /// Parses expressions containing "sau" or "hundred"
  /// e.g. "teen sau pachaas", "paanch sau", "barah sau", "twelve hundred", "fifteen hundred fifty"
  static int? _parseSauPhrase(String text) {
    final sauMatch = RegExp(
      r'\b([a-zA-Z]+)\s+(?:sau|hundred)\b(?:\s+(?:aur\s+|and\s+)?([a-zA-Z\s]+))?',
    ).firstMatch(text);

    if (sauMatch != null) {
      final multiplierWord = sauMatch.group(1)?.toLowerCase();
      final multiplier = _wordToNumber(multiplierWord);

      if (multiplier != null) {
        int total = multiplier * 100;
        final remainder = sauMatch.group(2)?.trim().toLowerCase();

        if (remainder != null && remainder.isNotEmpty) {
          final tokens = remainder.split(RegExp(r'\s+'));
          final firstToken = tokens.first;
          final tensVal = _wordToNumber(firstToken);

          if (tensVal != null) {
            total += tensVal;
            // Check if there's a subsequent unit token e.g. "fifty five"
            if (tokens.length > 1) {
              final secondToken = tokens[1];
              final unitVal = _units[secondToken];
              if (unitVal != null) {
                total += unitVal;
              }
            }
          }
        }
        return total;
      }
    } else if (RegExp(r'\b(?:sau|hundred)\b').hasMatch(text)) {
      // Just "sau" or "hundred" optionally followed by tens/units
      final postSau = text.split(RegExp(r'\b(?:sau|hundred)\b')).last.trim();
      int total = 100;
      if (postSau.isNotEmpty) {
        final firstW = postSau.split(RegExp(r'\s+')).first;
        final tensVal = _wordToNumber(firstW);
        if (tensVal != null) total += tensVal;
      }
      return total;
    }

    return null;
  }

  /// Converts an individual word into its numeric integer value.
  static int? _wordToNumber(String? word) {
    if (word == null) return null;
    final w = word.toLowerCase().trim();

    if (_units.containsKey(w)) return _units[w];
    if (_teens.containsKey(w)) return _teens[w];
    if (_tens.containsKey(w)) return _tens[w];
    if (_hindiCompounds.containsKey(w)) return _hindiCompounds[w];

    // Check special hundred multiples e.g. "pachees" = 25 -> 25 * 100 handled in sau
    return null;
  }
}
