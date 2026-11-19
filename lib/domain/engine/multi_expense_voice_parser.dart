import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import '../models/expense_draft.dart';
import '../models/trip_member.dart';

/// Production-grade Multi-Expense Voice Parser.
/// Extracts single or multiple discrete expense drafts from compound English, Hindi,
/// and Hinglish spoken voice transcripts with zero paid API overhead and 100% integer paise precision.
class MultiExpenseVoiceParser {
  const MultiExpenseVoiceParser._();

  /// Stop words stripped from clauses when extracting clean expense titles.
  static const Set<String> _stopWords = {
    // Hindi / Hinglish pronouns & verbs
    'maine', 'mera', 'meri', 'mere', 'humne', 'hamaare', 'apna', 'apni',
    'ne', 'diye', 'diya', 'dii', 'de', 'dediye', 'kharch', 'kharcha',
    'kiye', 'kiya', 'hue', 'hua', 'hui', 'kare', 'karo',
    'pe', 'par', 'ke', 'ka', 'ki', 'ko', 'se', 'mein',
    'liye', 'bheje', 'bheja', 'dala', 'dale', 'bhare', 'bhara',
    'tha', 'thi', 'hai', 'hain', 'ho', 'gaye', 'gaya',
    // English pronouns & verbs
    'i', 'we', 'me', 'my', 'mine', 'our', 'us',
    'paid', 'spent', 'pay', 'spend', 'gave', 'given', 'bought', 'cost',
    'for', 'on', 'at', 'in', 'to', 'from', 'with',
    'the', 'a', 'an', 'some',
    'yesterday', 'today', 'tonight', 'recently',
    // Currency markers (handled by amount extractor)
    'rupee', 'rupees', 'rupaye', 'rupya', 'rs', 'inr', 'bucks', 'dollars',
    // Conjunctions / group tokens
    'and', 'aur', 'plus', 'also', 'then', 'phir', 'baad',
    'sabke', 'everyone', 'all', 'together', 'total',
  };

  /// Main entry point: Parses [transcript] into a list of [ExpenseDraft]s.
  /// If [members] and [currentUserId] are provided, resolves payers and participants.
  static List<ExpenseDraft> parse(
    String transcript, {
    List<TripMember> members = const [],
    String? currentUserId,
  }) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];

    // 1. Detect global context (e.g. did user say "Maine..." or "Rahul ne..." at root?)
    final globalPayerInfo = _detectGlobalPayer(trimmed, members, currentUserId);

    // 2. Segment transcript into discrete clauses
    final rawClauses = _segmentTranscript(trimmed);
    if (rawClauses.isEmpty) return const [];

    // 3. Parse each clause into an ExpenseDraft
    final drafts = <ExpenseDraft>[];

    for (final clause in rawClauses) {
      final draft = _parseClause(
        clause: clause,
        globalPayerInfo: globalPayerInfo,
        members: members,
        currentUserId: currentUserId,
      );
      if (draft != null) {
        drafts.add(draft);
      }
    }

    // If segmentation produced nothing valid, attempt single-clause fallback
    if (drafts.isEmpty) {
      final fallbackDraft = _parseClause(
        clause: trimmed,
        globalPayerInfo: globalPayerInfo,
        members: members,
        currentUserId: currentUserId,
      );
      if (fallbackDraft != null) {
        drafts.add(fallbackDraft);
      }
    }

    return drafts;
  }

  /// Segments a transcript into separate clauses representing individual expenses.
  static List<String> _segmentTranscript(String transcript) {
    // Step A: First split on explicit delimiters and compound conjunctions:
    // Punctuation: , ; \n +
    // Conjunction phrases: "aur", "and", "plus", "then", "phir", "uske baad", "after that"
    final delimiterPattern = RegExp(
      r'(?:[\r\n;,+]+|\s+(?:aur|and|plus|then|phir|uske\s+baad|after\s+that)\s+)',
      caseSensitive: false,
    );

    final initialSegments = transcript
        .split(delimiterPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Step B: For each segment, check if it contains multiple amount patterns without delimiters
    // e.g. "4k train 5k club 800 food" or "train 4000 hotel 5000 food 800"
    final finalClauses = <String>[];

    for (final seg in initialSegments) {
      final subSegments = _splitMultiAmountSegment(seg);
      finalClauses.addAll(subSegments);
    }

    return finalClauses.isNotEmpty ? finalClauses : [transcript];
  }

  /// Splits an unpunctuated segment if it contains multiple amounts.
  static List<String> _splitMultiAmountSegment(String text) {
    // Match amounts like 4k, 2.5k, 4000, 10 thousand, 1 lakh, etc.
    final amountPattern = RegExp(
      r'(?:₹|rs\.?|inr|\$)?\s*\b\d+(?:,\d+)*(?:\.\d+)?\s*(?:k|thousand|hazar|hazaar|lakh|lac|lakhs|lacs|rupees|rupee|rs)?\b',
      caseSensitive: false,
    );

    final matches = amountPattern.allMatches(text).toList();
    if (matches.length <= 1) {
      return [text];
    }

    // If multiple amounts are detected, we determine boundary splits.
    // We check whether the descriptor precedes or follows the amount:
    // Case 1 (Amount-first): "4k train 5k club 800 food"
    // Case 2 (Descriptor-first): "train 4000 hotel 5000 food 800"
    final tokens = text.split(RegExp(r'\s+'));
    final amountIndices = <int>[];

    for (int i = 0; i < tokens.length; i++) {
      if (_hasAmount(tokens[i])) {
        amountIndices.add(i);
      }
    }

    if (amountIndices.length > 1) {
      final chunks = <String>[];
      int startIdx = 0;

      for (int i = 0; i < amountIndices.length; i++) {
        final currentAmountIdx = amountIndices[i];
        final nextAmountIdx = (i + 1 < amountIndices.length) ? amountIndices[i + 1] : tokens.length;

        if (i == 0) {
          // If first token is amount or preceded by a few words, determine next slice
          if (nextAmountIdx < tokens.length) {
            // Check if descriptor comes between currentAmount and nextAmount
            // E.g. "train 4000 hotel 5000": nextAmount is 5000 (idx 3), token before is hotel (idx 2)
            // If token before nextAmount is NOT a number, does currentAmount have a descriptor before it?
            if (currentAmountIdx > startIdx) {
              // Descriptor-first: "train 4000"
              final chunk = tokens.sublist(startIdx, currentAmountIdx + 1).join(' ');
              if (chunk.trim().isNotEmpty) chunks.add(chunk);
              startIdx = currentAmountIdx + 1;
            } else {
              // Amount-first: "4k train" -> slice up to nextAmountIdx
              final chunk = tokens.sublist(startIdx, nextAmountIdx).join(' ');
              if (chunk.trim().isNotEmpty) chunks.add(chunk);
              startIdx = nextAmountIdx;
            }
          } else {
            final chunk = tokens.sublist(startIdx).join(' ');
            if (chunk.trim().isNotEmpty) chunks.add(chunk);
          }
        } else {
          // Subsequent amounts
          if (nextAmountIdx <= tokens.length && nextAmountIdx > startIdx) {
            if (currentAmountIdx > startIdx && i == amountIndices.length - 1) {
              final chunk = tokens.sublist(startIdx).join(' ');
              if (chunk.trim().isNotEmpty) chunks.add(chunk);
            } else if (currentAmountIdx > startIdx) {
              final chunk = tokens.sublist(startIdx, currentAmountIdx + 1).join(' ');
              if (chunk.trim().isNotEmpty) chunks.add(chunk);
              startIdx = currentAmountIdx + 1;
            } else {
              final chunk = tokens.sublist(startIdx, nextAmountIdx).join(' ');
              if (chunk.trim().isNotEmpty) chunks.add(chunk);
              startIdx = nextAmountIdx;
            }
          }
        }
      }

      if (chunks.length > 1) {
        return chunks;
      }
    }

    return [text];
  }

  static bool _hasAmount(String token) {
    return RegExp(r'\d', caseSensitive: false).hasMatch(token);
  }

  /// Parses a single clause into an [ExpenseDraft].
  static ExpenseDraft? _parseClause({
    required String clause,
    required _PayerInfo globalPayerInfo,
    required List<TripMember> members,
    required String? currentUserId,
  }) {
    final lower = clause.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final unresolved = <String>[];

    // 1. Extract Amount in integer Paise
    final amountInPaise = _extractAmountInPaise(lower);
    if (amountInPaise == null || amountInPaise <= 0) {
      unresolved.add('amount');
    }

    // 2. Extract Category
    final category = _extractCategory(lower);

    // 3. Extract Clean Title
    final title = _extractTitle(clause, lower, category);

    // 4. Resolve Payer
    final payer = _resolvePayer(
      clauseLower: lower,
      globalPayerInfo: globalPayerInfo,
      members: members,
      currentUserId: currentUserId,
    );

    if (payer.isAmbiguous) {
      unresolved.add('payer_ambiguity');
    }

    // 5. Resolve Participants
    final participants = _resolveParticipants(
      clauseLower: lower,
      members: members,
      currentUserId: currentUserId,
      payerMemberId: payer.memberId,
    );

    final double confidence = (amountInPaise != null && amountInPaise > 0 && title.isNotEmpty)
        ? (unresolved.isEmpty ? 0.95 : 0.70)
        : 0.40;

    return ExpenseDraft(
      amountInPaise: amountInPaise ?? 0,
      title: title,
      category: category,
      payerMemberId: payer.memberId,
      payerName: payer.displayName,
      participantMemberIds: participants,
      splitType: SplitType.equal,
      confidence: confidence,
      rawInput: clause,
      source: ExpenseDraftSource.voice,
      unresolvedFields: unresolved,
      candidatePayers: payer.candidatePayers,
      ambiguityMessage: payer.isAmbiguous
          ? 'Multiple members found with this name.'
          : (amountInPaise == null || amountInPaise <= 0 ? 'Amount could not be detected.' : null),
    );
  }

  /// Extracts amount in integer Paise from text with full Indian notation support.
  static int? _extractAmountInPaise(String text) {
    // 1. Check for 'k' notation: "4k", "2.5k", "6.5 K"
    final kMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[kK]\b').firstMatch(text);
    if (kMatch != null) {
      final val = double.tryParse(kMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // 2. Check for "lakh" / "lac" / "lakhs" / "lacs"
    final lakhMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lakh|lac|lakhs|lacs)\b').firstMatch(text);
    if (lakhMatch != null) {
      final val = double.tryParse(lakhMatch.group(1)!);
      if (val != null) return (val * 100000 * 100).round();
    }

    // 3. Check for "hazar" / "hazaar" / "thousand"
    final hazarMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hazar|hazaar|thousand)\b').firstMatch(text);
    if (hazarMatch != null) {
      final val = double.tryParse(hazarMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // 4. Hindi word numbers (e.g. "ek hazar", "do hazar", "chhe hazar", "das hazar")
    final wordMap = {
      'ek': 1, 'one': 1,
      'do': 2, 'two': 2,
      'teen': 3, 'three': 3,
      'char': 4, 'four': 4,
      'panch': 5, 'five': 5,
      'chhe': 6, 'che': 6, 'six': 6,
      'saat': 7, 'seven': 7,
      'aath': 8, 'eight': 8,
      'nau': 9, 'nine': 9,
      'das': 10, 'ten': 10,
    };

    for (final entry in wordMap.entries) {
      if (text.contains('${entry.key} lakh') || text.contains('${entry.key} lac')) {
        return entry.value * 100000 * 100;
      }
      if (text.contains('${entry.key} hazar') ||
          text.contains('${entry.key} hazaar') ||
          text.contains('${entry.key} thousand')) {
        return entry.value * 1000 * 100;
      }
    }

    // 5. Standard digits (e.g. "4000", "850.50", "₹1,200", "500 rs", "1000 rupees")
    final digitMatch = RegExp(
      r'(?:₹|rs\.?|inr|\$)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:rupees|rupee|inr|rs)?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (digitMatch != null && digitMatch.group(1) != null) {
      final cleaned = digitMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(cleaned);
      if (val != null) return (val * 100).round();
    }

    return null;
  }

  /// Extracts clean expense title, stripping amounts, punctuation, and filler words.
  static String _extractTitle(String clause, String lower, ExpenseCategory category) {
    // 1. Remove amount expressions from text
    String cleaned = lower
        .replaceAll(RegExp(r'(\d+(?:\.\d+)?)\s*[kK]\b'), '')
        .replaceAll(RegExp(r'(\d+(?:\.\d+)?)\s*(?:lakh|lac|lakhs|lacs)\b'), '')
        .replaceAll(RegExp(r'(\d+(?:\.\d+)?)\s*(?:hazar|hazaar|thousand)\b'), '')
        .replaceAll(RegExp(r'(?:₹|rs\.?|inr|\$)?\s*\d+(?:,\d+)*(?:\.\d{1,2})?\s*(?:rupees|rupee|inr|rs)?\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ');

    // 2. Tokenize and filter stop words
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();

    if (tokens.isNotEmpty) {
      // Capitalize each token
      final title = tokens
          .map((t) => t.length > 1 ? (t[0].toUpperCase() + t.substring(1)) : t.toUpperCase())
          .join(' ');
      return title;
    }

    // 3. Fallback to smart title based on category keywords
    if (lower.contains('train')) return 'Train';
    if (lower.contains('flight')) return 'Flight';
    if (lower.contains('cab') || lower.contains('taxi') || lower.contains('uber') || lower.contains('ola')) return 'Cab';
    if (lower.contains('auto') || lower.contains('rickshaw')) return 'Auto';
    if (lower.contains('dinner')) return 'Dinner';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('breakfast') || lower.contains('nasta') || lower.contains('nashta')) return 'Breakfast';
    if (lower.contains('hotel') || lower.contains('stay') || lower.contains('resort')) return 'Hotel';
    if (lower.contains('club') || lower.contains('bar') || lower.contains('drinks')) return 'Club & Drinks';
    if (lower.contains('food') || lower.contains('khana')) return 'Food';
    if (lower.contains('snack') || lower.contains('snacks')) return 'Snacks';
    if (lower.contains('coffee') || lower.contains('chai') || lower.contains('tea')) return 'Coffee & Tea';
    if (lower.contains('grocery') || lower.contains('groceries')) return 'Groceries';
    if (lower.contains('movie') || lower.contains('cinema')) return 'Movie';
    if (lower.contains('shopping')) return 'Shopping';

    return '${category.displayName} Expense';
  }

  /// Predicts ExpenseCategory from text content.
  static ExpenseCategory _extractCategory(String text) {
    if (text.contains('train') || text.contains('flight') || text.contains('cab') ||
        text.contains('taxi') || text.contains('uber') || text.contains('ola') ||
        text.contains('petrol') || text.contains('fuel') || text.contains('diesel') ||
        text.contains('auto') || text.contains('rickshaw') || text.contains('bus') ||
        text.contains('metro') || text.contains('toll') || text.contains('parking')) {
      return ExpenseCategory.transport;
    }
    if (text.contains('dinner') || text.contains('lunch') || text.contains('food') ||
        text.contains('khana') || text.contains('restaurant') || text.contains('pizza') ||
        text.contains('burger') || text.contains('nasta') || text.contains('nashta') ||
        text.contains('breakfast') || text.contains('swiggy') || text.contains('zomato') ||
        text.contains('biryani') || text.contains('meal') || text.contains('snack') ||
        text.contains('snacks')) {
      return ExpenseCategory.food;
    }
    if (text.contains('hotel') || text.contains('stay') || text.contains('resort') ||
        text.contains('room') || text.contains('airbnb') || text.contains('villa') ||
        text.contains('hostel') || text.contains('lodge') || text.contains('homestay') ||
        text.contains('pg')) {
      return ExpenseCategory.stay;
    }
    if (text.contains('chai') || text.contains('coffee') || text.contains('tea') ||
        text.contains('beer') || text.contains('drinks') || text.contains('bar') ||
        text.contains('pub') || text.contains('club') || text.contains('cafe') ||
        text.contains('liquor') || text.contains('wine') || text.contains('cocktail') ||
        text.contains('alcohol')) {
      return ExpenseCategory.drinks;
    }
    if (text.contains('scuba') || text.contains('trek') || text.contains('trekking') ||
        text.contains('ticket') || text.contains('tickets') || text.contains('movie') ||
        text.contains('cinema') || text.contains('surf') || text.contains('activity') ||
        text.contains('sightseeing') || text.contains('museum') || text.contains('safari') ||
        text.contains('rafting') || text.contains('amusement')) {
      return ExpenseCategory.activities;
    }
    if (text.contains('shopping') || text.contains('clothes') || text.contains('mall') ||
        text.contains('shoes') || text.contains('souvenir') || text.contains('gifts')) {
      return ExpenseCategory.shopping;
    }
    if (text.contains('grocery') || text.contains('groceries') || text.contains('ration') ||
        text.contains('supermarket') || text.contains('zepto') || text.contains('blinkit') ||
        text.contains('instamart') || text.contains('vegetables') || text.contains('fruits')) {
      return ExpenseCategory.groceries;
    }
    return ExpenseCategory.general;
  }

  /// Detects global payer intent from full transcript (e.g. "Maine...", "I paid...", "Rahul ne...").
  static _PayerInfo _detectGlobalPayer(
    String transcript,
    List<TripMember> members,
    String? currentUserId,
  ) {
    final lower = transcript.toLowerCase();
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ?? members.firstOrNull;

    if (lower.startsWith('maine') ||
        lower.startsWith('i paid') ||
        lower.startsWith('i spent') ||
        lower.startsWith('humne') ||
        lower.contains('maine') ||
        lower.contains('i paid')) {
      return _PayerInfo(
        memberId: selfMember?.id,
        displayName: selfMember?.displayName ?? 'You',
        isSelf: true,
      );
    }

    // Check if an explicit name is specified e.g. "Rahul ne 4k diye"
    final payerMatch = RegExp(r'\b([a-zA-Z]+)\s+(?:ne|paid|diye|gave|spent)\b', caseSensitive: false).firstMatch(transcript);
    if (payerMatch != null && payerMatch.group(1) != null) {
      final candidateName = payerMatch.group(1)!.trim();
      final candLower = candidateName.toLowerCase();
      if (candLower != 'i' && candLower != 'maine' && candLower != 'humne' && candLower != 'we') {
        final matches = members.where((m) =>
            m.displayName.toLowerCase() == candLower ||
            m.displayName.toLowerCase().startsWith('$candLower ') ||
            m.displayName.toLowerCase().contains(candLower)).toList();

        if (matches.length == 1) {
          return _PayerInfo(
            memberId: matches.first.id,
            displayName: matches.first.displayName,
            isSelf: matches.first.userId == currentUserId,
          );
        } else if (matches.length > 1) {
          return _PayerInfo(
            memberId: null,
            displayName: candidateName,
            isSelf: false,
            isAmbiguous: true,
            candidatePayers: matches,
          );
        }
      }
    }

    return _PayerInfo(
      memberId: selfMember?.id,
      displayName: selfMember?.displayName ?? 'You',
      isSelf: true,
    );
  }

  /// Resolves the payer for a specific clause.
  static _PayerInfo _resolvePayer({
    required String clauseLower,
    required _PayerInfo globalPayerInfo,
    required List<TripMember> members,
    required String? currentUserId,
  }) {
    // Check if this clause explicitly specifies a payer (e.g. "Rahul ne...")
    final payerMatch = RegExp(r'\b([a-zA-Z]+)\s+(?:ne|paid|diye|gave|spent)\b', caseSensitive: false).firstMatch(clauseLower);
    if (payerMatch != null && payerMatch.group(1) != null) {
      final cand = payerMatch.group(1)!.trim().toLowerCase();
      if (cand == 'i' || cand == 'maine' || cand == 'humne' || cand == 'we') {
        final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ?? members.firstOrNull;
        return _PayerInfo(
          memberId: selfMember?.id,
          displayName: selfMember?.displayName ?? 'You',
          isSelf: true,
        );
      }

      final matches = members.where((m) =>
          m.displayName.toLowerCase() == cand ||
          m.displayName.toLowerCase().startsWith('$cand ') ||
          m.displayName.toLowerCase().contains(cand)).toList();

      if (matches.length == 1) {
        return _PayerInfo(
          memberId: matches.first.id,
          displayName: matches.first.displayName,
          isSelf: matches.first.userId == currentUserId,
        );
      } else if (matches.length > 1) {
        return _PayerInfo(
          memberId: null,
          displayName: cand,
          isSelf: false,
          isAmbiguous: true,
          candidatePayers: matches,
        );
      }
    }

    // Default to global payer info
    return globalPayerInfo;
  }

  /// Resolves participant member IDs for a clause.
  static List<String> _resolveParticipants({
    required String clauseLower,
    required List<TripMember> members,
    required String? currentUserId,
    required String? payerMemberId,
  }) {
    if (members.isEmpty) return const [];

    // Check if explicitly scoped to certain participants
    if (clauseLower.contains('for me and ') ||
        clauseLower.contains('mere aur ') ||
        clauseLower.contains('between ')) {
      final partMatch = RegExp(r'(?:for me and|mere aur|between)\s+([a-zA-Z\s,]+)', caseSensitive: false).firstMatch(clauseLower);
      if (partMatch != null && partMatch.group(1) != null) {
        final selectedIds = <String>{};
        if (payerMemberId != null) selectedIds.add(payerMemberId);

        final names = partMatch.group(1)!.split(RegExp(r'[,&]|\band\b|\baur\b'));
        for (final n in names) {
          final trimmed = n.trim().toLowerCase();
          if (trimmed.isEmpty || trimmed == 'everyone' || trimmed == 'all') continue;
          final match = members.where((m) =>
              m.displayName.toLowerCase() == trimmed ||
              m.displayName.toLowerCase().startsWith('$trimmed ') ||
              m.displayName.toLowerCase().contains(trimmed)).firstOrNull;
          if (match != null) {
            selectedIds.add(match.id);
          }
        }

        if (selectedIds.isNotEmpty) {
          return selectedIds.toList();
        }
      }
    }

    // Default: all trip members participate equally
    return members.map((m) => m.id).toList();
  }
}

class _PayerInfo {
  final String? memberId;
  final String? displayName;
  final bool isSelf;
  final bool isAmbiguous;
  final List<TripMember> candidatePayers;

  const _PayerInfo({
    required this.memberId,
    required this.displayName,
    this.isSelf = true,
    this.isAmbiguous = false,
    this.candidatePayers = const [],
  });
}
