import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import '../models/expense_draft.dart';
import '../models/trip_member.dart';

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

/// Deterministic natural-language and regex parser for English, Hindi, and Hinglish voice inputs.
class VoiceIntentParser {
  VoiceIntentParser._();

  /// Parses voice transcript into structured intermediate [ExpenseDraft] with entity resolution against trip members.
  static ExpenseDraft parseToDraft(
    String transcript,
    List<TripMember> members,
    String currentUserId,
  ) {
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
