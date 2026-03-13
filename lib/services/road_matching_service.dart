// Fast GPS-to-road matching using a spatial grid index.
//
// THE PROBLEM:
// When the user walks, we get GPS updates every few seconds. For each update,
// we need to find which road segment is closest. With thousands of segments
// (Larissa might have 5,000–15,000), checking every single one on every GPS
// update would freeze the UI — that's tens of thousands of distance calculations
// multiple times per second.
//
// THE SOLUTION: Spatial Grid Indexing
// Imagine laying a sheet of graph paper over the city map. Each square on the
// graph paper is a "cell" (roughly 100m × 100m). When we first load the road
// data, we assign each road segment to every cell it passes through.
//
// Then when a GPS update arrives, instead of checking ALL roads in the city,
// we just look up which cell the user is in, grab the roads in that cell and
// its 8 neighbouring cells, and only check those. This typically means checking
// ~10-30 segments instead of ~10,000.
//
// Big-O complexity:
//   Before (brute force): O(n) per GPS update, where n = total segments
//   After (spatial grid):  O(1) lookup + O(k) check, where k = nearby segments (~20)
//
// GRID CELL SIZE:
// We use ~111m per cell (0.001 degrees latitude ≈ 111m, longitude varies by
// latitude but is close enough for Greece at ~39°N where 0.001° ≈ 87m).
// This is a good balance:
//   - Too small (10m): too many cells, segments spread across many cells, memory waste
//   - Too large (1km): too many segments per cell, not much faster than brute force
//   - 100m: typically 5-30 segments per cell — fast to check

import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/road_segment_model.dart';

class RoadMatchingService {
  // --- Grid Configuration ---

  // How many degrees per grid cell.
  // 0.001 degrees ≈ 111 meters in latitude.
  // At Larissa's latitude (~39.6°N), 0.001° longitude ≈ 85m.
  // So each cell is roughly 111m × 85m — close enough for our purposes.
  static const double _cellSize = 0.001;

  // --- The Grid ---
  // A Map where:
  //   - Key: a string like "39638_22416" representing a grid cell
  //   - Value: a list of road segments that pass through that cell
  //
  // Why a Map<String, List>? Because:
  //   - We can look up any cell in O(1) time using its key
  //   - Empty cells don't take up memory (unlike a 2D array)
  //   - The string key is easy to compute from any GPS coordinate
  final Map<String, List<RoadSegmentModel>> _grid = {};

  // Whether the grid has been built yet.
  // We check this before trying to match — if the grid is empty,
  // there's nothing to match against.
  bool _isBuilt = false;
  bool get isBuilt => _isBuilt;

  // How many segments are indexed (for debug display).
  int _segmentCount = 0;
  int get segmentCount => _segmentCount;

  // --- Build the Grid ---
  // Call this once when road segments are first loaded.
  // It loops through every segment and assigns it to all grid cells
  // that the segment passes through.
  //
  // Why "all cells it passes through"? Because a road segment might
  // be 300m long, crossing 3 or 4 grid cells. We need to find it
  // regardless of which cell the user is standing in.
  void buildGrid(List<RoadSegmentModel> segments) {
    // Clear any previous grid (e.g. if switching cities)
    _grid.clear();
    _segmentCount = segments.length;

    for (final segment in segments) {
      // Get all unique grid cells this segment touches
      final cells = _getCellsForSegment(segment);

      // Add this segment to each cell it touches
      for (final cellKey in cells) {
        // putIfAbsent: if this cell key doesn't exist in the map yet,
        // create an empty list for it. Then add the segment to that list.
        //
        // This is a common Dart pattern for "get or create":
        //   - First time a cell is encountered: creates [] then adds segment
        //   - Subsequent times: just adds segment to existing list
        _grid.putIfAbsent(cellKey, () => []).add(segment);
      }
    }

    _isBuilt = true;
  }

  // --- Find Nearest Segment ---
  // Given a GPS position, find the closest road segment.
  // Returns a MatchResult with the segment and distance, or null if
  // nothing is within range.
  //
  // This is the method called on every GPS update — it MUST be fast.
  //
  // How it works:
  //   1. Calculate which grid cell the GPS position falls in
  //   2. Get all segments in that cell AND its 8 neighbours (a 3×3 area)
  //   3. Check distance to each of those segments only
  //   4. Return the closest one (if any)
  //
  // Why 8 neighbours? Because the user might be standing at the edge
  // of a cell, and the nearest road might be in the adjacent cell.
  // Checking a 3×3 area (roughly 300m × 300m) guarantees we won't
  // miss any road within our 25m matching threshold.
  MatchResult? findNearestSegment(double latitude, double longitude) {
    if (!_isBuilt) return null;

    // Step 1: Get the grid cell coordinates for this GPS position
    final centerRow = _latToRow(latitude);
    final centerCol = _lngToCol(longitude);

    // Step 2: Collect candidate segments from 3×3 neighbourhood
    // Using a Set of segment IDs to avoid checking the same segment
    // twice (a long road might appear in multiple neighbouring cells).
    final Set<String> checkedIds = {};
    RoadSegmentModel? nearestSegment;
    double nearestDistance = double.infinity;

    // Loop through the 3×3 grid of cells centred on the user
    // row goes from centerRow-1 to centerRow+1 (3 rows)
    // col goes from centerCol-1 to centerCol+1 (3 columns)
    for (int row = centerRow - 1; row <= centerRow + 1; row++) {
      for (int col = centerCol - 1; col <= centerCol + 1; col++) {
        // Build the cell key for this grid position
        final cellKey = '${row}_$col';

        // Get segments in this cell (empty list if cell has no roads)
        final cellSegments = _grid[cellKey];
        if (cellSegments == null) continue;

        // Check each segment in this cell
        for (final segment in cellSegments) {
          // Skip if we already checked this segment (from another cell)
          if (checkedIds.contains(segment.segmentId)) continue;
          checkedIds.add(segment.segmentId);

          // Find the closest point on this segment's polyline
          final distance = _distanceToSegment(
            latitude,
            longitude,
            segment,
          );

          if (distance < nearestDistance) {
            nearestDistance = distance;
            nearestSegment = segment;
          }
        }
      }
    }

    if (nearestSegment == null) return null;

    return MatchResult(
      segment: nearestSegment,
      distance: nearestDistance,
    );
  }

  // --- Calculate distance from a point to a road segment ---
  // Checks the GPS position against every vertex (point) in the
  // segment's polyline and returns the shortest distance found.
  //
  // This is the same approach as the old brute-force method, but
  // now it's only called for ~20 nearby segments instead of ~10,000.
  //
  // Future improvement: use point-to-LINE-SEGMENT distance (perpendicular
  // distance to the line between vertices) instead of point-to-VERTEX.
  // This would be more accurate for long straight roads where the nearest
  // point is between two vertices, not AT a vertex.
  double _distanceToSegment(
      double lat,
      double lng,
      RoadSegmentModel segment,
      ) {
    double minDistance = double.infinity;

    for (final point in segment.polyline) {
      final distance = _haversineDistance(
        lat, lng,
        point.latitude, point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  // --- Get all grid cells that a segment passes through ---
  // A segment has a polyline (list of LatLng points). We need to
  // find every grid cell that any point of the polyline falls in.
  //
  // We use a Set<String> so cells aren't duplicated (multiple points
  // of the same segment might fall in the same cell).
  Set<String> _getCellsForSegment(RoadSegmentModel segment) {
    final Set<String> cells = {};

    for (final point in segment.polyline) {
      final row = _latToRow(point.latitude);
      final col = _lngToCol(point.longitude);
      cells.add('${row}_$col');
    }

    return cells;
  }

  // --- Convert latitude to grid row ---
  // Divides the latitude by cell size and floors it to get an integer row.
  // Example: latitude 39.6383 / 0.001 = 39638.3 → row 39638
  int _latToRow(double latitude) {
    return (latitude / _cellSize).floor();
  }

  // --- Convert longitude to grid column ---
  // Same concept as _latToRow but for the east-west axis.
  // Example: longitude 22.4161 / 0.001 = 22416.1 → col 22416
  int _lngToCol(double longitude) {
    return (longitude / _cellSize).floor();
  }

  // --- Haversine distance formula ---
  // Calculates the distance in meters between two GPS coordinates
  // on the surface of the Earth.
  //
  // Same formula as in tracking_provider.dart, copied here so this
  // service is self-contained with no provider dependencies.
  // Later we can extract this to a shared geo_utils.dart file.
  double _haversineDistance(
      double lat1, double lng1,
      double lat2, double lng2,
      ) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) *
                cos(_toRadians(lat2)) *
                sin(dLng / 2) *
                sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // --- Clear the grid ---
  // Used when switching cities or clearing data.
  void clear() {
    _grid.clear();
    _isBuilt = false;
    _segmentCount = 0;
  }
}

// --- Result class ---
// Bundles a matched segment with its distance from the user.
// Public (no underscore) so tracking_provider can use it.
class MatchResult {
  final RoadSegmentModel segment;
  final double distance;

  MatchResult({
    required this.segment,
    required this.distance,
  });
}