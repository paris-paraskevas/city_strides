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
}




























