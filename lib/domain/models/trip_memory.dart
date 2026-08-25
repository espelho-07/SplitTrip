/// Represents a personal memory, reflection or photo highlight from a trip.
class TripMemory {
  final String id;
  final String tripId;
  final String title;
  final String? note;
  final String emoji;
  final int dayNumber;
  final String? photoUrl;
  final String? expenseId;
  final DateTime createdAt;

  const TripMemory({
    required this.id,
    required this.tripId,
    required this.title,
    this.note,
    this.emoji = '✨',
    this.dayNumber = 1,
    this.photoUrl,
    this.expenseId,
    required this.createdAt,
  });

  TripMemory copyWith({
    String? id,
    String? tripId,
    String? title,
    String? note,
    String? emoji,
    int? dayNumber,
    String? photoUrl,
    String? expenseId,
    DateTime? createdAt,
  }) {
    return TripMemory(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      note: note ?? this.note,
      emoji: emoji ?? this.emoji,
      dayNumber: dayNumber ?? this.dayNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      expenseId: expenseId ?? this.expenseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'note': note,
    'emoji': emoji,
    'dayNumber': dayNumber,
    'photoUrl': photoUrl,
    'expenseId': expenseId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TripMemory.fromJson(Map<String, dynamic> json) => TripMemory(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    title: json['title'] as String? ?? 'Memory',
    note: json['note'] as String?,
    emoji: json['emoji'] as String? ?? '✨',
    dayNumber: json['dayNumber'] as int? ?? 1,
    photoUrl: json['photoUrl'] as String?,
    expenseId: json['expenseId'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}
