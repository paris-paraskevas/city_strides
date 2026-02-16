// Represents a user's walking progress within a specific city
//
// This is the model that drives the completion percentage
// shown on the map and stats screens. It gets recalculated
// each time new walked segments are recorded.

class CityProgressModel {
  // --- Fields ---
  final String userId;                // Which user
  final String cityId;                // Which city
  final int segmentsWalked;           // How many road segments they've walked
  final int totalSegments;            // How many road segments in the city
  final double distanceWalkedMeters;  // Total distance walked in the city
  final double completionPercent;     // segmentsWalked/totalSegments * 100
  final DateTime lastUpdated;         // When progress was last recalculated

  // --- Constructor ---
  // userId, cityId, and lastUpdated are required.
  // Numeric fields default to 0 - progress starts from nothing
  CityProgressModel({
    required this.userId,
    required this.cityId,
    required this.lastUpdated,
    this.segmentsWalked = 0,
    this.totalSegments = 0,
    this.distanceWalkedMeters = 0.0,
    this.completionPercent = 0.0,
  });

  // --- fromJson ---
  factory CityProgressModel.fromJson(Map<String, dynamic> json) {
    return CityProgressModel(
        userId: json['userId'] as String? ?? '',
        cityId: json['cityId'] as String? ?? '',
        segmentsWalked: json['segmentsWalked'] as int? ?? 0,
        totalSegments: json['totalSegments'] as int? ?? 0,
        distanceWalkedMeters:
            (json['distanceWalkedMeters'] as num?)?.toDouble() ?? 0.0,
        completionPercent:
            (json['completionPercent'] as num?)?.toDouble() ?? 0.0,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : DateTime.now(),
    );
  }

  // --- toJson ---
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'cityId': cityId,
      'segmentsWalked': segmentsWalked,
      'totalSegments': totalSegments,
      'distanceWalkedMeters': distanceWalkedMeters,
      'completionPercent': completionPercent,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // --- copyWith ---
  CityProgressModel copyWith({
    String? userId,
    String? cityId,
    int? segmentsWalked,
    int? totalSegments,
    double? distanceWalkedMeters,
    double? completionPercent,
    DateTime? lastUpdated,
  }) {
    return CityProgressModel(
      userId: userId ?? this.userId,
      cityId: cityId ?? this.cityId,
      segmentsWalked: segmentsWalked ?? this.segmentsWalked,
      totalSegments: totalSegments ?? this.totalSegments,
      distanceWalkedMeters: distanceWalkedMeters ?? this.distanceWalkedMeters,
      completionPercent: completionPercent ?? this.completionPercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}