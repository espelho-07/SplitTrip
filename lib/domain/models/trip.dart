import '../enums/trip_lifecycle.dart';
import 'trip_member.dart';

/// Result of a deep merge between two Trip snapshots, exposing any member ID translations
/// and identifying ambiguous/unresolved member candidates.
class TripMergeResult {
  final Trip mergedTrip;
  final Map<String, String> memberIdMap;
  final List<String> unresolvedMemberIds;

  const TripMergeResult({
    required this.mergedTrip,
    this.memberIdMap = const {},
    this.unresolvedMemberIds = const [],
  });
}

/// Core Trip aggregate root.
class Trip {
  final String id;
  final String name;
  final String? description;
  final String emoji;
  final int coverGradientIndex;
  final String currencyCode;
  final String creatorId;
  final List<TripMember> members;
  final TripLifecycle lifecycleState;
  final String inviteCode;
  final String? p2pTripSecret;
  final String tripMode; // 'split_only' or 'split_and_journey'
  final int revision;
  final String? completionMode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isJourneyEnabled => tripMode == 'split_and_journey';

  Trip({
    required this.id,
    required this.name,
    this.description,
    this.emoji = '✈️',
    this.coverGradientIndex = 0,
    this.currencyCode = 'INR',
    required this.creatorId,
    required this.members,
    this.lifecycleState = TripLifecycle.active,
    required this.inviteCode,
    this.p2pTripSecret,
    this.tripMode = 'split_only',
    this.revision = 1,
    this.completionMode,
    DateTime? startedAt,
    this.completedAt,
    this.completedBy,
    required this.createdAt,
    required this.updatedAt,
  }) : startedAt = startedAt ?? createdAt;

  Trip copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    int? coverGradientIndex,
    String? currencyCode,
    String? creatorId,
    List<TripMember>? members,
    TripLifecycle? lifecycleState,
    String? inviteCode,
    String? p2pTripSecret,
    String? tripMode,
    int? revision,
    String? completionMode,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      coverGradientIndex: coverGradientIndex ?? this.coverGradientIndex,
      currencyCode: currencyCode ?? this.currencyCode,
      creatorId: creatorId ?? this.creatorId,
      members: members ?? this.members,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      inviteCode: inviteCode ?? this.inviteCode,
      p2pTripSecret: p2pTripSecret ?? this.p2pTripSecret,
      tripMode: tripMode ?? this.tripMode,
      revision: revision ?? this.revision,
      completionMode: completionMode ?? this.completionMode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Safely merges this local trip aggregate with a remote or cached snapshot.
  /// Backward compatible wrapper around [mergeWithDetailed].
  /// Checks whether a given user ID is the creator of this trip.
  bool isCreator(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (creatorId == userId) return true;
    return members.any((m) => (m.userId == userId || m.id == userId) && m.isCreator);
  }

  Trip mergeWith(Trip other) => mergeWithDetailed(other).mergedTrip;

  /// Safely merges this local trip aggregate with a remote or cached snapshot,
  /// tracking all member ID translations and unresolved identity ambiguities.
  TripMergeResult mergeWithDetailed(Trip other) {
    if (other.id != id) {
      return TripMergeResult(mergedTrip: this);
    }

    final memberIdMap = <String, String>{};
    final unresolvedMemberIds = <String>{};
    final mergedMembersMap = <String, TripMember>{};

    // 1. Seed with this trip's members
    for (final m in members) {
      mergedMembersMap[m.id] = m;
    }

    // 2. Union merge other trip's members
    for (final otherMember in other.members) {
      if (mergedMembersMap.containsKey(otherMember.id)) {
        final existing = mergedMembersMap[otherMember.id]!;
        final chosenDisplayName =
            (otherMember.displayName.isNotEmpty &&
                otherMember.displayName != 'Member')
            ? otherMember.displayName
            : existing.displayName;

        final bool isNowClaimed = otherMember.isClaimed || existing.isClaimed;
        final String chosenUserId;
        if (!existing.userId.startsWith('unclaimed_') && existing.userId.isNotEmpty) {
          chosenUserId = existing.userId;
        } else if (!otherMember.userId.startsWith('unclaimed_') && otherMember.userId.isNotEmpty) {
          chosenUserId = otherMember.userId;
        } else {
          chosenUserId = existing.userId.isNotEmpty ? existing.userId : otherMember.userId;
        }

        mergedMembersMap[otherMember.id] = existing.copyWith(
          displayName: chosenDisplayName,
          userId: chosenUserId,
          avatarUrl: otherMember.avatarUrl ?? existing.avatarUrl,
          role: otherMember.role != 'member' && otherMember.role != 'virtual' ? otherMember.role : existing.role,
          upiId: otherMember.upiId ?? existing.upiId,
          isClaimed: isNowClaimed,
          status: isNowClaimed ? 'claimed' : (otherMember.status ?? existing.status),
          claimToken: otherMember.claimToken ?? existing.claimToken,
          mergedIntoMemberId:
              otherMember.mergedIntoMemberId ?? existing.mergedIntoMemberId,
          isVirtualMember: !isNowClaimed,
        );

        // Deduplication self-healing: if otherMember is an unclaimed virtual member,
        // collapse any other local unclaimed virtual members sharing the exact display name,
        // unless they have a distinct claimToken matching another server member.
        if (otherMember.isVirtual && !otherMember.isClaimed) {
          final otherName = otherMember.displayName.trim().toLowerCase();
          final duplicateUnclaimed = mergedMembersMap.values
              .where((m) =>
                  m.id != otherMember.id &&
                  !m.isMerged &&
                  m.isVirtual &&
                  !m.isClaimed &&
                  (m.userId.startsWith('unclaimed_') || m.userId.isEmpty) &&
                  m.displayName.trim().toLowerCase() == otherName &&
                  !other.members.any((sm) =>
                      sm.id != otherMember.id &&
                      sm.claimToken != null &&
                      sm.claimToken!.isNotEmpty &&
                      sm.claimToken == m.claimToken))
              .toList();
          for (final dup in duplicateUnclaimed) {
            memberIdMap[dup.id] = otherMember.id;
            mergedMembersMap.remove(dup.id);
          }
        }
      } else {
        // 2a. Match by claimToken if present
        TripMember? matchedByToken;
        if (otherMember.claimToken != null && otherMember.claimToken!.isNotEmpty) {
          matchedByToken = mergedMembersMap.values
              .where((m) => m.claimToken == otherMember.claimToken)
              .firstOrNull;
        }

        // 2b. Match by authenticated userId if not unclaimed
        TripMember? matchedByUserId;
        if (matchedByToken == null &&
            otherMember.userId.isNotEmpty &&
            !otherMember.userId.startsWith('unclaimed_')) {
          matchedByUserId = mergedMembersMap.values
              .where(
                (m) =>
                    m.userId.isNotEmpty &&
                    !m.userId.startsWith('unclaimed_') &&
                    m.userId == otherMember.userId,
              )
              .firstOrNull;
        }

        // 2c. Identity reconciliation:
        //  - Valid claimToken matching (2a)
        //  - Trusted, authenticated userId matching (2b)
        //  - Name-based reconciliation:
        //      * Unclaimed virtual to unclaimed virtual
        //      * Real claimed member to unclaimed virtual placeholder (e.g. user joins after being added virtually)
        //      * Unclaimed virtual placeholder to real claimed member
        TripMember? matchedByName;
        if (matchedByToken == null && matchedByUserId == null) {
          final otherName = otherMember.displayName.trim().toLowerCase();
          if (otherName.isNotEmpty && otherName != 'member' && otherName != 'traveler') {
            // Case 1: otherMember is virtual/unclaimed, matching a virtual/unclaimed candidate
            if (otherMember.isVirtual &&
                !otherMember.isClaimed &&
                (otherMember.userId.startsWith('unclaimed_') || otherMember.userId.isEmpty)) {
              final candidates = mergedMembersMap.values
                  .where((m) =>
                      !m.isMerged &&
                      m.isVirtual &&
                      !m.isClaimed &&
                      (m.userId.startsWith('unclaimed_') || m.userId.isEmpty) &&
                      m.displayName.trim().toLowerCase() == otherName)
                  .toList();
              if (candidates.length == 1) {
                matchedByName = candidates.first;
              }
            }

            // Case 2: otherMember is a REAL CLAIMED member, matching an unclaimed virtual placeholder in mergedMembersMap
            if (matchedByName == null &&
                !otherMember.isVirtual &&
                otherMember.isClaimed &&
                otherMember.userId.isNotEmpty &&
                !otherMember.userId.startsWith('unclaimed_')) {
              final candidates = mergedMembersMap.values
                  .where((m) =>
                      !m.isMerged &&
                      m.isVirtual &&
                      !m.isClaimed &&
                      (m.userId.startsWith('unclaimed_') || m.userId.isEmpty) &&
                      m.displayName.trim().toLowerCase() == otherName)
                  .toList();
              if (candidates.length == 1) {
                matchedByName = candidates.first;
              }
            }

            // Case 3: otherMember is an UNCLAIMED VIRTUAL placeholder, matching a real claimed member in mergedMembersMap
            if (matchedByName == null &&
                otherMember.isVirtual &&
                !otherMember.isClaimed &&
                (otherMember.userId.startsWith('unclaimed_') || otherMember.userId.isEmpty)) {
              final candidates = mergedMembersMap.values
                  .where((m) =>
                      !m.isMerged &&
                      !m.isVirtual &&
                      m.isClaimed &&
                      m.userId.isNotEmpty &&
                      !m.userId.startsWith('unclaimed_') &&
                      m.displayName.trim().toLowerCase() == otherName)
                  .toList();
              if (candidates.length == 1) {
                matchedByName = candidates.first;
              }
            }
          }
        }

        final matched = matchedByToken ?? matchedByUserId ?? matchedByName;

        // If identity cannot be established, preserve original IDs
        // and track unresolved virtual candidates for auditability.
        if (matched == null) {
          final otherName = otherMember.displayName.trim().toLowerCase();
          final matchingLocalCandidates = mergedMembersMap.values
              .where((m) =>
                  !m.isMerged &&
                  (m.isVirtual || otherMember.isVirtual) &&
                  m.displayName.trim().toLowerCase() == otherName)
              .toList();

          if (matchingLocalCandidates.isNotEmpty) {
            for (final cand in matchingLocalCandidates) {
              unresolvedMemberIds.add(cand.id);
            }
            unresolvedMemberIds.add(otherMember.id);
          }
        }

        if (matched != null) {
          final bool isNowClaimed = otherMember.isClaimed || matched.isClaimed;

          // Determine canonical ID: Always preserve the real claimed member ID over a temporary virtual ID
          final String canonicalId;
          final String supersededId;
          if (matched.isClaimed && !otherMember.isClaimed) {
            canonicalId = matched.id;
            supersededId = otherMember.id;
          } else {
            canonicalId = otherMember.id;
            supersededId = matched.id;
          }

          if (supersededId != canonicalId) {
            memberIdMap[supersededId] = canonicalId;
          }
          mergedMembersMap.remove(matched.id);

          final chosenDisplayName =
              (otherMember.displayName.isNotEmpty &&
                  otherMember.displayName != 'Member')
              ? otherMember.displayName
              : matched.displayName;

          final String chosenUserId;
          if (!matched.userId.startsWith('unclaimed_') && matched.userId.isNotEmpty) {
            chosenUserId = matched.userId;
          } else if (!otherMember.userId.startsWith('unclaimed_') && otherMember.userId.isNotEmpty) {
            chosenUserId = otherMember.userId;
          } else {
            chosenUserId = matched.userId.isNotEmpty ? matched.userId : otherMember.userId;
          }

          mergedMembersMap[canonicalId] = (canonicalId == otherMember.id ? otherMember : matched).copyWith(
            id: canonicalId,
            displayName: chosenDisplayName,
            userId: chosenUserId,
            avatarUrl: otherMember.avatarUrl ?? matched.avatarUrl,
            role: otherMember.role != 'member' && otherMember.role != 'virtual' ? otherMember.role : matched.role,
            upiId: otherMember.upiId ?? matched.upiId,
            isClaimed: isNowClaimed,
            status: isNowClaimed ? 'claimed' : (otherMember.status ?? matched.status),
            claimToken: otherMember.claimToken ?? matched.claimToken,
            mergedIntoMemberId:
                otherMember.mergedIntoMemberId ?? matched.mergedIntoMemberId,
            isVirtualMember: !isNowClaimed,
          );

          // Deduplicate any remaining unclaimed duplicate members sharing this name,
          // unless they have a distinct claimToken matching another server member.
          if (otherMember.isVirtual && !otherMember.isClaimed) {
            final otherName = otherMember.displayName.trim().toLowerCase();
            final remainingDups = mergedMembersMap.values
                .where((m) =>
                    m.id != otherMember.id &&
                    !m.isMerged &&
                    m.isVirtual &&
                    !m.isClaimed &&
                    m.userId.startsWith('unclaimed_') &&
                    m.displayName.trim().toLowerCase() == otherName &&
                    !other.members.any((sm) =>
                        sm.id != otherMember.id &&
                        sm.claimToken != null &&
                        sm.claimToken!.isNotEmpty &&
                        sm.claimToken == m.claimToken))
                .toList();
            for (final dup in remainingDups) {
              memberIdMap[dup.id] = otherMember.id;
              mergedMembersMap.remove(dup.id);
            }
          }
        } else {
          // Genuinely distinct member from other device/server - preserve intact
          mergedMembersMap[otherMember.id] = otherMember;
        }
      }
    }

    // 3. Final safety: preserve all distinct members without dropping duplicate names.
    // Every member in mergedMembersMap has a unique ID and is preserved.

    final isOtherNewer =
        other.revision > revision || other.updatedAt.isAfter(updatedAt);

    final String? mergedSecret;
    if (other.revision > revision &&
        other.p2pTripSecret != null &&
        other.p2pTripSecret!.isNotEmpty) {
      mergedSecret = other.p2pTripSecret;
    } else if (p2pTripSecret != null && p2pTripSecret!.isNotEmpty) {
      mergedSecret = p2pTripSecret;
    } else {
      mergedSecret = other.p2pTripSecret;
    }

    final mergedTrip = Trip(
      id: id,
      name: isOtherNewer && other.name.isNotEmpty ? other.name : name,
      description: isOtherNewer
          ? (other.description ?? description)
          : (description ?? other.description),
      emoji: isOtherNewer ? other.emoji : emoji,
      coverGradientIndex: isOtherNewer
          ? other.coverGradientIndex
          : coverGradientIndex,
      currencyCode: other.currencyCode.isNotEmpty
          ? other.currencyCode
          : currencyCode,
      creatorId: creatorId.isNotEmpty ? creatorId : other.creatorId,
      members: mergedMembersMap.values.toList(),
      lifecycleState: () {
        // Authoritative higher revision always dictates lifecycle state
        if (other.revision > revision) return other.lifecycleState;
        if (revision > other.revision) return lifecycleState;
        // If revisions match, prefer the newer state unless a non-creator set it to completed/settled without authorization
        final candidate = isOtherNewer ? other.lifecycleState : lifecycleState;
        final candidateCompletedBy = isOtherNewer ? other.completedBy : completedBy;
        if ((candidate == TripLifecycle.completed || candidate == TripLifecycle.settled) &&
            candidateCompletedBy != null &&
            creatorId.isNotEmpty &&
            candidateCompletedBy != creatorId) {
          return TripLifecycle.active;
        }
        return candidate;
      }(),
      inviteCode: inviteCode.isNotEmpty ? inviteCode : other.inviteCode,
      p2pTripSecret: mergedSecret,
      tripMode: isOtherNewer ? other.tripMode : tripMode,
      revision: other.revision > revision ? other.revision : revision,
      completionMode: other.completionMode ?? completionMode,
      startedAt: startedAt.isBefore(other.startedAt)
          ? startedAt
          : other.startedAt,
      completedAt: other.completedAt ?? completedAt,
      completedBy: other.completedBy ?? completedBy,
      createdAt: createdAt.isBefore(other.createdAt)
          ? createdAt
          : other.createdAt,
      updatedAt: isOtherNewer ? other.updatedAt : updatedAt,
    );

    return TripMergeResult(
      mergedTrip: mergedTrip,
      memberIdMap: memberIdMap,
      unresolvedMemberIds: unresolvedMemberIds.toList(),
    );
  }

  /// Self-heals duplicate unclaimed virtual members who share the exact same display name
  /// within this single trip (e.g. from prior race conditions, outbox replay, or client/server mismatches).
  TripMergeResult deduplicateMembers() {
    final Map<String, TripMember> uniqueMap = {};
    final Map<String, String> translationMap = {};
    final Map<String, List<TripMember>> nameGroups = {};

    for (final m in members) {
      final key = m.displayName.trim().toLowerCase();
      nameGroups.putIfAbsent(key, () => []).add(m);
    }

    bool changed = false;
    for (final entry in nameGroups.entries) {
      final group = entry.value;
      if (group.length == 1) {
        uniqueMap[group.first.id] = group.first;
      } else {
        // Check if all duplicates are unclaimed virtual members
        final claimedOrAuth = group.where((m) => m.isClaimed || !m.userId.startsWith('unclaimed_')).toList();
        final unclaimedVirtual = group.where((m) => !m.isClaimed && m.userId.startsWith('unclaimed_')).toList();

        if (unclaimedVirtual.length > 1 && claimedOrAuth.isEmpty) {
          // Sort to pick canonical member:
          // Prefer member with valid claimToken, then UTC formatted server timestamp
          unclaimedVirtual.sort((a, b) {
            final aHasToken = (a.claimToken != null && a.claimToken!.isNotEmpty) ? 1 : 0;
            final bHasToken = (b.claimToken != null && b.claimToken!.isNotEmpty) ? 1 : 0;
            if (aHasToken != bHasToken) return bHasToken.compareTo(aHasToken);
            return a.joinedAt.compareTo(b.joinedAt);
          });
          final canonical = unclaimedVirtual.first;
          uniqueMap[canonical.id] = canonical;
          for (int i = 1; i < unclaimedVirtual.length; i++) {
            final dup = unclaimedVirtual[i];
            translationMap[dup.id] = canonical.id;
            changed = true;
          }
        } else if (claimedOrAuth.length == 1 && unclaimedVirtual.isNotEmpty) {
          // Exactly one real claimed user and one or more unclaimed virtual placeholders with the same display name.
          // The real claimed member is canonical. All unclaimed virtual placeholders are merged into it.
          final canonical = claimedOrAuth.first;
          uniqueMap[canonical.id] = canonical;
          for (final dup in unclaimedVirtual) {
            translationMap[dup.id] = canonical.id;
            changed = true;
          }
        } else {
          // If there's a mix of multiple distinct real users with different userIds, preserve them
          for (final m in group) {
            uniqueMap[m.id] = m;
          }
        }
      }
    }

    if (!changed) {
      return TripMergeResult(mergedTrip: this, memberIdMap: {});
    }

    final newTrip = copyWith(members: uniqueMap.values.toList());
    return TripMergeResult(mergedTrip: newTrip, memberIdMap: translationMap);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'emoji': emoji,
    'coverGradientIndex': coverGradientIndex,
    'currencyCode': currencyCode,
    'creatorId': creatorId,
    'members': members.map((m) => m.toJson()).toList(),
    'lifecycleState': lifecycleState.name,
    'inviteCode': inviteCode,
    'p2pTripSecret': p2pTripSecret,
    'tripMode': tripMode,
    'revision': revision,
    'completionMode': completionMode,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final parsedCreatedAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String) ??
                    DateTime.now()
              : DateTime.now());
    final parsedStartedAt = json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'] as String) ?? parsedCreatedAt
        : (json['started_at'] != null
              ? DateTime.tryParse(json['started_at'] as String) ??
                    parsedCreatedAt
              : parsedCreatedAt);

    final rawLifecycle =
        json['lifecycleState'] as String? ??
        json['lifecycle_state'] as String? ??
        json['status'] as String? ??
        'active';

    final rawCompletedAt = json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : (json['completed_at'] != null
              ? DateTime.tryParse(json['completed_at'] as String)
              : null);

    final rawCompletedBy =
        json['completedBy'] as String? ?? json['completed_by'] as String?;

    return Trip(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Trip',
      description: json['description'] as String?,
      emoji: json['emoji'] as String? ?? '✈️',
      coverGradientIndex:
          json['coverGradientIndex'] as int? ??
          json['cover_gradient_index'] as int? ??
          0,
      currencyCode:
          json['currencyCode'] as String? ??
          json['currency_code'] as String? ??
          'INR',
      creatorId:
          (json['creatorId'] as String?) ??
          (json['creator_id'] as String?) ??
          '',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lifecycleState: TripLifecycle.fromString(rawLifecycle),
      inviteCode:
          json['inviteCode'] as String? ??
          json['invite_code'] as String? ??
          'KITH00',
      p2pTripSecret:
          json['p2pTripSecret'] as String? ??
          json['p2p_trip_secret'] as String?,
      tripMode:
          json['tripMode'] as String? ??
          json['trip_mode'] as String? ??
          'split_only',
      revision: json['revision'] as int? ?? 1,
      completionMode:
          json['completionMode'] as String? ??
          json['completion_mode'] as String?,
      startedAt: parsedStartedAt,
      completedAt: rawCompletedAt,
      completedBy: rawCompletedBy,
      createdAt: parsedCreatedAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? parsedCreatedAt
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'] as String) ??
                      parsedCreatedAt
                : parsedCreatedAt),
    );
  }
}
