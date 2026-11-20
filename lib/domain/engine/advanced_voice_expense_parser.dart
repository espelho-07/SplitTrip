import '../enums/expense_category.dart';
import '../models/expense_draft.dart';
import '../models/trip_member.dart';
import 'expense_date_extractor.dart';
import 'member_resolution_service.dart';
import 'number_normalization_service.dart';

/// Master NLP & Speech Understanding Engine for Kith voice expense input.
///
/// Seamlessly converts unstructured English, Hindi, and Hinglish speech into
/// fully validated, context-aware [ExpenseDraft]s with:
/// - 100% integer paise precision
/// - Indian spoken numeral understanding ("teen sau pachaas", "barah sau", "dedh hazar")
/// - Temporal date awareness ("aaj", "today", "kal", "yesterday", "parso")
/// - Live trip member entity resolution and fuzzy matching
/// - Multi-expense compound sentence segmentation
class AdvancedVoiceExpenseParser {
  const AdvancedVoiceExpenseParser._();

  /// Stop words stripped from clauses when extracting clean expense titles.
  static const Set<String> _stopWords = {
    // Hindi / Hinglish pronouns & verbs
    'maine', 'mera', 'meri', 'mere', 'humne', 'hamaare', 'apna', 'apni',
    'ne', 'diye', 'diya', 'dii', 'de', 'dediye', 'kharch', 'kharcha',
    'kiye', 'kiya', 'hue', 'hua', 'hui', 'kare', 'karo', 'bharwaya', 'bharwaye',
    'pe', 'par', 'ke', 'ka', 'ki', 'ko', 'se', 'mein', 'beech',
    'liye', 'bheje', 'bheja', 'dala', 'dale', 'bhare', 'bhara',
    'tha', 'thi', 'the', 'hai', 'hain', 'ho', 'gaye', 'gaya', 'gayi',
    'laga', 'lage', 'lagi', 'thee', 'baaki', 'baki',
    // English pronouns & verbs
    'i', 'we', 'me', 'my', 'mine', 'our', 'us',
    'paid', 'spent', 'pay', 'spend', 'gave', 'given', 'bought', 'cost',
    'for', 'on', 'at', 'in', 'to', 'from', 'with', 'between',
    'a', 'an', 'some', 'only', 'just', 'add',
    'yesterday', 'today', 'tonight', 'recently', 'last', 'night',
    // Currency markers
    'rupee', 'rupees', 'rupaye', 'rupya', 'rs', 'inr', 'bucks', 'dollars',
    // Conjunctions / group tokens
    'and', 'aur', 'plus', 'also', 'then', 'phir', 'baad', 'uske',
    'sabke', 'everyone', 'all', 'together', 'total', 'sirf', 'hum',
  };

  /// Parses voice [transcript] into one or more structured [ExpenseDraft]s.
  static List<ExpenseDraft> parse(
    String transcript, {
    List<TripMember> members = const [],
    String? currentUserId,
    String tripCurrency = 'INR',
  }) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];

    // 1. Detect global payer if present at root (e.g. "Rahul ne ...")
    final globalPayer = MemberResolutionService.resolvePayer(
      clauseLower: trimmed.toLowerCase(),
      members: members,
      currentUserId: currentUserId,
    );

    // 2. Segment transcript into discrete clauses
    final clauses = _segmentTranscript(trimmed);
    if (clauses.isEmpty) return const [];

    final drafts = <ExpenseDraft>[];

    for (final clause in clauses) {
      final draft = _parseSingleClause(
        clause: clause,
        globalPayer: globalPayer,
        members: members,
        currentUserId: currentUserId,
        tripCurrency: tripCurrency,
      );
      if (draft != null) {
        drafts.add(draft);
      }
    }

    if (drafts.isEmpty) {
      final fallback = _parseSingleClause(
        clause: trimmed,
        globalPayer: globalPayer,
        members: members,
        currentUserId: currentUserId,
        tripCurrency: tripCurrency,
      );
      if (fallback != null) drafts.add(fallback);
    }

    return drafts;
  }

  /// Parses a single segmented clause into an [ExpenseDraft].
  static ExpenseDraft? _parseSingleClause({
    required String clause,
    required ResolvedPayer globalPayer,
    required List<TripMember> members,
    required String? currentUserId,
    required String tripCurrency,
  }) {
    final lower = clause.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final unresolved = <String>[];

    // 1. Extract Amount in integer paise via NumberNormalizationService
    final amountInPaise = NumberNormalizationService.extractAmountInPaise(clause);
    if (amountInPaise == null || amountInPaise <= 0) {
      unresolved.add('amount');
    }

    // 2. Extract Temporal Date via ExpenseDateExtractor
    final date = ExpenseDateExtractor.extractDate(clause);

    // 3. Extract Category
    final category = _extractCategory(lower);

    // 4. Extract Clean Title
    final title = _extractCleanTitle(clause, lower, category);

    // 5. Resolve Payer (check local clause first, fallback to global root payer)
    ResolvedPayer payer = MemberResolutionService.resolvePayer(
      clauseLower: lower,
      members: members,
      currentUserId: currentUserId,
    );

    if (payer.memberId == null && globalPayer.memberId != null) {
      payer = globalPayer;
    }

    if (payer.isAmbiguous) {
      unresolved.add('payer_ambiguity');
    }

    // 6. Resolve Participants
    final participants = MemberResolutionService.resolveParticipants(
      clauseLower: lower,
      members: members,
      currentUserId: currentUserId,
      payerMemberId: payer.memberId,
    );

    // 7. Resolve Split Type
    final splitType = MemberResolutionService.resolveSplitType(lower);

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
      splitType: splitType,
      confidence: confidence,
      rawInput: clause,
      source: ExpenseDraftSource.voice,
      unresolvedFields: unresolved,
      candidatePayers: payer.candidatePayers,
      ambiguityMessage: payer.isAmbiguous
          ? 'Multiple members found with name "${payer.rawPayerToken ?? ''}".'
          : (amountInPaise == null || amountInPaise <= 0 ? 'Amount could not be detected.' : null),
      expenseDate: date,
      currency: tripCurrency,
    );
  }

  /// Segments compound voice transcripts into individual expense clauses.
  static List<String> _segmentTranscript(String transcript) {
    // Split on delimiters and conjunction markers
    final delimiterPattern = RegExp(
      r'(?:[\r\n;,+]+|\s+(?:aur|and|plus|then|phir|uske\s+baad|after\s+that)\s+)',
      caseSensitive: false,
    );

    final initialSegments = transcript
        .split(delimiterPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Recombine orphan clauses that lack an amount with their corresponding expense clause
    final mergedSegments = <String>[];
    String currentBuffer = '';

    for (int i = 0; i < initialSegments.length; i++) {
      final seg = initialSegments[i];
      final amt = NumberNormalizationService.extractAmountInPaise(seg);

      if (amt == null) {
        if (currentBuffer.isEmpty) {
          currentBuffer = seg;
        } else {
          currentBuffer = '$currentBuffer $seg';
        }
      } else {
        if (currentBuffer.isNotEmpty) {
          mergedSegments.add('$currentBuffer $seg');
          currentBuffer = '';
        } else {
          mergedSegments.add(seg);
        }
      }
    }

    if (currentBuffer.isNotEmpty) {
      if (mergedSegments.isNotEmpty) {
        final last = mergedSegments.removeLast();
        mergedSegments.add('$last $currentBuffer');
      } else {
        mergedSegments.add(currentBuffer);
      }
    }

    final finalClauses = <String>[];

    for (final seg in mergedSegments) {
      final subSegments = _splitMultiAmountSegment(seg);
      finalClauses.addAll(subSegments);
    }

    return finalClauses.isNotEmpty ? finalClauses : [transcript];
  }

  /// Splits an unpunctuated segment if it contains multiple discrete amounts.
  static List<String> _splitMultiAmountSegment(String text) {
    final amountPattern = RegExp(
      r'(?:₹|rs\.?|inr|\$)?\s*\b\d+(?:,\d+)*(?:\.\d+)?\s*(?:[kK]|thousand|hazar|hazaar|lakh|lac|crore|sau|hundred|rupees|rupee|rs)?\b|'
      r'\b(?:dedh|dhai|sade|saade)\s+(?:hazar|sau|thousand)\b|'
      r'\b(?:ek|do|teen|char|chaar|panch|paanch|chhe|che|saat|aath|nau|das|gyarah|barah|pandrah|bees|pachees|pachaas)\s+(?:sau|hundred|hazar|thousand|lakh)\b',
      caseSensitive: false,
    );

    final matches = amountPattern.allMatches(text).toList();
    if (matches.length <= 1) {
      return [text];
    }

    final tokens = text.split(RegExp(r'\s+'));
    final amountIndices = <int>[];

    for (int i = 0; i < tokens.length; i++) {
      if (_hasAmountToken(tokens[i])) {
        // If next token is a multiplier unit ("lakh", "thousand", "sau", "hazar"), skip treating it as a separate amount
        if (i + 1 < tokens.length && _isMultiplier(tokens[i + 1])) {
          amountIndices.add(i);
          i++; // Skip the multiplier token
        } else {
          amountIndices.add(i);
        }
      }
    }

    if (amountIndices.length <= 1) {
      return [text];
    }

    final chunks = <String>[];
    int startIdx = 0;

    for (int i = 0; i < amountIndices.length; i++) {
      final currentAmountIdx = amountIndices[i];
      final nextAmountIdx = (i + 1 < amountIndices.length) ? amountIndices[i + 1] : tokens.length;

      if (i == 0) {
        if (currentAmountIdx > startIdx) {
          // Descriptor preceded first amount (e.g. "train 4000")
          final nextCut = (nextAmountIdx - 1 > currentAmountIdx) ? nextAmountIdx - 1 : currentAmountIdx + 1;
          chunks.add(tokens.sublist(startIdx, nextCut).join(' '));
          startIdx = nextCut;
        } else {
          // Amount came first (e.g. "4k train")
          chunks.add(tokens.sublist(startIdx, nextAmountIdx).join(' '));
          startIdx = nextAmountIdx;
        }
      } else if (i == amountIndices.length - 1) {
        chunks.add(tokens.sublist(startIdx).join(' '));
      } else {
        chunks.add(tokens.sublist(startIdx, nextAmountIdx).join(' '));
        startIdx = nextAmountIdx;
      }
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  static bool _hasAmountToken(String token) {
    final clean = token.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    if (RegExp(r'^\d+[kK]?$').hasMatch(clean)) return true;
    if (clean == 'sau' || clean == 'hundred' || clean == 'hazar' || clean == 'thousand' || clean == 'lakh') {
      return true;
    }
    return false;
  }

  static bool _isMultiplier(String token) {
    final clean = token.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    return clean == 'sau' || clean == 'hundred' || clean == 'hazar' || clean == 'thousand' || clean == 'lakh' || clean == 'lac' || clean == 'crore';
  }

  /// Classifies category from speech keywords.
  static ExpenseCategory _extractCategory(String text) {
    // 1. Transport
    if (RegExp(r'\b(?:train|flight|cab|taxi|uber|ola|auto|rickshaw|petrol|diesel|fuel|cng|bus|metro|toll|parking|fastag|bike|scooty|rental)\b').hasMatch(text)) {
      return ExpenseCategory.transport;
    }
    // 2. Food
    if (RegExp(r'\b(?:dinner|lunch|breakfast|nasta|nashta|khana|food|restaurant|cafe|dhaba|pizza|burger|biryani|thali|snacks|swiggy|zomato|kfc|domino)\b').hasMatch(text)) {
      return ExpenseCategory.food;
    }
    // 3. Stay
    if (RegExp(r'\b(?:hotel|stay|resort|room|airbnb|villa|hostel|homestay|lodge|camp|tent)\b').hasMatch(text)) {
      return ExpenseCategory.stay;
    }
    // 4. Drinks
    if (RegExp(r'\b(?:chai|tea|coffee|beer|drinks|bar|pub|club|alcohol|daru|wine|mocktail|cocktail|juice|lassi)\b').hasMatch(text)) {
      return ExpenseCategory.drinks;
    }
    // 5. Activities
    if (RegExp(r'\b(?:scuba|trek|trekking|ticket|tickets|entry|movie|cinema|surf|surfing|boat|boating|safari|passes|museum|adventure|parasailing)\b').hasMatch(text)) {
      return ExpenseCategory.activities;
    }
    // 6. Shopping
    if (RegExp(r'\b(?:shopping|clothes|mall|market|souvenir|gift|gifts|tshirt|shoes)\b').hasMatch(text)) {
      return ExpenseCategory.shopping;
    }
    // 7. Groceries
    if (RegExp(r'\b(?:grocery|groceries|ration|supermarket|zepto|blinkit|instamart|milk|water|bisleri|chips|veggies|sabzi|fruits)\b').hasMatch(text)) {
      return ExpenseCategory.groceries;
    }

    return ExpenseCategory.general;
  }

  /// Generates a clean, capitalized title by filtering amounts, dates, and noise words.
  static String _extractCleanTitle(String clause, String lower, ExpenseCategory category) {
    // 1. Strip temporal keywords
    String cleaned = ExpenseDateExtractor.cleanTemporalKeywords(lower);

    // 2. Strip amounts and numbers (replace with a space to preserve word separation)
    cleaned = cleaned
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*[kK]\b'), ' ')
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*(?:lakh|lac|crore)\b'), ' ')
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*(?:hazar|hazaar|thousand)\b'), ' ')
        .replaceAll(RegExp(r'\b\d+\s*(?:sau|hundred)\b'), ' ')
        .replaceAll(RegExp(r'(?:₹|rs\.?|inr|\$)?\s*\b\d+(?:,\d+)*(?:\.\d{1,2})?\s*(?:rupees|rupee|rupaye|rupya|inr|rs|bucks)?\b'), ' ')
        .replaceAll(RegExp(r'\b(?:dedh|dhai|sade|saade)\s+(?:hazar|sau|thousand|hundred)\b'), ' ')
        .replaceAll(RegExp(r'\b(?:ek|do|teen|char|chaar|panch|paanch|chhe|che|saat|aath|nau|das|gyarah|barah|terah|pandrah|bees|pachees|pachaas|sau|hundred|hazar|thousand)\b'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ' ');

    // 3. Tokenize and filter stop words
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t) && t.length > 1)
        .toList();

    if (tokens.isNotEmpty) {
      if (tokens.length == 1) {
        final single = tokens.first.toLowerCase();
        if (single == 'train') return 'Train';
        if (single == 'flight') return 'Flight';
        if (single == 'taxi') return 'Taxi';
        if (single == 'cab' || single == 'uber' || single == 'ola') return 'Cab';
        if (single == 'auto' || single == 'rickshaw') return 'Auto';
        if (single == 'hotel' || single == 'stay') return 'Hotel';
        if (single == 'dinner') return 'Dinner';
        if (single == 'lunch') return 'Lunch';
        if (single == 'chai' || single == 'coffee') return 'Coffee & Snacks';
      }

      final capitalized = tokens
          .map((t) => t.length > 1 ? (t[0].toUpperCase() + t.substring(1)) : t.toUpperCase())
          .join(' ');
      return capitalized;
    }

    // Fallback: Smart contextual title based on category keywords
    if (lower.contains('train')) return 'Train';
    if (lower.contains('flight')) return 'Flight';
    if (lower.contains('cab') || lower.contains('taxi') || lower.contains('uber') || lower.contains('ola')) return 'Cab';
    if (lower.contains('auto') || lower.contains('rickshaw')) return 'Auto';
    if (lower.contains('toll')) return 'Toll Tax';
    if (lower.contains('petrol') || lower.contains('fuel')) return 'Petrol';
    if (lower.contains('dinner')) return 'Dinner';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('breakfast') || lower.contains('nasta') || lower.contains('nashta')) return 'Breakfast';
    if (lower.contains('hotel') || lower.contains('stay') || lower.contains('resort')) return 'Hotel';
    if (lower.contains('chai') || lower.contains('coffee')) return 'Coffee & Snacks';
    if (lower.contains('drinks') || lower.contains('beer') || lower.contains('club')) return 'Drinks & Club';
    if (lower.contains('grocery') || lower.contains('groceries')) return 'Groceries';

    return '${category.displayName} Expense';
  }
}
