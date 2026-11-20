import '../enums/split_type.dart';
import '../models/trip_member.dart';

/// Result of resolving a payer entity from spoken text against trip members.
class ResolvedPayer {
  final String? memberId;
  final String? displayName;
  final bool isAmbiguous;
  final List<TripMember> candidatePayers;
  final bool isSelf;
  final String? rawPayerToken;

  const ResolvedPayer({
    this.memberId,
    this.displayName,
    this.isAmbiguous = false,
    this.candidatePayers = const [],
    this.isSelf = false,
    this.rawPayerToken,
  });

  const ResolvedPayer.self({
    required this.memberId,
    required this.displayName,
  })  : isAmbiguous = false,
        candidatePayers = const [],
        isSelf = true,
        rawPayerToken = 'self';

  const ResolvedPayer.unresolved({this.rawPayerToken})
      : memberId = null,
        displayName = null,
        isAmbiguous = false,
        candidatePayers = const [],
        isSelf = false;

  const ResolvedPayer.ambiguous({
    required this.candidatePayers,
    this.rawPayerToken,
  })  : memberId = null,
        displayName = null,
        isAmbiguous = true,
        isSelf = false;
}

/// Service that matches spoken names and group splitting phrases
/// against live trip members with phonetic and fuzzy tolerance.
class MemberResolutionService {
  const MemberResolutionService._();

  /// Resolves who paid for the expense from spoken text.
  static ResolvedPayer resolvePayer({
    required String clauseLower,
    required List<TripMember> members,
    required String? currentUserId,
  }) {
    // 1. Identify current user's member object
    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ??
        (currentUserId != null && currentUserId.isNotEmpty
            ? members.where((m) => m.id == currentUserId).firstOrNull
            : null) ??
        members.firstOrNull;

    // 2. Identify candidate self and third-party payer positions
    final selfRegex = RegExp(
      r'\b(?:maine|humne|i\s+paid|i\s+spent|my\s+payment|mera\s+payment|mere\s+taraf\s+se|'
      r'paid\s+by\s+me|maine\s+pay\s+kiya|maine\s+diye|maine\s+bhara|i\s+gave)\b',
    );
    final selfMatch = selfRegex.firstMatch(clauseLower);

    final payerRegex = RegExp(
      r'\b([a-zA-Z]+)\s+(?:ne|paid|diye|gave|spent|bhara|bheje|chuka|dediye)\b',
      caseSensitive: false,
    );
    final thirdPartyMatch = payerRegex.firstMatch(clauseLower);

    String? thirdPartyToken;
    if (thirdPartyMatch != null && thirdPartyMatch.group(1) != null) {
      final token = thirdPartyMatch.group(1)!.trim().toLowerCase();
      if (token != 'maine' && token != 'i' && token != 'mera' && token != 'humne' && token != 'we') {
        thirdPartyToken = token;
      }
    }

    // If both self and third-party markers exist, the one occurring earlier takes precedence
    if (thirdPartyToken != null && selfMatch != null) {
      if (thirdPartyMatch!.start < selfMatch.start) {
        return _matchMemberByName(thirdPartyToken, members, selfMember);
      } else if (selfMember != null) {
        return ResolvedPayer.self(
          memberId: selfMember.id,
          displayName: selfMember.displayName,
        );
      }
    }

    if (thirdPartyToken != null) {
      return _matchMemberByName(thirdPartyToken, members, selfMember);
    }

    if (selfMatch != null && selfMember != null) {
      return ResolvedPayer.self(
        memberId: selfMember.id,
        displayName: selfMember.displayName,
      );
    }

    // Default: If no third-party payer was explicitly identified, assume self payment
    if (selfMember != null) {
      return ResolvedPayer.self(
        memberId: selfMember.id,
        displayName: selfMember.displayName,
      );
    }

    return const ResolvedPayer.unresolved();
  }

  /// Resolves the list of participant member IDs based on spoken text.
  static List<String> resolveParticipants({
    required String clauseLower,
    required List<TripMember> members,
    required String? currentUserId,
    required String? payerMemberId,
  }) {
    if (members.isEmpty) return const [];

    final selfMember = members.where((m) => m.userId == currentUserId).firstOrNull ??
        members.firstOrNull;

    // 1. Check for explicit universal markers ("sabke liye", "for all", "equally", etc.)
    if (RegExp(
      r'\b(?:sabke\s+liye|sabka|sabke|for\s+everyone|for\s+all|all\s+members|'
      r'sab\s+log|sab\s+mein|sabke\s+beech|hum\s+sab|hum\s+sabke|together)\b',
    ).hasMatch(clauseLower)) {
      return members.map((m) => m.id).toList();
    }

    // 2. Check for explicit subset phrases:
    // Patterns with high precedence: "for me and X", "mere aur X ke beech", "between X and Y"
    final subsetPatterns = [
      RegExp(r'\b(?:for\s+me\s+and|mere\s+aur)\s+([a-zA-Z\s,&]+)', caseSensitive: false),
      RegExp(r'\b(?:between)\s+([a-zA-Z\s,&]+)', caseSensitive: false),
      RegExp(r'\b(?:sirf)\s+([a-zA-Z\s,&]+)', caseSensitive: false),
      RegExp(r'\b(?:for)\s+([a-zA-Z\s,&]+)\s+only\b', caseSensitive: false),
    ];

    for (final pattern in subsetPatterns) {
      final match = pattern.firstMatch(clauseLower);
      if (match != null && match.group(1) != null) {
        String namesString = match.group(1)!.trim();
        // Strip trailing conjunctions, postpositions, and instructions
        namesString = namesString.replaceAll(
          RegExp(r'\s+(?:ke\s+beech|ke\s+andar|mein|me|among|between|split|divide|karo|kar\s+do|bhi|only)\b.*$', caseSensitive: false),
          '',
        );
        final tokens = namesString
            .split(RegExp(r'[,&]|\band\b|\baur\b'))
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();

        final resolvedIds = <String>{};

        if (clauseLower.contains('mere') || clauseLower.contains('me and') || clauseLower.contains('for me')) {
          if (selfMember != null) {
            resolvedIds.add(selfMember.id);
          }
        }

        for (final t in tokens) {
          if (t == 'me' || t == 'mere' || t == 'mera' || t == 'i') {
            if (selfMember != null) resolvedIds.add(selfMember.id);
            continue;
          }
          if (t == 'all' || t == 'everyone' || t == 'sab') {
            return members.map((m) => m.id).toList();
          }

          final matched = _findSingleMember(t, members);
          if (matched != null) {
            resolvedIds.add(matched.id);
          }
        }

        if (resolvedIds.isNotEmpty) {
          return resolvedIds.toList();
        }
      }
    }

    // 3. Check for "hum dono mein" (Self + Payer, or first 2 members)
    if (RegExp(r'\b(?:hum\s+dono|both\s+of\s+us|dono\s+mein)\b').hasMatch(clauseLower)) {
      final ids = <String>{};
      if (selfMember != null) ids.add(selfMember.id);
      if (payerMemberId != null && payerMemberId.isNotEmpty) ids.add(payerMemberId);
      if (ids.length < 2 && members.length >= 2) {
        for (final m in members) {
          ids.add(m.id);
          if (ids.length == 2) break;
        }
      }
      return ids.toList();
    }

    // Default: If no explicit restriction was mentioned, all trip members participate
    return members.map((m) => m.id).toList();
  }

  /// Determines the split type from spoken language.
  static SplitType resolveSplitType(String clauseLower) {
    if (RegExp(r'\b(?:percentage|percent|pratishat)\b').hasMatch(clauseLower)) {
      return SplitType.percentage;
    }
    if (RegExp(r'\b(?:shares|hisse|hissa)\b').hasMatch(clauseLower)) {
      return SplitType.shares;
    }
    // "equally", "barabar", "aadha aadha", "half half", default
    return SplitType.equal;
  }

  /// Matches a candidate name token against trip members.
  static ResolvedPayer _matchMemberByName(
    String queryToken,
    List<TripMember> members,
    TripMember? selfMember,
  ) {
    if (members.isEmpty) {
      return ResolvedPayer.unresolved(rawPayerToken: queryToken);
    }

    final query = queryToken.toLowerCase().trim();

    // 1. Exact or first-name match (e.g. "Rahul" matches "Rahul" and "Rahul Patel")
    final nameMatches = members.where((m) {
      final name = m.displayName.toLowerCase().trim();
      return name == query || name.startsWith('$query ');
    }).toList();

    if (nameMatches.length == 1) {
      return ResolvedPayer(
        memberId: nameMatches.first.id,
        displayName: nameMatches.first.displayName,
        isSelf: selfMember?.id == nameMatches.first.id,
        rawPayerToken: queryToken,
      );
    } else if (nameMatches.length > 1) {
      return ResolvedPayer.ambiguous(
        candidatePayers: nameMatches,
        rawPayerToken: queryToken,
      );
    }

    // 2. Substring match
    final substringMatches = members.where((m) {
      return m.displayName.toLowerCase().contains(query);
    }).toList();

    if (substringMatches.length == 1) {
      return ResolvedPayer(
        memberId: substringMatches.first.id,
        displayName: substringMatches.first.displayName,
        isSelf: selfMember?.id == substringMatches.first.id,
        rawPayerToken: queryToken,
      );
    } else if (substringMatches.length > 1) {
      return ResolvedPayer.ambiguous(
        candidatePayers: substringMatches,
        rawPayerToken: queryToken,
      );
    }

    // 4. Fuzzy Levenshtein match (distance <= 2 for slight STT errors like "Neel" vs "Neil")
    TripMember? bestFuzzy;
    int bestDist = 3;

    for (final m in members) {
      final firstName = m.displayName.toLowerCase().split(' ').first;
      final dist = _levenshtein(query, firstName);
      if (dist < bestDist && dist <= 2) {
        bestDist = dist;
        bestFuzzy = m;
      }
    }

    if (bestFuzzy != null) {
      return ResolvedPayer(
        memberId: bestFuzzy.id,
        displayName: bestFuzzy.displayName,
        isSelf: selfMember?.id == bestFuzzy.id,
        rawPayerToken: queryToken,
      );
    }

    return ResolvedPayer.unresolved(rawPayerToken: queryToken);
  }

  static TripMember? _findSingleMember(String queryToken, List<TripMember> members) {
    final query = queryToken.toLowerCase().trim();
    return members.where((m) => m.displayName.toLowerCase() == query).firstOrNull ??
        members.where((m) => m.displayName.toLowerCase().startsWith('$query ')).firstOrNull ??
        members.where((m) => m.displayName.toLowerCase().contains(query)).firstOrNull;
  }

  /// Calculates Levenshtein edit distance between two strings.
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
