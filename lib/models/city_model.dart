// Represents a city that can be explored in City Strides
//
// The boundaryPolygon defines the city's geographic borders,
// fetched from OpenStreetMap admin boundaries.

import 'package:latlong2/latlong.dart';

class CityModel {
  // --- Fields ---
  final String cityId;                  // Unique ID like "athens_gr"
  final String name;                    // Display name like "Athens"
  final String country;                 // Country name like "Greece"
  final List<LatLng> boundaryPolygon;   // City border as a list of coordinates
  final int totalRoadSegments;          // Road segments in this city
  final double totalRoadLengthMeters;   // Total length of all roads in meters

  // --- Constructor ---
  // cityId, name, and country are required because a city must have an identity.
  // boundaryPolygon defaults to an empty list - and gets populated when we fetch
  // data from the Overpass API.
  // Road counts default to 0 - they're calculated after fetching road data.
  CityModel({
    required this.cityId,
    required this.name,
    required this.country,
    this.boundaryPolygon = const[],
    this.totalRoadSegments = 0,
    this.totalRoadLengthMeters = 0.0,
  });

  // --- fromJson ---
  // Converts from JSON Map to a CityModel
  // The boundaryPolygon requires special handling: each point in the JSON
  // is like a map like {'lat': 42.69, 'lng': 23.32}, which we convert to LatLng.
  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      cityId: json['cityId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      country: json['country'] as String? ?? '',
      boundaryPolygon: json['boundaryPolygon'] != null
        ? (json['boundaryPolygon'] as List)
            .map((point) => LatLng(
                  (point['lat'] as num).toDouble(),
                  (point['lng'] as num).toDouble(),
            ))
            .toList()
        : [],
      totalRoadSegments: json['totalRoadSegments'] as int? ?? 0,
      totalRoadLengthMeters:
        (json['totalRoadLengthMeters'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // --- toJson ---
  // Converts this CityModel into a Map for storage or sending to a backend.
  // Each LatLng point becomes a simple map with 'lat' and 'lng' keys.
  Map<String, dynamic> toJson() {
    return{
      'cityId': cityId,
      'name': name,
      'country': country,
      'boundaryPolygon': boundaryPolygon
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
          })
          .toList(),
      'totalRoadSegments': totalRoadSegments,
      'totalRoadLengthMeters': totalRoadLengthMeters,
    };

  }
  // --- copyWith ---
  CityModel copyWith({
    String? cityId,
    String? name,
    String? country,
    List<LatLng>? boundaryPolygon,
    int? totalRoadSegments,
    double? totalRoadLengthMeters
  }) {
    return CityModel(
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      country: country ?? this.country,
      boundaryPolygon: boundaryPolygon ?? this.boundaryPolygon,
      totalRoadSegments: totalRoadSegments ?? this.totalRoadSegments,
      totalRoadLengthMeters:
          totalRoadLengthMeters ?? this.totalRoadLengthMeters,
    );
  }
}