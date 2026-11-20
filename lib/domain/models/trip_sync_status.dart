import 'trip.dart';

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
  final bool isVirtual;
  final bool isOnline;
  final ParticipantSyncState syncStatus;
  final int acknowledgedRevision;
  final int pendingCount;
  final DateTime? lastSeenAt;
  final DateTime? lastHeartbeatAt;
  final String lastSyncFormatted;
  final String presenceStatus; // 'ONLINE', 'RECENTLY_ACTIVE', 'OFFLINE', 'UNKNOWN', 'VIRTUAL_ACCOUNTED'
  final String consentStatus;  // 'NONE', 'PENDING', 'CONFIRMED_AVAILABLE', 'UNAVAILABLE', 'EXPIRED'
  final String? activeRequestId;
  final String? consentResponseNote;

  const ParticipantSyncInfo({
    required this.memberId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isCreator = false,
    this.isCurrentUser = false,
    this.isVirtual = false,
    this.isOnline = false,
    this.syncStatus = ParticipantSyncState.unknown,
    this.acknowledgedRevision = 1,
    this.pendingCount = 0,
    this.lastSeenAt,
    this.lastHeartbeatAt,
    this.lastSyncFormatted = 'Unknown',
    this.presenceStatus = 'UNKNOWN',
    this.consentStatus = 'NONE',
    this.activeRequestId,
    this.consentResponseNote,
  });

  bool get isSynced => isVirtual || (syncStatus == ParticipantSyncState.synced && pendingCount == 0);
  bool get isConsentConfirmed => consentStatus == 'CONFIRMED_AVAILABLE';
  bool get isConsentRejected => consentStatus == 'UNAVAILABLE';
  bool get isConsentPending => consentStatus == 'PENDING';

  factory ParticipantSyncInfo.fromJson(Map<String, dynamic> json) => ParticipantSyncInfo(
    memberId: json['memberId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Member',
    avatarUrl: json['avatarUrl'] as String?,
    isCreator: json['isCreator'] as bool? ?? false,
    isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    isVirtual: (json['isVirtual'] == true) ||
        (json['userId'] as String? ?? '').startsWith('unclaimed_') ||
        (json['lastSyncFormatted'] as String? ?? '').toLowerCase().contains('virtual'),
    isOnline: json['isOnline'] as bool? ?? false,
    syncStatus: ParticipantSyncState.fromString(json['syncStatus'] as String?),
    acknowledgedRevision: json['acknowledgedRevision'] as int? ?? 1,
    pendingCount: json['pendingCount'] as int? ?? 0,
    lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'] as String) : null,
    lastHeartbeatAt: json['lastHeartbeatAt'] != null ? DateTime.tryParse(json['lastHeartbeatAt'] as String) : null,
    lastSyncFormatted: json['lastSyncFormatted'] as String? ?? 'Unknown',
    presenceStatus: json['presenceStatus'] as String? ?? (json['isOnline'] == true ? 'ONLINE' : 'UNKNOWN'),
    consentStatus: json['consentStatus'] as String? ?? 'NONE',
    activeRequestId: json['activeRequestId'] as String?,
    consentResponseNote: json['consentResponseNote'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'isCreator': isCreator,
    'isCurrentUser': isCurrentUser,
    'isVirtual': isVirtual,
    'isOnline': isOnline,
    'syncStatus': syncStatus.name,
    'acknowledgedRevision': acknowledgedRevision,
    'pendingCount': pendingCount,
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'lastHeartbeatAt': lastHeartbeatAt?.toIso8601String(),
    'lastSyncFormatted': lastSyncFormatted,
    'presenceStatus': presenceStatus,
    'consentStatus': consentStatus,
    'activeRequestId': activeRequestId,
    'consentResponseNote': consentResponseNote,
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
  final bool isCompletionBlocked;
  final String? blockReason;
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
    this.isCompletionBlocked = false,
    this.blockReason,
    required this.totalParticipants,
    required this.syncedParticipantsCount,
    required this.unsyncedParticipantsCount,
    required this.participants,
  });

    factory TripSyncStatus.fromLocalTrip(Trip trip, {String currentUserId = ''}) {
    final participants = trip.members.map((m) => ParticipantSyncInfo(
      memberId: m.id,
      userId: m.userId,
      displayName: m.displayName,
      avatarUrl: m.avatarUrl,
      isCreator: m.isCreator,
      isCurrentUser: m.userId == currentUserId,
      isVirtual: m.isVirtual,
      isOnline: true,
      syncStatus: ParticipantSyncState.synced,
      acknowledgedRevision: trip.revision,
      pendingCount: 0,
      lastSeenAt: m.lastSeenAt ?? DateTime.now(),
      lastSyncFormatted: m.isVirtual ? 'Virtual member' : 'Local',
    )).toList();

    return TripSyncStatus(
      tripId: trip.id,
      tripName: trip.name,
      currentRevision: trip.revision,
      lifecycleState: trip.lifecycleState.name,
      isFullySynced: true,
      canCompleteNormally: true,
      totalParticipants: participants.length,
      syncedParticipantsCount: participants.length,
      unsyncedParticipantsCount: 0,
      participants: participants,
    );
  }

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
    isCompletionBlocked: json['isCompletionBlocked'] as bool? ?? false,
    blockReason: json['blockReason'] as String?,
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
    'isCompletionBlocked': isCompletionBlocked,
    'blockReason': blockReason,
    'totalParticipants': totalParticipants,
    'syncedParticipantsCount': syncedParticipantsCount,
    'unsyncedParticipantsCount': unsyncedCount,
    'participants': participants.map((p) => p.toJson()).toList(),
  };

  int get unsyncedCount => unsyncedParticipantsCount;
}
