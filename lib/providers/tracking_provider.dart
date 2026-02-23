// Manages walk tracking - the core logic that connects GPS positions to road
// segments and records what the user has walked.
//
// Depends on:
//    - locationProvider: for GPS position updates
//    - roadProvider: for the list of road segments to match against
// Flow:
//  1. GPS position arrives from locationProvider
//  2. This provider checks which road segment is closest
//  3. If the user is close enough to a road (within threshold),
//     that segment is marked as "walked"
//  4. A WalkedSegmentModel record is created
//  5. progress_provider reads this data to calculate completion %
//
// Currently uses a simplified distance check for road matching.
// Later: road_matching_service.dart will handle proper GPS-to-road
// snapping with point-to-line distance calculations.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/walked_segment_model.dart';
import '../models/road_segment_model.dart';
import 'location_provider.dart';
import 'road_provider.dart';

// --- State class ---
class TrackingState {
  // Set of segment IDs that have been walked.
  // A Set (not a List) because:
  //    - Each segment should only appear once (no duplicates)
  //    - Checking "has this segment been walked?" is very fast with a Set
  //    (0(1) lookup vs 0(n) for a List - meaning a Set checks instantly
  //    regardless of size, while a List gets slower as it grows)
  final Set<String> walkedSegmentIds;

  // Full records of each walk event, with timestamps.
  // This is the data that would be synced to a backend later.
  final List<WalkedSegmentModel> walkedSegments;

  // Is active tracking currently running?
  final bool isActive;

  final String? errorMessage;

  const TrackingState ({
    this.walkedSegmentIds = const {},
    this.walkedSegments = const[],
    this.isActive = false,
    this.errorMessage,
  });

  TrackingState copyWith ({
    Set<String>? walkedSegmentIds,
    List<WalkedSegmentModel>? walkedSegments,
    bool? isActive,
    String? errorMessage,
  })  {
    return TrackingState(
      walkedSegmentIds: walkedSegmentIds ?? this.walkedSegmentIds,
      walkedSegments: walkedSegments ?? this.walkedSegments,
      isActive: isActive ?? this.isActive,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// --- State Notifier ---
class TrackingNotifier extends StateNotifier<TrackingState> {
  final Ref _ref;

  TrackingNotifier(this._ref) : super(const TrackingState());

  // Distance threshold in meters.
  // If the user is within this distance of a road segment,
  //
  // 25 meters accounts for GPS inaccuracy ( which is typically
  // 3 - 10 meters outside) plus the fact that the user might be
  // walking on a sidewalk next to the road, not on the road itself.

  Future<void> startTracking() async {
    await _ref.read(locationProvider.notifier).startTracking();
    state = state.copyWith(isActive: true);
  }

  // --- Stop active tracking ---
  void stopTracking() {
    _ref.read(locationProvider.notifier).stopTracking();
    state = state.copyWith(isActive: false);
  }

  // --- Process a GPS position ---
  // This is the method that does the actual tracking work.
  // Called each time a new GPS position arrives.
  //
  // It finds the nearest road segment and, if it's close enough,
  // marks it as walked.
  void processPosition(Position position) {
    // Get the current road segments from roadProvider
    final roadState = _ref.read(roadProvider);

    if (roadState.segments.isEmpty) return;

    // Find the nearest road segment to the user's position
    final nearestResult = _findNearestSegment(
      position,
      roadState.segments,
    );

    // If no segment is near enough do nothing
    if (nearestResult == null) return;

    final nearestSegment = nearestResult.segment;
    final distance = nearestSegment.distance;

    // Only mark as walked if within threshold
    if (distance <= _matchThresholdMeters) {
      markSegmentWalked(
        nearestSegment.segmentId,
        nearestSegment.cityId,
      );
    }
  }

  // --- Mark a segment as walked ---
  // Records that the user has walked a specific road segment
  // Checks for duplicates using the walkedSegmentIds Set.
  void markSegmentWalked(String segmentId, String cityId) {
    // Skip if already walked - the Set makes this check fast
    if (state.walkedSegmentIds.contains(segmentId)) return;

    // Get the current user's ID from authProvider
    // We import it here to avoid circular dependency at the top level
    // For now, hardcode 'local_user' to match auth_provider
    const userId = 'local_user';

    // Create the walk record
    final walkedSegment = WalkedSegmentModel(
        userId: userId,
        segmentId: segmentId,
        cityId: cityId,
        walkedAt: DateTime.now()
    );

    // Update state with the new walked segment.
    // We create NEW Set and List objects (using spread operator)
    // rather than modifying the existing ones. This is because
    // Riverpod detects changes by checking if the object reference
    // changed. If we just added to the existing Set, Riverpod
    // wouldn't notice the change.
    state = state.copyWith(
      walkedSegmentIds: {...state.walkedSegmentIds, segmentId},
      walkedSegments: [...state.walkedSegments, walkedSegment],
    );
  }

  // --- Find the nearest road segment to a GPS position ---
  // Loops through all segments and finds the closest one.
  //
  // Return a _nearestSegmentResult with the segment and its distance,
  // or null if there are no segments to check.
  //
  // TODO: Replace with road_matching_service.dart which will use
  //  proper point-to-line distance (perpendicular distance from the
  //  GPS point to each road's polyline). Current implementation uses
  // point-to-point distance to the nearest vertex, which is simpler
  // but less accurate.
  _NearestSegmentResult? _findNearestSegment(
      Position position,
      List<RoadSegmentModel> segments,
      ) {
        if (segments.isEmpty) return null;

        RoadSegmentModel? nearestSegment;
        double nearestDistance = double.infinity;

        // Loop through every road segment
        for (final segment in segments) {
          // Check distance to each point in the segment's polyline
          for (final point in segment.polyline) {
            final distance = _calculateDistance(
              position.latitude,
              position.longitude,
              point.latitude,
              point.longitude,
            );

            // If this point is closer than our current best, update
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestSegment = segment;
            }
          }
        }

        if (nearestSegment == null) return null;

        return _NearestSegmentResult(
          segment: nearestSegment,
          distance: nearestDistance,
        );
      }

  // --- Calculate distance between two GPS coordinates ---
  // Uses the Haversine formula to calculate the distance in meters
  // between two latitude/longitude points.
  //
  // Why Haversine? Because the Earth is a sphere (roughly) so you
  // can't use Pythagoras. Haversine account for the curvature.
  //
  // This will be moved to geo_utils.dart later when we organise
  // utility functions.
  double _calculateDistance(
      double lat1,
      double lat2,
      double lon1,
      double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat /2) +
        cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return earthRadius * c;
  }

  // Converts degrees to radians. GPS coordinates are in degrees
  // but trigonometric functions (sin, cos) work with radians.
  double _toRadians(double degrees){
    return degrees * (pi/180);
  }

  // --- Clear all walked data ---
  // Resets tracking state. Used when switching cities or for testing.
  void clearWalkedSegments(){
    state = const TrackingState();
  }
}

// --- Helper class ---
// Bundles a segment with its distance so _findNearestSegment can
// return both values. The underscore prefix makes it private to
// this file - so other files can't use _NearestSegmentResult.
class _NearestSegmentResult {
  final RoadSegmentModel segment;
  final double distance;

  _NearestSegmentResult({
    required this.segment,
    required this.distance,
  });
}

// --- Provider ---
// Usage:
//    final trackingState = ref.watch(trackingProvider);
//    final walkedCount = trackingState.walkedSegments.length;
//
//    ref.read(trackingProvider.notifier).startTracking();
//    ref.read(trackingProvider.notifier).stopTracking();
final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref);
});




























