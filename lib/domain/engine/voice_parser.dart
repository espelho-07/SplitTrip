import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import '../models/expense_draft.dart';
import '../models/trip_member.dart';
import 'advanced_voice_expense_parser.dart';
import 'multi_expense_voice_parser.dart';
import 'number_normalization_service.dart';

/// Structured intent extracted from spoken audio transcript.
class VoiceExpenseIntent {
  final int amountInPaise;
  final String title;
  final ExpenseCategory category;
  final bool paidBySelf;
  final String? specifiedPayerName;
  final bool forAllParticipants;
  final List<String> specifiedParticipantNames;
  final SplitType splitType;
  final double confidence;
  final String rawTranscript;

  const VoiceExpenseIntent({
    required this.amountInPaise,
    required this.title,
    required this.category,
    this.paidBySelf = true,
    this.specifiedPayerName,
    this.forAllParticipants = true,
    this.specifiedParticipantNames = const [],
    this.splitType = SplitType.equal,
    required this.confidence,
    required this.rawTranscript,
  });
}

enum PersonalVoiceIntentType {
  expense,
  lend,
  borrow,
  repayment,
}

/// Intermediate structured draft for personal voice expenses and lending/borrowing.
class PersonalVoiceDraft {
  final PersonalVoiceIntentType type;
  final int amountInPaise;
  final String title;
  final ExpenseCategory category;
  final String? personName;
  final double confidence;
  final String rawInput;
  final List<String> unresolvedFields;
  final String? questionPrompt;

  const PersonalVoiceDraft({
    required this.type,
    required this.amountInPaise,
    required this.title,
    required this.category,
    this.personName,
    required this.confidence,
    required this.rawInput,
    this.unresolvedFields = const [],
    this.questionPrompt,
  });

  bool get isReady => amountInPaise > 0 && unresolvedFields.isEmpty;
}

/// Deterministic natural-language and regex parser for English, Hindi, and Hinglish voice inputs.
class VoiceIntentParser {
  VoiceIntentParser._();

  /// Parses voice transcript into structured [PersonalVoiceDraft] for personal expenses or peer lending.
  static PersonalVoiceDraft parsePersonalDraft(String transcript) {
    final lower = transcript.toLowerCase().trim();
    final unresolved = <String>[];
    String? prompt;

    // 1. Detect Intent Type (Lending vs Borrowing vs Expense)
    PersonalVoiceIntentType type = PersonalVoiceIntentType.expense;
    String? personName;

    // Lending keywords: "ko udhar diye", "lent to", "gave to", "ko paise diye", "ko 500 diye"
    final lendMatch = RegExp(
      r'(?:([a-zA-Z]+)\s+ko\s+.*(?:diye|udhar|bheje))|'
      r'(?:lent\s+(?:.*to\s+)?([a-zA-Z]+))|'
      r'(?:gave\s+.*to\s+([a-zA-Z]+))',
    ).firstMatch(lower);

    // Borrowing keywords: "ne mere liye", "borrowed from", "took from", "se udhar liye", "se paise liye"
    final borrowMatch = RegExp(
      r'(?:([a-zA-Z]+)\s+(?:se\s+.*(?:udhar|liye|paise)|ne\s+mere\s+liye))|'
      r'(?:borrowed\s+.*from\s+([a-zA-Z]+))|'
      r'(?:took\s+.*from\s+([a-zA-Z]+))',
    ).firstMatch(lower);

    // Repayment keywords: "returned", "wapas diye", "chuka diye", "settled"
    final repayMatch = RegExp(
      r'(?:([a-zA-Z]+)\s+.*(?:returned|wapas|chuka))|'
      r'(?:received\s+.*from\s+([a-zA-Z]+))',
    ).firstMatch(lower);

    if (repayMatch != null) {
      type = PersonalVoiceIntentType.repayment;
      personName = (repayMatch.group(1) ?? repayMatch.group(2))?.trim();
    } else if (lendMatch != null) {
      type = PersonalVoiceIntentType.lend;
      personName = (lendMatch.group(1) ?? lendMatch.group(2) ?? lendMatch.group(3))?.trim();
    } else if (borrowMatch != null) {
      type = PersonalVoiceIntentType.borrow;
      personName = (borrowMatch.group(1) ?? borrowMatch.group(2) ?? borrowMatch.group(3))?.trim();
    }

    // Capitalize person name if found
    if (personName != null && personName.isNotEmpty) {
      personName = personName[0].toUpperCase() + personName.substring(1);
    }

    // 2. Extract Amount
    final amount = _extractAmountInPaise(lower);
    if (amount == null || amount <= 0) {
      unresolved.add('missing_amount');
      prompt = 'How much did you pay / spend?';
    }

    // 3. Extract Category & Title
    final category = _extractCategory(lower);
    String title;
    if (type == PersonalVoiceIntentType.lend) {
      title = personName != null ? 'Lent to $personName' : 'Money Lent';
    } else if (type == PersonalVoiceIntentType.borrow) {
      title = personName != null ? 'Borrowed from $personName' : 'Money Borrowed';
    } else if (type == PersonalVoiceIntentType.repayment) {
      title = personName != null ? 'Repayment from $personName' : 'Debt Repayment';
    } else {
      // Remove common prefix phrases from title
      title = _generatePersonalTitle(lower, category);
    }

    final double confidence = (amount != null && amount > 0) ? 0.95 : 0.40;

    return PersonalVoiceDraft(
      type: type,
      amountInPaise: amount ?? 0,
      title: title,
      category: category,
      personName: personName,
      confidence: confidence,
      rawInput: transcript,
      unresolvedFields: unresolved,
      questionPrompt: prompt,
    );
  }

  static String _generatePersonalTitle(String text, ExpenseCategory category) {
    if (text.contains('dinner')) return 'Dinner';
    if (text.contains('lunch')) return 'Lunch';
    if (text.contains('breakfast') || text.contains('nasta')) return 'Breakfast';
    if (text.contains('auto') || text.contains('rickshaw')) return 'Auto Ride';
    if (text.contains('cab') || text.contains('taxi') || text.contains('uber') || text.contains('ola')) return 'Cab';
    if (text.contains('petrol') || text.contains('fuel')) return 'Petrol';
    if (text.contains('grocery') || text.contains('groceries') || text.contains('zepto') || text.contains('blinkit')) return 'Groceries';
    if (text.contains('coffee') || text.contains('chai') || text.contains('tea')) return 'Coffee';
    if (text.contains('movie') || text.contains('cinema')) return 'Movie';
    if (text.contains('shopping') || text.contains('clothes')) return 'Shopping';
    if (text.contains('recharge') || text.contains('bill') || text.contains('wifi') || text.contains('electricity')) return 'Bill Payment';
    if (text.contains('medic') || text.contains('pharma') || text.contains('doctor')) return 'Health & Medical';
    return '${category.displayName} Expense';
  }

  /// Parses voice transcript into one or more structured [ExpenseDraft]s using [MultiExpenseVoiceParser].
  static List<ExpenseDraft> parseMultipleToDrafts(
    String transcript,
    List<TripMember> members,
    String currentUserId,
  ) {
    return MultiExpenseVoiceParser.parse(
      transcript,
      members: members,
      currentUserId: currentUserId,
    );
  }

  /// Parses voice transcript into structured intermediate [ExpenseDraft] with entity resolution against trip members.
  static ExpenseDraft parseToDraft(
    String transcript,
    List<TripMember> members,
    String currentUserId,
  ) {
    final drafts = AdvancedVoiceExpenseParser.parse(
      transcript,
      members: members,
      currentUserId: currentUserId,
    );
    if (drafts.isNotEmpty) {
      return drafts.first;
    }

    final intent = parse(transcript);
    final unresolved = <String>[];
    final candidatePayers = <TripMember>[];
    String? resolvedPayerId;
    String? resolvedPayerName;

    // Find current user's membership
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ??
        members.firstOrNull;

    // 1. Resolve Payer
    if (intent.paidBySelf && selfMember != null) {
      resolvedPayerId = selfMember.id;
      resolvedPayerName = selfMember.displayName;
    } else if (intent.specifiedPayerName != null) {
      final query = intent.specifiedPayerName!.toLowerCase().trim();
      final matches = members.where((m) =>
          m.displayName.toLowerCase() == query ||
          m.displayName.toLowerCase().startsWith('$query ') ||
          m.displayName.toLowerCase().contains(query)).toList();

      if (matches.length == 1) {
        resolvedPayerId = matches.first.id;
        resolvedPayerName = matches.first.displayName;
      } else if (matches.length > 1) {
        // Ambiguous payer (e.g. multiple "Rahul"s)
        unresolved.add('payer_ambiguity');
        candidatePayers.addAll(matches);
      } else {
        // Unknown payer not in trip members
        unresolved.add('unknown_payer');
        if (selfMember != null) {
          resolvedPayerId = selfMember.id;
          resolvedPayerName = selfMember.displayName;
        }
      }
    } else if (selfMember != null) {
      resolvedPayerId = selfMember.id;
      resolvedPayerName = selfMember.displayName;
    }

    // 2. Resolve Participants
    final resolvedParticipantIds = <String>[];
    if (intent.forAllParticipants) {
      resolvedParticipantIds.addAll(members.map((m) => m.id));
    } else {
      if (selfMember != null) {
        resolvedParticipantIds.add(selfMember.id);
      }
      for (final name in intent.specifiedParticipantNames) {
        final query = name.toLowerCase().trim();
        final match = members.where((m) =>
            m.displayName.toLowerCase() == query ||
            m.displayName.toLowerCase().startsWith('$query ') ||
            m.displayName.toLowerCase().contains(query)).firstOrNull;

        if (match != null && !resolvedParticipantIds.contains(match.id)) {
          resolvedParticipantIds.add(match.id);
        }
      }
    }

    if (resolvedParticipantIds.isEmpty) {
      resolvedParticipantIds.addAll(members.map((m) => m.id));
      unresolved.add('participants');
    }

    // 3. Amount Validation
    if (intent.amountInPaise <= 0) {
      unresolved.add('amount');
    }

    return ExpenseDraft(
      amountInPaise: intent.amountInPaise,
      title: intent.title,
      category: intent.category,
      payerMemberId: resolvedPayerId,
      payerName: resolvedPayerName,
      participantMemberIds: resolvedParticipantIds,
      splitType: intent.splitType,
      confidence: unresolved.isEmpty ? intent.confidence : (intent.confidence * 0.6),
      rawInput: transcript,
      source: ExpenseDraftSource.voice,
      unresolvedFields: unresolved,
      candidatePayers: candidatePayers,
      ambiguityMessage: unresolved.contains('payer_ambiguity')
          ? 'Multiple members named "${intent.specifiedPayerName}" found in this trip.'
          : (unresolved.contains('amount') ? 'Could not confidently detect the expense amount.' : null),
    );
  }

  static VoiceExpenseIntent parse(String transcript) {
    final text = transcript.trim();
    final lower = text.toLowerCase();

    // 1. Extract Amount
    int? extractedPaise = _extractAmountInPaise(lower);
    extractedPaise ??= 0;

    // 2. Identify Category
    final category = _extractCategory(lower);

    // 3. Identify Payer
    bool paidBySelf = true;
    String? payerName;
    if (lower.contains('maine') || lower.contains('i paid') || lower.contains('i spent') || lower.contains('my payment') || lower.contains('mera payment')) {
      paidBySelf = true;
    } else {
      // Check if someone else paid e.g., "Rahul ne", "Rahul paid", "Rahul gave"
      final payerMatch = RegExp(r'([a-zA-Z]+)\s+(?:ne|paid|diye|gave|spent)', caseSensitive: false).firstMatch(text);
      if (payerMatch != null && payerMatch.group(1) != null) {
        final candidate = payerMatch.group(1)!.trim();
        if (candidate.toLowerCase() != 'i' && candidate.toLowerCase() != 'maine' && candidate.toLowerCase() != 'mera') {
          paidBySelf = false;
          payerName = candidate;
        }
      }
    }

    // 4. Identify Participants
    bool forAll = true;
    final specificParticipants = <String>[];
    if (lower.contains('sabke liye') || lower.contains('for everyone') || lower.contains('for all') || lower.contains('sabke') || lower.contains('all members')) {
      forAll = true;
    } else if (lower.contains('for me and ') || lower.contains('mere aur ') || lower.contains('for ') || lower.contains('between ')) {
      forAll = false;
      final partMatch = RegExp(r'(?:for me and|mere aur|for|between)\s+([a-zA-Z\s,]+)', caseSensitive: false).firstMatch(text);
      if (partMatch != null && partMatch.group(1) != null) {
        final names = partMatch.group(1)!.split(RegExp(r'[,&]|\band\b|\baur\b'));
        for (final n in names) {
          final trimmed = n.trim();
          if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'everyone' && trimmed.toLowerCase() != 'all') {
            specificParticipants.add(trimmed);
          }
        }
      }
    }

    // 5. Generate Smart Clean Title
    String title = _generateTitle(lower, category);

    double confidence = (extractedPaise > 0) ? 0.95 : 0.4;

    return VoiceExpenseIntent(
      amountInPaise: extractedPaise,
      title: title,
      category: category,
      paidBySelf: paidBySelf,
      specifiedPayerName: payerName,
      forAllParticipants: forAll,
      specifiedParticipantNames: specificParticipants,
      splitType: SplitType.equal,
      confidence: confidence,
      rawTranscript: transcript,
    );
  }

  static int? _extractAmountInPaise(String text) {
    final normalized = NumberNormalizationService.extractAmountInPaise(text);
    if (normalized != null) return normalized;

    // Check for "k" notation e.g., "6k", "6.5k"
    final kMatch = RegExp(r'(\d+(?:\.\d+)?)\s*k\b').firstMatch(text);
    if (kMatch != null) {
      final val = double.tryParse(kMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // Check for "hazar" / "hazaar" (Hindi thousand)
    final hazarMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hazar|hazaar|thousand)').firstMatch(text);
    if (hazarMatch != null) {
      final val = double.tryParse(hazarMatch.group(1)!);
      if (val != null) return (val * 1000 * 100).round();
    }

    // Check for words like "ek hazar", "do hazar", "chhe hazar"
    final wordMap = {
      'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'panch': 5,
      'chhe': 6, 'che': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    };
    for (final entry in wordMap.entries) {
      if (text.contains('${entry.key} hazar') || text.contains('${entry.key} thousand')) {
        return entry.value * 1000 * 100;
      }
    }

    // Check for standard digits (e.g. 6000, 850.50, ₹1,200, 6000 rupees)
    final digitMatch = RegExp(r'(?:₹|rs\.?|inr|\$)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:rupees|rupee|inr|rs)?').firstMatch(text);
    if (digitMatch != null && digitMatch.group(1) != null) {
      final cleaned = digitMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(cleaned);
      if (val != null) return (val * 100).round();
    }

    return null;
  }

  static ExpenseCategory _extractCategory(String text) {
    if (text.contains('train') || text.contains('flight') || text.contains('cab') ||
        text.contains('taxi') || text.contains('uber') || text.contains('ola') ||
        text.contains('petrol') || text.contains('auto') || text.contains('bus')) {
      return ExpenseCategory.transport;
    }
    if (text.contains('dinner') || text.contains('lunch') || text.contains('food') ||
        text.contains('khana') || text.contains('restaurant') || text.contains('pizza') ||
        text.contains('burger') || text.contains('nasta') || text.contains('breakfast')) {
      return ExpenseCategory.food;
    }
    if (text.contains('hotel') || text.contains('stay') || text.contains('resort') ||
        text.contains('room') || text.contains('airbnb') || text.contains('villa')) {
      return ExpenseCategory.stay;
    }
    if (text.contains('chai') || text.contains('coffee') || text.contains('beer') ||
        text.contains('drinks') || text.contains('bar') || text.contains('cafe')) {
      return ExpenseCategory.drinks;
    }
    if (text.contains('scuba') || text.contains('trek') || text.contains('ticket') ||
        text.contains('movie') || text.contains('surf') || text.contains('activity')) {
      return ExpenseCategory.activities;
    }
    if (text.contains('shopping') || text.contains('clothes') || text.contains('mall')) {
      return ExpenseCategory.shopping;
    }
    if (text.contains('grocery') || text.contains('ration') || text.contains('supermarket') ||
        text.contains('zepto') || text.contains('blinkit')) {
      return ExpenseCategory.groceries;
    }
    return ExpenseCategory.general;
  }

  static String _generateTitle(String text, ExpenseCategory category) {
    if (text.contains('train')) return 'Train Tickets';
    if (text.contains('flight')) return 'Flight Booking';
    if (text.contains('cab') || text.contains('taxi') || text.contains('uber')) return 'Cab Ride';
    if (text.contains('dinner')) return 'Group Dinner';
    if (text.contains('lunch')) return 'Lunch';
    if (text.contains('chai') || text.contains('coffee')) return 'Coffee & Snacks';
    if (text.contains('hotel') || text.contains('stay')) return 'Hotel Stay';
    if (text.contains('drinks') || text.contains('beer')) return 'Drinks';
    if (text.contains('grocery')) return 'Groceries';
    return '${category.displayName} Expense';
  }
}
