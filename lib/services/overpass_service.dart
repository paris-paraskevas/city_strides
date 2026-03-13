// Service for fetching city boundaries and road segments from
// OpenStreetMap via the Overpass API.
//
// This service handles:
// - Building Overpass QL queries
// - Making HTTP requests to the Overpass API
// - Parsing JSON responses into CityModel and RoadSegmentModel
// - Calculating road segment lengths using the Haversine formula
//
// Two modes of operation:
//   1. Relation-based: fetch boundary & roads for an OSM relation ID (e.g. Athens)
//   2. Bounding-box-based: fetch roads within a custom area (e.g. Larissa Centre)
//
// Usage:
//   final service = OverpassService();
//   // Mode 1: OSM relation
//   final city = await service.fetchCityBoundary(relationId: 1370736);
//   final roads = await service.fetchRoads(relationId: 1370736, cityId: 'osm_1370736');
//   // Mode 2: Custom boundary
//   final boundary = await service.fetchBoundaryFromStreets(streetNames: [...], ...);
//   final roads = await service.fetchRoadsInBbox(cityId: 'larissa_centre', ...);

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
  // PUBLIC METHODS — RELATION-BASED (existing)
  // =========================================================================

  /// Fetches the boundary polygon for a city by its OSM relation ID.
  ///
  /// [relationId] — the OpenStreetMap relation ID for the city.
  ///   Example: 1370736 for Athens, Greece.
  ///
  /// Returns a [CityModel] with the boundary polygon and metadata.
  /// Throws [OverpassException] if the request fails or returns no data.
  Future<CityModel> fetchCityBoundary({required int relationId}) async {
    final query = '''
[out:json][timeout:$_boundaryTimeoutSeconds];
relation(id:$relationId);
out geom;
''';

    final jsonData = await _executeQuery(query);

    final elements = jsonData['elements'] as List<dynamic>;

    if (elements.isEmpty) {
      throw OverpassException(
        'No boundary found for relation ID $relationId',
      );
    }

    return _parseBoundaryElement(elements.first, relationId);
  }

  /// Fetches all walkable road segments within a city boundary (by relation).
  ///
  /// [relationId] — the OpenStreetMap relation ID for the city.
  /// [cityId] — the cityId string to assign to each road segment.
  ///
  /// Returns a list of [RoadSegmentModel] for all walkable roads.
  Future<List<RoadSegmentModel>> fetchRoads({
    required int relationId,
    required String cityId,
  }) async {
    final highwayRegex = _walkableHighwayTypes.join('|');

    final areaId = 3600000000 + relationId;
    final query = '''
[out:json][timeout:$_roadsTimeoutSeconds];
area(id:$areaId)->.city;
way["highway"~"^($highwayRegex)\$"](area.city);
out geom;
''';

    final jsonData = await _executeQuery(query);

    final elements = jsonData['elements'] as List<dynamic>;

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
  // PUBLIC METHODS — BOUNDING BOX-BASED (new for Chat 13)
  // =========================================================================

  /// Fetches the geometry of named streets and stitches them into a
  /// continuous boundary polygon.
  ///
  /// This is used for custom city boundaries defined by ring roads
  /// (like Larissa Centre, bounded by Κίμωνος Σανδράκη → Αθανασίου Λάγου
  /// → Ηρώων Πολυτεχνείου).
  ///
  /// [streetNames] — list of street names that form the boundary ring.
  /// [south], [west], [north], [east] — bounding box to search within.
  ///   This prevents matching streets with the same name in other cities.
  ///
  /// Returns an ordered list of [LatLng] points forming a closed polygon.
  /// Throws [OverpassException] if no streets are found.
  ///
  /// HOW IT WORKS:
  /// 1. Queries Overpass for all OSM ways matching the street names
  /// 2. Each street may consist of multiple way segments (OSM splits
  ///    roads at intersections). We get back many small pieces.
  /// 3. We "stitch" these pieces together by connecting endpoints
  ///    that are close to each other, forming one continuous line.
  /// 4. The result is an ordered polygon tracing the ring road.
  Future<List<LatLng>> fetchBoundaryFromStreets({
    required List<String> streetNames,
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    // Build an Overpass union query for all street names.
    //
    // A "union" in Overpass is multiple queries inside parentheses,
    // separated by semicolons. The results are combined.
    //
    // Example output:
    //   (
    //     way["name"="Κίμωνος Σανδράκη"](39.62,22.39,39.66,22.44);
    //     way["name"="Αθανασίου Λάγου"](39.62,22.39,39.66,22.44);
    //     way["name"="Ηρώων Πολυτεχνείου"](39.62,22.39,39.66,22.44);
    //   );
    final bbox = '$south,$west,$north,$east';
    final wayQueries = streetNames
        .map((name) => 'way["name"="$name"]($bbox);')
        .join('\n  ');

    final query = '''
[out:json][timeout:$_boundaryTimeoutSeconds];
(
  $wayQueries
);
out geom;
''';

    final jsonData = await _executeQuery(query);

    final elements = jsonData['elements'] as List<dynamic>;

    if (elements.isEmpty) {
      throw OverpassException(
        'No streets found matching names: ${streetNames.join(", ")}. '
            'Check spelling matches OpenStreetMap exactly.',
      );
    }

    // Extract each way's coordinates as a separate list.
    // Each OSM way becomes one List<LatLng>.
    final ways = <List<LatLng>>[];

    for (final element in elements) {
      final geometry = element['geometry'] as List<dynamic>? ?? [];
      if (geometry.length < 2) continue;

      final wayPoints = <LatLng>[];
      for (final point in geometry) {
        final lat = (point['lat'] as num?)?.toDouble();
        final lon = (point['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          wayPoints.add(LatLng(lat, lon));
        }
      }
      if (wayPoints.length >= 2) {
        ways.add(wayPoints);
      }
    }

    if (ways.isEmpty) {
      throw OverpassException(
        'Streets found but contain no coordinates.',
      );
    }

    // Stitch all way segments into one continuous polygon.
    final stitchedPolygon = _stitchWays(ways);

    return stitchedPolygon;
  }

  /// Fetches all walkable road segments within a bounding box.
  ///
  /// Unlike [fetchRoads] which uses an OSM relation/area, this method
  /// uses raw latitude/longitude bounds. This is needed for custom
  /// city boundaries that don't correspond to an OSM administrative area.
  ///
  /// [cityId] — the cityId to assign to each road segment.
  /// [south], [west], [north], [east] — the bounding box.
  ///
  /// Returns a list of [RoadSegmentModel] for all walkable roads in the box.
  Future<List<RoadSegmentModel>> fetchRoadsInBbox({
    required String cityId,
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final highwayRegex = _walkableHighwayTypes.join('|');
    final bbox = '$south,$west,$north,$east';

    // Much simpler query than the relation-based one:
    // just find all walkable ways inside the bounding box.
    final query = '''
[out:json][timeout:$_roadsTimeoutSeconds];
way["highway"~"^($highwayRegex)\$"]($bbox);
out geom;
''';

    final jsonData = await _executeQuery(query);

    final elements = jsonData['elements'] as List<dynamic>;

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
  Future<Map<String, dynamic>> _executeQuery(String query) async {
    try {
      final response = await http
          .post(
        Uri.parse(_baseUrl),
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

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        throw OverpassException(
          'Overpass API rate limit reached. Please wait a moment and try again.',
        );
      } else if (response.statusCode == 504) {
        throw OverpassException(
          'Query timed out on the Overpass server. The area may have too many roads for a single query.',
        );
      } else {
        throw OverpassException(
          'Overpass API error (HTTP ${response.statusCode}): ${response.body}',
        );
      }
    } on OverpassException {
      rethrow;
    } catch (e) {
      throw OverpassException('Failed to contact Overpass API: $e');
    }
  }

  // =========================================================================
  // PRIVATE METHODS — PARSING
  // =========================================================================

  /// Parses an OSM relation element into a CityModel.
  CityModel _parseBoundaryElement(
      Map<String, dynamic> element,
      int relationId,
      ) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final cityName = (tags['sorting_name'] as String?) ??
        (tags['name:en'] as String?) ??
        (tags['name'] as String?) ??
        'Unknown City';

    final country = (tags['ISO3166-1:alpha2'] as String?) ??
        (tags['ISO3166-1'] as String?) ??
        (tags['is_in:country'] as String?) ??
        (tags['is_in:country_code'] as String?) ??
        '';

    final members = element['members'] as List<dynamic>? ?? [];
    final boundaryPoints = <LatLng>[];

    for (final member in members) {
      final memberMap = member as Map<String, dynamic>;
      final role = memberMap['role'] as String? ?? '';
      final type = memberMap['type'] as String? ?? '';

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
  /// Returns null if the way has no geometry.
  RoadSegmentModel? _parseRoadElement(
      Map<String, dynamic> element,
      String cityId,
      ) {
    final wayId = element['id'];
    final geometry = element['geometry'] as List<dynamic>? ?? [];

    if (geometry.length < 2) return null;

    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final name = (tags['name'] as String?) ?? '';

    final polyline = <LatLng>[];
    for (final point in geometry) {
      final lat = (point['lat'] as num?)?.toDouble();
      final lon = (point['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        polyline.add(LatLng(lat, lon));
      }
    }

    if (polyline.length < 2) return null;

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
  // PRIVATE METHODS — WAY STITCHING (new for Chat 13)
  // =========================================================================

  /// Stitches multiple OSM way segments into a single continuous polygon.
  ///
  /// WHY THIS IS NEEDED:
  /// OpenStreetMap splits roads at every intersection. So a ring road
  /// that's one continuous street to a human is stored as 10-30 separate
  /// "way" objects in OSM. To draw a boundary polygon, we need to
  /// connect them end-to-end in the right order.
  ///
  /// HOW IT WORKS:
  /// 1. Start with the first way segment
  /// 2. Look at its last point (endpoint)
  /// 3. Find another segment that starts or ends near that point
  /// 4. If it starts there → append its points in order
  ///    If it ends there → append its points in reverse
  /// 5. Repeat until no more segments can be connected
  ///
  /// This is like connecting puzzle pieces by matching their edges.
  ///
  /// EXAMPLE:
  ///   Way A: [p1, p2, p3]
  ///   Way B: [p3, p4, p5]  ← starts where A ends
  ///   Way C: [p7, p6, p5]  ← ends where B ends (needs reversing)
  ///   Result: [p1, p2, p3, p4, p5, p6, p7]
  List<LatLng> _stitchWays(List<List<LatLng>> ways) {
    if (ways.isEmpty) return [];
    if (ways.length == 1) return ways.first;

    // Start with the first way's points
    final result = List<LatLng>.from(ways.first);

    // Track which ways we've already used
    final remaining = List<List<LatLng>>.from(ways.sublist(1));

    // Keep connecting ways until we can't find any more matches
    int maxIterations = remaining.length + 1; // Safety limit
    int iteration = 0;

    while (remaining.isNotEmpty && iteration < maxIterations) {
      iteration++;
      final lastPoint = result.last;
      bool foundMatch = false;

      for (int i = 0; i < remaining.length; i++) {
        final way = remaining[i];

        // Case 1: This way STARTS where our chain ends
        // → append its points in order (skip first to avoid duplicate)
        if (_pointsClose(lastPoint, way.first)) {
          result.addAll(way.skip(1));
          remaining.removeAt(i);
          foundMatch = true;
          break;
        }

        // Case 2: This way ENDS where our chain ends
        // → append its points in REVERSE (skip first of reversed = last of original)
        if (_pointsClose(lastPoint, way.last)) {
          result.addAll(way.reversed.skip(1));
          remaining.removeAt(i);
          foundMatch = true;
          break;
        }
      }

      // If no segment connects to our chain, stop.
      // (Some segments might be disconnected — that's OK, we have enough)
      if (!foundMatch) break;
    }

    return result;
  }

  /// Checks if two LatLng points are close enough to be considered
  /// the same intersection point.
  ///
  /// 0.00005 degrees ≈ 5.5 meters — accounts for slight coordinate
  /// differences between connected OSM ways at the same intersection.
  bool _pointsClose(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00005 &&
        (a.longitude - b.longitude).abs() < 0.00005;
  }

  // =========================================================================
  // PRIVATE METHODS — GEOMETRY
  // =========================================================================

  /// Calculates the total length of a polyline in meters.
  double _calculatePolylineLength(List<LatLng> points) {
    double totalLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalLength += _haversineDistance(points[i], points[i + 1]);
    }
    return totalLength;
  }

  /// Haversine formula — distance between two GPS coordinates in meters.
  double _haversineDistance(LatLng point1, LatLng point2) {
    const double earthRadiusMeters = 6371000.0;

    final lat1 = point1.latitude * pi / 180.0;
    final lat2 = point2.latitude * pi / 180.0;
    final dLat = (point2.latitude - point1.latitude) * pi / 180.0;
    final dLon = (point2.longitude - point1.longitude) * pi / 180.0;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }
}

// ===========================================================================
// CUSTOM EXCEPTION
// ===========================================================================

class OverpassException implements Exception {
  final String message;

  OverpassException(this.message);

  @override
  String toString() => 'OverpassException: $message';
}