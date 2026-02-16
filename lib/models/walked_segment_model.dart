// Represents a single "walk event" - the record that a user walked a specific
// road segment at a specific time
//
// This is the core tracking data. Every time the app tracks that you have
// walked a road segment, one of these gets created.

class WalkedSegmentModel {
  // --- Fields ---
  final String userId;      // Who walked it
  final String segmentId;   // Which road segment was walked
  final String cityId;      // Which city the segment belongs to
  final DateTime walkedAt;  // When it was walked

  // --- Constructor ---
  // All fields are required - a walk event is meaningless without
  // knowing who, what, where and when.
  WalkedSegmentModel({
    required this.userId,
    required this.segmentId,
    required this.cityId,
    required this.walkedAt,
  });

  // --- fromJson ---
  factory WalkedSegmentModel.fromJson(Map<String, dynamic> json) {
    return WalkedSegmentModel(
      userId: json['userId'] as String? ?? '',
      segmentId: json['segmentId'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      walkedAt: json['walkedAt'] != null
          ? DateTime.parse(json['walkedAt'] as String)
          : DateTime.now(),
    );
  }

  // --- toJson ---
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'segmentId': segmentId,
      'cityId': cityId,
      'walkedAt': walkedAt.toIso8601String(),
    };
  }

  // --- copyWith ---
  WalkedSegmentModel copyWith({
    String? userId,
    String? segmentId,
    String? cityId,
    DateTime? walkedAt,
  }) {
    return WalkedSegmentModel(
        userId: userId ?? this.userId,
        segmentId: segmentId ?? this.segmentId,
        cityId: cityId ?? this.cityId,
        walkedAt: walkedAt ?? this.walkedAt
    );
  }
}