import 'package:flutter/foundation.dart';

enum MemberPresenceStatus {
  online,
  recentlyActive,
  offline,
  unknown,
  virtualAccounted;

  static MemberPresenceStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'ONLINE':
        return MemberPresenceStatus.online;
      case 'RECENTLY_ACTIVE':
        return MemberPresenceStatus.recentlyActive;
      case 'OFFLINE':
        return MemberPresenceStatus.offline;
      case 'VIRTUAL_ACCOUNTED':
        return MemberPresenceStatus.virtualAccounted;
      default:
        return MemberPresenceStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case MemberPresenceStatus.online:
        return 'Online';
      case MemberPresenceStatus.recentlyActive:
        return 'Recently Active';
      case MemberPresenceStatus.offline:
        return 'Offline';
      case MemberPresenceStatus.virtualAccounted:
        return 'Managed by you';
      case MemberPresenceStatus.unknown:
        return 'Unknown';
    }
  }
}

enum MemberConsentStatus {
  none,
  pending,
  confirmedAvailable,
  unavailable,
  expired,
  cancelled;

  static MemberConsentStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PENDING':
        return MemberConsentStatus.pending;
      case 'CONFIRMED_AVAILABLE':
        return MemberConsentStatus.confirmedAvailable;
      case 'UNAVAILABLE':
        return MemberConsentStatus.unavailable;
      case 'EXPIRED':
        return MemberConsentStatus.expired;
      case 'CANCELLED':
        return MemberConsentStatus.cancelled;
      default:
        return MemberConsentStatus.none;
    }
  }

  String get displayName {
    switch (this) {
      case MemberConsentStatus.pending:
        return 'Confirmation Requested';
      case MemberConsentStatus.confirmedAvailable:
        return 'Confirmed Available';
      case MemberConsentStatus.unavailable:
        return 'Unavailable';
      case MemberConsentStatus.expired:
        return 'Request Expired';
      case MemberConsentStatus.cancelled:
        return 'Cancelled';
      case MemberConsentStatus.none:
        return 'None';
    }
  }
}

@immutable
class TripCompletionRequest {
  final String id;
  final String tripId;
  final String memberId;
  final String? userId;
  final String requestedBy;
  final MemberConsentStatus status;
  final String? response;
  final String? responseNote;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final int version;

  const TripCompletionRequest({
    required this.id,
    required this.tripId,
    required this.memberId,
    this.userId,
    required this.requestedBy,
    required this.status,
    this.response,
    this.responseNote,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
    this.version = 1,
  });

  bool get isPending => status == MemberConsentStatus.pending;
  bool get isConfirmed => status == MemberConsentStatus.confirmedAvailable;
  bool get isUnavailable => status == MemberConsentStatus.unavailable;
  bool get isExpired => status == MemberConsentStatus.expired || DateTime.now().isAfter(expiresAt);

  factory TripCompletionRequest.fromJson(Map<String, dynamic> json) => TripCompletionRequest(
        id: json['id'] as String? ?? '',
        tripId: json['tripId'] as String? ?? json['trip_id'] as String? ?? '',
        memberId: json['memberId'] as String? ?? json['member_id'] as String? ?? '',
        userId: json['userId'] as String? ?? json['user_id'] as String?,
        requestedBy: json['requestedBy'] as String? ?? json['requested_by'] as String? ?? '',
        status: MemberConsentStatus.fromString(json['status'] as String?),
        response: json['response'] as String?,
        responseNote: json['responseNote'] as String? ?? json['response_note'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? json['expires_at'] as String? ?? '') ??
            DateTime.now().add(const Duration(hours: 24)),
        respondedAt: json['respondedAt'] != null
            ? DateTime.tryParse(json['respondedAt'] as String)
            : (json['responded_at'] != null ? DateTime.tryParse(json['responded_at'] as String) : null),
        version: json['version'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'memberId': memberId,
        'userId': userId,
        'requestedBy': requestedBy,
        'status': status.name,
        'response': response,
        'responseNote': responseNote,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
        'version': version,
      };
}

@immutable
class TripReopeningRequest {
  final String id;
  final String tripId;
  final String requestedBy;
  final String reasonCategory;
  final String? note;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;

  const TripReopeningRequest({
    required this.id,
    required this.tripId,
    required this.requestedBy,
    required this.reasonCategory,
    this.note,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory TripReopeningRequest.fromJson(Map<String, dynamic> json) => TripReopeningRequest(
        id: json['id'] as String? ?? '',
        tripId: json['tripId'] as String? ?? json['trip_id'] as String? ?? '',
        requestedBy: json['requestedBy'] as String? ?? json['requested_by'] as String? ?? '',
        reasonCategory: json['reasonCategory'] as String? ?? json['reason_category'] as String? ?? 'OTHER',
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        reviewedBy: json['reviewedBy'] as String? ?? json['reviewed_by'] as String?,
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.tryParse(json['reviewedAt'] as String)
            : (json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'] as String) : null),
        reviewNote: json['reviewNote'] as String? ?? json['review_note'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'requestedBy': requestedBy,
        'reasonCategory': reasonCategory,
        'note': note,
        'status': status,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewNote': reviewNote,
        'createdAt': createdAt.toIso8601String(),
      };
}

@immutable
class TripLifecycleHistoryEntry {
  final String id;
  final String tripId;
  final String previousStatus;
  final String newStatus;
  final String changedBy;
  final String? reason;
  final String? relatedRequestId;
  final DateTime createdAt;

  const TripLifecycleHistoryEntry({
    required this.id,
    required this.tripId,
    required this.previousStatus,
    required this.newStatus,
    required this.changedBy,
    this.reason,
    this.relatedRequestId,
    required this.createdAt,
  });

  factory TripLifecycleHistoryEntry.fromJson(Map<String, dynamic> json) => TripLifecycleHistoryEntry(
        id: json['id'] as String? ?? '',
        tripId: json['tripId'] as String? ?? json['trip_id'] as String? ?? '',
        previousStatus: json['previousStatus'] as String? ?? json['previous_status'] as String? ?? '',
        newStatus: json['newStatus'] as String? ?? json['new_status'] as String? ?? '',
        changedBy: json['changedBy'] as String? ?? json['changed_by'] as String? ?? '',
        reason: json['reason'] as String?,
        relatedRequestId: json['relatedRequestId'] as String? ?? json['related_request_id'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'previousStatus': previousStatus,
        'newStatus': newStatus,
        'changedBy': changedBy,
        'reason': reason,
        'relatedRequestId': relatedRequestId,
        'createdAt': createdAt.toIso8601String(),
      };
}

@immutable
class TripCompletionSummary {
  final int totalMembers;
  final int onlineCount;
  final int recentlyActiveCount;
  final int offlineCount;
  final int confirmedCount;
  final int unavailableCount;
  final int pendingConsentCount;
  final int virtualCount;

  const TripCompletionSummary({
    this.totalMembers = 0,
    this.onlineCount = 0,
    this.recentlyActiveCount = 0,
    this.offlineCount = 0,
    this.confirmedCount = 0,
    this.unavailableCount = 0,
    this.pendingConsentCount = 0,
    this.virtualCount = 0,
  });

  factory TripCompletionSummary.fromJson(Map<String, dynamic> json) => TripCompletionSummary(
        totalMembers: json['totalMembers'] as int? ?? 0,
        onlineCount: json['onlineCount'] as int? ?? 0,
        recentlyActiveCount: json['recentlyActiveCount'] as int? ?? 0,
        offlineCount: json['offlineCount'] as int? ?? 0,
        confirmedCount: json['confirmedCount'] as int? ?? 0,
        unavailableCount: json['unavailableCount'] as int? ?? 0,
        pendingConsentCount: json['pendingConsentCount'] as int? ?? 0,
        virtualCount: json['virtualCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'totalMembers': totalMembers,
        'onlineCount': onlineCount,
        'recentlyActiveCount': recentlyActiveCount,
        'offlineCount': offlineCount,
        'confirmedCount': confirmedCount,
        'unavailableCount': unavailableCount,
        'pendingConsentCount': pendingConsentCount,
        'virtualCount': virtualCount,
      };
}

@immutable
class TripCompletionDetail {
  final String tripId;
  final String tripName;
  final String lifecycleState;
  final int currentRevision;
  final bool isOwnerOnline;
  final bool canCompleteNormally;
  final bool isCompletionBlocked;
  final String? blockReason;
  final TripCompletionSummary summary;
  final List<dynamic> participants;
  final List<TripCompletionRequest> activeCompletionRequests;
  final List<TripReopeningRequest> pendingReopeningRequests;
  final List<TripLifecycleHistoryEntry> lifecycleHistory;

  const TripCompletionDetail({
    required this.tripId,
    required this.tripName,
    required this.lifecycleState,
    required this.currentRevision,
    this.isOwnerOnline = true,
    required this.canCompleteNormally,
    this.isCompletionBlocked = false,
    this.blockReason,
    required this.summary,
    required this.participants,
    this.activeCompletionRequests = const [],
    this.pendingReopeningRequests = const [],
    this.lifecycleHistory = const [],
  });

  factory TripCompletionDetail.fromJson(Map<String, dynamic> json) => TripCompletionDetail(
        tripId: json['tripId'] as String? ?? '',
        tripName: json['tripName'] as String? ?? '',
        lifecycleState: json['lifecycleState'] as String? ?? 'active',
        currentRevision: json['currentRevision'] as int? ?? 1,
        isOwnerOnline: json['isOwnerOnline'] as bool? ?? true,
        canCompleteNormally: json['canCompleteNormally'] as bool? ?? false,
        isCompletionBlocked: json['isCompletionBlocked'] as bool? ?? false,
        blockReason: json['blockReason'] as String?,
        summary: json['summary'] != null
            ? TripCompletionSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : const TripCompletionSummary(),
        participants: json['participants'] as List<dynamic>? ?? [],
        activeCompletionRequests: (json['activeCompletionRequests'] as List<dynamic>?)
                ?.map((e) => TripCompletionRequest.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingReopeningRequests: (json['pendingReopeningRequests'] as List<dynamic>?)
                ?.map((e) => TripReopeningRequest.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lifecycleHistory: (json['lifecycleHistory'] as List<dynamic>?)
                ?.map((e) => TripLifecycleHistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
