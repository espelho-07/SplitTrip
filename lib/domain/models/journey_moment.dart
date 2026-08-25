import 'package:flutter/foundation.dart';

@immutable
class JourneyMoment {
  final String id;
  final String tripId;
  final String createdBy;
  final String? creatorName;
  final String title;
  final String? placeName;
  final String? note;
  final double? latitude;
  final double? longitude;
  final DateTime occurredAt;
  final int dayIndex;
  final List<String> photoUrls;
  final String? expenseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JourneyMoment({
    required this.id,
    required this.tripId,
    required this.createdBy,
    this.creatorName,
    required this.title,
    this.placeName,
    this.note,
    this.latitude,
    this.longitude,
    required this.occurredAt,
    this.dayIndex = 1,
    this.photoUrls = const [],
    this.expenseId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'title': title,
      'placeName': placeName,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'occurredAt': occurredAt.toIso8601String(),
      'dayIndex': dayIndex,
      'photoUrls': photoUrls,
      'expenseId': expenseId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JourneyMoment.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photoUrls'] ?? json['photo_urls'];
    final rawOccurred = json['occurredAt'] ?? json['occurred_at'];
    final rawCreated = json['createdAt'] ?? json['created_at'];
    final rawUpdated = json['updatedAt'] ?? json['updated_at'];

    return JourneyMoment(
      id: json['id'] as String,
      tripId: (json['tripId'] ?? json['trip_id']) as String,
      createdBy: (json['createdBy'] ?? json['created_by']) as String? ?? 'unknown',
      creatorName: (json['creatorName'] ?? json['creator_name']) as String?,
      title: json['title'] as String,
      placeName: (json['placeName'] ?? json['place_name']) as String?,
      note: json['note'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      occurredAt: rawOccurred != null
          ? DateTime.tryParse(rawOccurred.toString()) ?? DateTime.now()
          : DateTime.now(),
      dayIndex: (json['dayIndex'] ?? json['day_index']) as int? ?? 1,
      photoUrls: rawPhotos != null
          ? List<String>.from(rawPhotos as List)
          : const [],
      expenseId: (json['expenseId'] ?? json['expense_id']) as String?,
      createdAt: rawCreated != null
          ? DateTime.tryParse(rawCreated.toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: rawUpdated != null
          ? DateTime.tryParse(rawUpdated.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  JourneyMoment copyWith({
    String? id,
    String? tripId,
    String? createdBy,
    String? creatorName,
    String? title,
    String? placeName,
    String? note,
    double? latitude,
    double? longitude,
    DateTime? occurredAt,
    int? dayIndex,
    List<String>? photoUrls,
    String? expenseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JourneyMoment(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      placeName: placeName ?? this.placeName,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      occurredAt: occurredAt ?? this.occurredAt,
      dayIndex: dayIndex ?? this.dayIndex,
      photoUrls: photoUrls ?? this.photoUrls,
      expenseId: expenseId ?? this.expenseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyMoment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tripId == other.tripId &&
          title == other.title &&
          dayIndex == other.dayIndex &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ tripId.hashCode ^ title.hashCode ^ dayIndex.hashCode ^ updatedAt.hashCode;
}
