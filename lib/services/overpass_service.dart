// Service for fetching city boundaries and road segments from
// OpenStreetMap via the Overpass API.
//
// This service handles:
// - Building Overpass QL queries
// - Making HTTP requests to the Overpass API
// - Parsing JSON responses into CityModel and RoadSegmentModel
// - Calculating road segment lengths using the Haversine formula
//
// Usage:
//   final service = OverpassService();
//   final city = await service.fetchCityBoundary(relationId: 187890); // Athens
//   final roads = await service.fetchRoads(relationId: 187890);

import 'dart:convert'; // For jsonDecode — turns JSON string into Dart objects
import 'dart:math';    // For sin, cos, atan2, sqrt — used in Haversine formula

import 'package:http/http.dart' as http; // HTTP client for API calls
import 'package:latlong2/latlong.dart';  // LatLng coordinate class

import '../models/city_model.dart';
import '../models/road_segment_model.dart';

class OverpassService {
  // --- Constants ---

  /// The Overpass API endpoint. All queries go here as POST requests.
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  /// Timeout for boundary queries (city outline — relatively small response).
  static const int _boundaryTimeoutSeconds = 30;

  /// Timeout for road queries (all roads in a city — can be very large).
  static const int _roadsTimeoutSeconds = 120;

  /// Road types to include — all legally walkable roads/paths.
  /// These are OpenStreetMap 'highway' tag values.
  ///
  /// residential    — neighbourhood streets
  /// tertiary       — smaller connecting roads
  /// secondary      — district-level roads
  /// primary        — major city roads
  /// trunk          — important roads (not motorways)
  /// living_street  — shared pedestrian/vehicle zones
  /// pedestrian     — pedestrian-only streets
  /// footway        — dedicated footpaths/sidewalks
  /// path           — generic paths (parks, trails)
  /// cycleway       — bike paths (legally walkable)
  /// track          — unpaved roads/farm tracks
  /// steps          — staircases connecting streets
  /// bridleway      — horse paths (walkable in most countries)
  /// service        — access roads, alleys, parking lot roads
  /// unclassified   — minor public roads
  static const List<String> _walkableHighwayTypes = [
    'residential',
    'tertiary',
    'secondary',
    'primary',
    'trunk',
    'living_street',
    'pedestrian',
    'footway',
    'path',
    'cycleway',
    'track',
    'steps',
    'bridleway',
    'service',
    'unclassified',
  ];

  // =========================================================================
  // PUBLIC METHODS
  // =========================================================================

  /// Fetches the boundary polygon for a city by its OSM relation ID.
  ///
  /// [relationId] — the OpenStreetMap relation ID for the city.
  ///   Example: 187890 for Athens, Greece.
  ///   You can find these at: https://www.openstreetmap.org/relation/187890
  ///
  /// Returns a [CityModel] with the boundary polygon and metadata.
  /// Throws [OverpassException] if the request fails or returns no data.
  Future<CityModel> fetchCityBoundary({required int relationId}) async {
    // Build the Overpass QL query.
    // This asks for a specific relation (city boundary) with full geometry.
    //
    // "relation(id:...)" — fetch a specific OSM relation by ID
    // "out geom;" — include the actual coordinates (not just metadata)
    final query = '''
[out:json][timeout:$_boundaryTimeoutSeconds];
relation(id:$relationId);
out geom;
''';

    // Send the query to Overpass API
    final jsonData = await _executeQuery(query);

    // The response has an 'elements' array. For a city boundary,
    // we expect exactly one element (the relation we asked for).
    final elements = jsonData['elements'] as List<dynamic>;

    if (elements.isEmpty) {
      throw OverpassException(
        'No boundary found for relation ID $relationId',
      );
    }

    // Parse the relation element into a CityModel
    return _parseBoundaryElement(elements.first, relationId);
  }

  /// Fetches all walkable road segments within a city boundary.
  ///
  /// [relationId] — the OpenStreetMap relation ID for the city.
  /// [cityId] — the cityId string to assign to each road segment
  ///   (should match the CityModel.cityId from fetchCityBoundary).
  ///
  /// Returns a list of [RoadSegmentModel] for all walkable roads.
  /// Throws [OverpassException] if the request fails.
  Future<List<RoadSegmentModel>> fetchRoads({
    required int relationId,
    required String cityId,
  }) async {
    // Build the road types regex for the query.
    // This creates: "residential|tertiary|secondary|..." which Overpass
    // uses as a regex match against the highway tag.
    final highwayRegex = _walkableHighwayTypes.join('|');

    // Build the Overpass QL query for roads.
    //
    // "area(id:3600000000 + relationId)" — converts the relation to a
    //   searchable area. The 3600000000 offset is an Overpass convention
    //   for converting relation IDs to area IDs.
    //
    // 'way["highway"~"..."]' — find all "ways" (roads/paths) where the
    //   highway tag matches any of our walkable types.
    //
    // "(area.city)" — only roads inside the city area.
    //
    // "out geom;" — include full coordinate geometry.
    final areaId = 3600000000 + relationId;
    final query = '''
[out:json][timeout:$_roadsTimeoutSeconds];
area(id:$areaId)->.city;
way["highway"~"^($highwayRegex)\$"](area.city);
out geom;
''';

    // Send the query to Overpass API
    final jsonData = await _executeQuery(query);

    final elements = jsonData['elements'] as List<dynamic>;

    // Parse each road element into a RoadSegmentModel
    final segments = <RoadSegmentModel>[];
    for (final element in elements) {
      final segment = _parseRoadElement(element, cityId);
      if (segment != null) {
        segments.add(segment);
      }
    }

    return segments;
  }

  // =========================================================================
  // PRIVATE METHODS — HTTP
  // =========================================================================

  /// Sends an Overpass QL query and returns the parsed JSON response.
  ///
  /// Uses HTTP POST (not GET) because queries can be long and complex.
  /// GET has URL length limits; POST doesn't.
  Future<Map<String, dynamic>> _executeQuery(String query) async {
    try {
      final response = await http
          .post(
        Uri.parse(_baseUrl),
        // Overpass API expects the query in a form field called 'data'
        body: {'data': query},
      )
          .timeout(
        Duration(seconds: _roadsTimeoutSeconds + 10),
        onTimeout: () {
          throw OverpassException(
            'Request timed out. The Overpass API may be busy — try again in a moment.',
          );
        },
      );

      // Check HTTP status code
      if (response.statusCode == 200) {
        // Success — parse the JSON response body
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        // 429 = Too Many Requests — Overpass has rate limits
        throw OverpassException(
          'Overpass API rate limit reached. Please wait a moment and try again.',
        );
      } else if (response.statusCode == 504) {
        // 504 = Gateway Timeout — query took too long on their server
        throw OverpassException(
          'Query timed out on the Overpass server. The city may have too many roads for a single query.',
        );
      } else {
        throw OverpassException(
          'Overpass API error (HTTP ${response.statusCode}): ${response.body}',
        );
      }
    } on OverpassException {
      // Re-throw our own exceptions as-is
      rethrow;
    } catch (e) {
      // Catch network errors, JSON parse errors, etc.
      throw OverpassException('Failed to contact Overpass API: $e');
    }
  }

  // =========================================================================
  // PRIVATE METHODS — PARSING
  // =========================================================================

  /// Parses an OSM relation element into a CityModel.
  ///
  /// OSM relations have 'members' which are the individual line segments
  /// that make up the boundary. We extract all coordinates from members
  /// with role "outer" (the main boundary, not inner holes like lakes).
  CityModel _parseBoundaryElement(
      Map<String, dynamic> element,
      int relationId,
      ) {
    // Extract city name and country from OSM tags
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final cityName = (tags['name:en'] as String?) ??
        (tags['name'] as String?) ??
        'Unknown City';
    final country = (tags['ISO3166-1:alpha2'] as String?) ??
        (tags['ISO3166-1'] as String?) ??
        (tags['is_in:country'] as String?) ??
        (tags['addr:country'] as String?) ??
        '';

    // Extract boundary coordinates from relation members.
    //
    // A city boundary relation has "members" — these are the individual
    // line segments (ways) that when connected form the boundary polygon.
    // We want members with role "outer" (the main boundary).
    // Each member has a 'geometry' array of {lat, lon} points.
    final members = element['members'] as List<dynamic>? ?? [];
    final boundaryPoints = <LatLng>[];

    for (final member in members) {
      final memberMap = member as Map<String, dynamic>;
      final role = memberMap['role'] as String? ?? '';
      final type = memberMap['type'] as String? ?? '';

      // Only process outer boundary ways (not inner holes, not nodes)
      if (role == 'outer' && type == 'way') {
        final geometry = memberMap['geometry'] as List<dynamic>? ?? [];
        for (final point in geometry) {
          final lat = (point['lat'] as num?)?.toDouble();
          final lon = (point['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            boundaryPoints.add(LatLng(lat, lon));
          }
        }
      }
    }

    if (boundaryPoints.isEmpty) {
      throw OverpassException(
        'City boundary has no coordinates. The relation may not be a valid city boundary.',
      );
    }

    // Build the CityModel.
    // Note: totalRoadSegments and totalRoadLengthMeters are 0 for now —
    // they get populated after we fetch roads separately.
    return CityModel(
      cityId: 'osm_$relationId',
      name: cityName,
      country: country,
      boundaryPolygon: boundaryPoints,
      totalRoadSegments: 0,
      totalRoadLengthMeters: 0.0,
    );
  }

  /// Parses an OSM way element into a RoadSegmentModel.
  ///
  /// Returns null if the way has no geometry (skip it).
  RoadSegmentModel? _parseRoadElement(
      Map<String, dynamic> element,
      String cityId,
      ) {
    // Each road is an OSM "way" with an ID and geometry
    final wayId = element['id'];
    final geometry = element['geometry'] as List<dynamic>? ?? [];

    // Skip ways with no coordinates (shouldn't happen, but be safe)
    if (geometry.length < 2) return null;

    // Extract street name from tags (many roads are unnamed)
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final name = (tags['name'] as String?) ?? '';

    // Convert geometry points to LatLng list
    final polyline = <LatLng>[];
    for (final point in geometry) {
      final lat = (point['lat'] as num?)?.toDouble();
      final lon = (point['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        polyline.add(LatLng(lat, lon));
      }
    }

    if (polyline.length < 2) return null;

    // Calculate the total length of this road segment
    // by summing the distance between each consecutive pair of points.
    final lengthMeters = _calculatePolylineLength(polyline);

    return RoadSegmentModel(
      segmentId: 'way_$wayId',
      cityId: cityId,
      name: name,
      polyline: polyline,
      lengthMeters: lengthMeters,
    );
  }

  // =========================================================================
  // PRIVATE METHODS — GEOMETRY
  // =========================================================================

  /// Calculates the total length of a polyline in meters.
  ///
  /// Sums the Haversine distance between each consecutive pair of points.
  /// You already have Haversine in tracking_provider.dart — this is the
  /// same formula, used here for measuring road lengths.
  double _calculatePolylineLength(List<LatLng> points) {
    double totalLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalLength += _haversineDistance(points[i], points[i + 1]);
    }
    return totalLength;
  }

  /// Haversine formula — calculates distance between two GPS coordinates
  /// on a sphere (the Earth).
  ///
  /// Returns distance in meters.
  double _haversineDistance(LatLng point1, LatLng point2) {
    const double earthRadiusMeters = 6371000.0;

    // Convert degrees to radians
    final lat1 = point1.latitude * pi / 180.0;
    final lat2 = point2.latitude * pi / 180.0;
    final dLat = (point2.latitude - point1.latitude) * pi / 180.0;
    final dLon = (point2.longitude - point1.longitude) * pi / 180.0;

    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }
}

// ===========================================================================
// CUSTOM EXCEPTION
// ===========================================================================

/// Custom exception for Overpass API errors.
///
/// This gives us specific error messages we can display to the user,
/// rather than generic "something went wrong" messages.
///
/// New concept — Custom exceptions:
/// Dart lets you create your own exception types by implementing Exception.
/// This helps distinguish "Overpass API failed" from other errors like
/// "no internet" or "JSON parse error". The provider can catch
/// OverpassException specifically and show a meaningful error message.
class OverpassException implements Exception {
  final String message;

  OverpassException(this.message);

  @override
  String toString() => 'OverpassException: $message';
}