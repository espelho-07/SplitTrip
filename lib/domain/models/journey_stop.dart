/// Represents an itinerary stop / waypoint along a trip journey.
class JourneyStop {
  final String id;
  final String tripId;
  final int dayNumber;
  final String time;
  final String locationName;
  final String? notes;
  final String? expenseId;
  final DateTime createdAt;

  const JourneyStop({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.time,
    required this.locationName,
    this.notes,
    this.expenseId,
    required this.createdAt,
  });

  JourneyStop copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    String? time,
    String? locationName,
    String? notes,
    String? expenseId,
    DateTime? createdAt,
  }) {
    return JourneyStop(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      time: time ?? this.time,
      locationName: locationName ?? this.locationName,
      notes: notes ?? this.notes,
      expenseId: expenseId ?? this.expenseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'dayNumber': dayNumber,
    'time': time,
    'locationName': locationName,
    'notes': notes,
    'expenseId': expenseId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory JourneyStop.fromJson(Map<String, dynamic> json) => JourneyStop(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    dayNumber: json['dayNumber'] as int? ?? 1,
    time: json['time'] as String? ?? '12:00 PM',
    locationName: json['locationName'] as String? ?? 'Place',
    notes: json['notes'] as String?,
    expenseId: json['expenseId'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}
