/// Participant synchronization status reported by the server.
enum ParticipantSyncState {
  synced,
  pending,
  offline,
  unknown;

  static ParticipantSyncState fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'synced':
        return ParticipantSyncState.synced;
      case 'pending':
        return ParticipantSyncState.pending;
      case 'offline':
        return ParticipantSyncState.offline;
      default:
        return ParticipantSyncState.unknown;
    }
  }
}

/// Detailed sync inspection metadata for a single trip participant.
class ParticipantSyncInfo {
  final String memberId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isCreator;
  final bool isCurrentUser;
  final bool isOnline;
  final ParticipantSyncState syncStatus;
  final int acknowledgedRevision;
  final int pendingCount;
  final DateTime? lastSeenAt;
  final String lastSyncFormatted;

  const ParticipantSyncInfo({
    required this.memberId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isCreator = false,
    this.isCurrentUser = false,
    this.isOnline = false,
    this.syncStatus = ParticipantSyncState.unknown,
    this.acknowledgedRevision = 1,
    this.pendingCount = 0,
    this.lastSeenAt,
    this.lastSyncFormatted = 'Unknown',
  });

  bool get isSynced => syncStatus == ParticipantSyncState.synced && pendingCount == 0;

  factory ParticipantSyncInfo.fromJson(Map<String, dynamic> json) => ParticipantSyncInfo(
    memberId: json['memberId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Member',
    avatarUrl: json['avatarUrl'] as String?,
    isCreator: json['isCreator'] as bool? ?? false,
    isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    isOnline: json['isOnline'] as bool? ?? false,
    syncStatus: ParticipantSyncState.fromString(json['syncStatus'] as String?),
    acknowledgedRevision: json['acknowledgedRevision'] as int? ?? 1,
    pendingCount: json['pendingCount'] as int? ?? 0,
    lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'] as String) : null,
    lastSyncFormatted: json['lastSyncFormatted'] as String? ?? 'Unknown',
  );

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'isCreator': isCreator,
    'isCurrentUser': isCurrentUser,
    'isOnline': isOnline,
    'syncStatus': syncStatus.name,
    'acknowledgedRevision': acknowledgedRevision,
    'pendingCount': pendingCount,
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'lastSyncFormatted': lastSyncFormatted,
  };
}

/// Authoritative multi-participant synchronization state for an entire Trip.
class TripSyncStatus {
  final String tripId;
  final String tripName;
  final int currentRevision;
  final String lifecycleState;
  final String? completionMode;
  final DateTime? completedAt;
  final String? completedBy;
  final bool isFullySynced;
  final bool canCompleteNormally;
  final int totalParticipants;
  final int syncedParticipantsCount;
  final int unsyncedParticipantsCount;
  final List<ParticipantSyncInfo> participants;

  const TripSyncStatus({
    required this.tripId,
    required this.tripName,
    required this.currentRevision,
    required this.lifecycleState,
    this.completionMode,
    this.completedAt,
    this.completedBy,
    required this.isFullySynced,
    required this.canCompleteNormally,
    required this.totalParticipants,
    required this.syncedParticipantsCount,
    required this.unsyncedParticipantsCount,
    required this.participants,
  });

  factory TripSyncStatus.fromJson(Map<String, dynamic> json) => TripSyncStatus(
    tripId: json['tripId'] as String? ?? '',
    tripName: json['tripName'] as String? ?? '',
    currentRevision: json['currentRevision'] as int? ?? 1,
    lifecycleState: json['lifecycleState'] as String? ?? 'active',
    completionMode: json['completionMode'] as String?,
    completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
    completedBy: json['completedBy'] as String?,
    isFullySynced: json['isFullySynced'] as bool? ?? false,
    canCompleteNormally: json['canCompleteNormally'] as bool? ?? false,
    totalParticipants: json['totalParticipants'] as int? ?? 0,
    syncedParticipantsCount: json['syncedParticipantsCount'] as int? ?? 0,
    unsyncedParticipantsCount: json['unsyncedParticipantsCount'] as int? ?? 0,
    participants: (json['participants'] as List<dynamic>?)
            ?.map((e) => ParticipantSyncInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'tripName': tripName,
    'currentRevision': currentRevision,
    'lifecycleState': lifecycleState,
    'completionMode': completionMode,
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
    'isFullySynced': isFullySynced,
    'canCompleteNormally': canCompleteNormally,
    'totalParticipants': totalParticipants,
    'syncedParticipantsCount': syncedParticipantsCount,
    'unsyncedParticipantsCount': unsyncedCount,
    'participants': participants.map((p) => p.toJson()).toList(),
  };

  int get unsyncedCount => unsyncedParticipantsCount;
}
