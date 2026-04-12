// Shared geographic utility functions.
//
// Single source of truth for distance calculations used by
// overpass_service.dart and road_matching_service.dart.

import 'dart:math';
import 'package:latlong2/latlong.dart';

const double _earthRadiusMeters = 6371000.0;

double _toRadians(double degrees) => degrees * (pi / 180.0);

/// Haversine distance between two raw coordinate pairs, in meters.
double haversineDistance(
  double lat1, double lng1,
  double lat2, double lng2,
) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return _earthRadiusMeters * c;
}

/// Haversine distance between two LatLng points, in meters.
double haversineDistanceLatLng(LatLng a, LatLng b) {
  return haversineDistance(
    a.latitude, a.longitude,
    b.latitude, b.longitude,
  );
}

/// Total length of a polyline in meters.
double polylineLength(List<LatLng> points) {
  double total = 0.0;
  for (int i = 0; i < points.length - 1; i++) {
    total += haversineDistanceLatLng(points[i], points[i + 1]);
  }
  return total;
}
