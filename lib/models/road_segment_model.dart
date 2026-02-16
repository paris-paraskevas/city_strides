// Represents a single road segment inside a city.
//
// A road segment is a section of road between two intersections,
// fetched from OpenStreetMap via the Overpass API.
// The polyline is the list of coordinates that traces the road's path.

import 'package:latlong2/latlong.dart';

class RoadSegmentModel {
  // --- Fields ---
  final String segmentId;       // OpenStreetMap way ID
  final String cityId;           // Which city this road belongs to
  final String name;            // Street name (empty for unnamed roads)
  final List<LatLng> polyline;  // The points that draw this road on a map.
  final double lengthMeters;

  // --- Constructor ---
  // segmentId and cityId are required - a road must have an identity
  // and belong to a city.
  // name defaults to empty string because some roads in OSM are unnamed.
  RoadSegmentModel({
    required this.segmentId,
    required this.cityId,
    this.name = '',
    this.polyline = const[],
    this.lengthMeters = 0.0,
  });

  // --- fromJson ---
  factory RoadSegmentModel.fromJson(Map<String, dynamic> json) {
    return RoadSegmentModel(
      segmentId: json['segmentId'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      polyline: json['polyline'] != null
          ? (json['polyline'] as List)
              .map((point) => LatLng(
                    (point['lat'] as num).toDouble(),
                    (point['lng'] as num).toDouble(),
                  ))
              .toList()
          : [],
      lengthMeters:
          (json['lengthMeters'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // --- toJson ---
  Map<String, dynamic> toJson() {
    return{
      'segmentId': segmentId,
      'cityId': cityId,
      'name': name,
      'polyline': polyline
        .map((point) => {
              'lat': point.latitude,
              'lng': point.longitude,
        })
        .toList(),
      'lengthMeters': lengthMeters
    };
  }

  // --- copyWith ---
  RoadSegmentModel copyWith({
    String? segmentId,
    String? cityId,
    String? name,
    List<LatLng>? polyline,
    double? lengthMeters,
  }) {
    return RoadSegmentModel(
      segmentId: segmentId ?? this.segmentId,
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      polyline: polyline ?? this.polyline,
      lengthMeters: lengthMeters ?? this.lengthMeters,
    );
  }
}