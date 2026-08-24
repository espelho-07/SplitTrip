/// Represents a single chronological audit event in a trip.
class ActivityLog {
  final String id;
  final String tripId;
  final String type;
  final String actorId;
  final String actorName;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ActivityLog({
    required this.id,
    required this.tripId,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'] as String? ?? '',
        tripId: json['tripId'] as String? ?? '',
        type: json['type'] as String? ?? 'general',
        actorId: json['actorId'] as String? ?? '',
        actorName: json['actorName'] as String? ?? 'Member',
        description: json['description'] as String? ?? '',
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'type': type,
        'actorId': actorId,
        'actorName': actorName,
        'description': description,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
      };
}
