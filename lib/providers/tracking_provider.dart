// Manages walk tracking - the core logic that connects GPS positions to road
// segments and records what the user has walked.
//
// Depends on:
//    - locationProvider: for GPS position updates
//    - roadProvider: for the list of road segments to match against
//    - RoadMatchingService: spatial grid for fast GPS-to-road matching
//
// Flow:
//  1. Roads load → buildGrid() indexes them into spatial cells
//  2. GPS position arrives (piped in by map_screen via ref.listen)
//  3. processPosition() uses the spatial grid to find the nearest road
//  4. If the user is close enough (within 25m), that segment is marked "walked"
//  5. progress_provider reads this data to calculate completion %
//
// PERFORMANCE NOTE:
// The old approach looped through ALL segments on every GPS update (O(n)).
// The spatial grid reduces this to O(1) lookup + O(k) local check,
// where k is typically 10-30 nearby segments. This prevents UI freezing
// with thousands of real road segments.

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/walked_segment_model.dart';
import '../models/road_segment_model.dart';
import '../services/road_matching_service.dart';
import 'location_provider.dart';
import 'road_provider.dart';

// --- State class ---
class TrackingState {
  // Set of segment IDs that have been walked.
  // A Set (not a List) because:
  //    - Each segment should only appear once (no duplicates)
  //    - Checking "has this segment been walked?" is very fast with a Set
  //    (O(1) lookup vs O(n) for a List - meaning a Set checks instantly
  //    regardless of size, while a List gets slower as it grows)
  final Set<String> walkedSegmentIds;

  // Full records of each walk event, with timestamps.
  // This is the data that would be synced to a backend later.
  final List<WalkedSegmentModel> walkedSegments;

  // Is active tracking currently running?
  final bool isActive;

  // Is the spatial grid ready for matching?
  // This becomes true after buildGrid() completes.
  final bool isGridReady;

  final String? errorMessage;

  const TrackingState({
    this.walkedSegmentIds = const {},
    this.walkedSegments = const [],
    this.isActive = false,
    this.isGridReady = false,
    this.errorMessage,
  });

  TrackingState copyWith({
    Set<String>? walkedSegmentIds,
    List<WalkedSegmentModel>? walkedSegments,
    bool? isActive,
    bool? isGridReady,
    String? errorMessage,
  }) {
    return TrackingState(
      walkedSegmentIds: walkedSegmentIds ?? this.walkedSegmentIds,
      walkedSegments: walkedSegments ?? this.walkedSegments,
      isActive: isActive ?? this.isActive,
      isGridReady: isGridReady ?? this.isGridReady,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// --- State Notifier ---
class TrackingNotifier extends StateNotifier<TrackingState> {
  final Ref _ref;

  // The spatial grid service — lives here because tracking owns the
  // matching logic. One instance, reused across all GPS updates.
  final RoadMatchingService _matchingService = RoadMatchingService();

  TrackingNotifier(this._ref) : super(const TrackingState());

  // Distance threshold in meters.
  // If the user is within this distance of a road segment,
  // that segment is marked as "walked".
  //
  // 25 meters accounts for GPS inaccuracy (which is typically
  // 3-10 meters outside) plus the fact that the user might be
  // walking on a sidewalk next to the road, not on the road itself.
  static const double _matchThresholdMeters = 25.0;

  // --- Build the spatial grid index ---
  // Call this once when road segments are loaded. It creates the
  // grid that makes GPS-to-road matching fast.
  //
  // This is called from map_screen.dart after roads finish loading.
  // It replaces the old approach of scanning all segments on every
  // GPS update.
  void buildGrid(List<RoadSegmentModel> segments) {
    _matchingService.buildGrid(segments);
    state = state.copyWith(isGridReady: true);
  }

  // --- Start GPS tracking ---
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
  // This is the method called each time a new GPS position arrives.
  // It uses the spatial grid to find the nearest road segment quickly,
  // and marks it as walked if close enough.
  //
  // IMPORTANT: This is called by map_screen.dart via ref.listen on
  // locationProvider. The map screen acts as the "bridge" connecting
  // GPS updates to the tracking logic.
  void processPosition(Position position) {
    // Can't match if the grid hasn't been built yet
    if (!_matchingService.isBuilt) return;

    // Use the spatial grid to find the nearest road segment.
    // This checks only ~20 nearby segments instead of all ~10,000.
    final result = _matchingService.findNearestSegment(
      position.latitude,
      position.longitude,
    );

    // If no segment is near enough, do nothing
    if (result == null) return;

    // Only mark as walked if within threshold
    if (result.distance <= _matchThresholdMeters) {
      markSegmentWalked(
        result.segment.segmentId,
        result.segment.cityId,
      );
    }
  }

  // --- Mark a segment as walked ---
  // Records that the user has walked a specific road segment.
  // Checks for duplicates using the walkedSegmentIds Set.
  void markSegmentWalked(String segmentId, String cityId) {
    // Skip if already walked — the Set makes this check fast
    if (state.walkedSegmentIds.contains(segmentId)) return;

    // For now, hardcode 'local_user' to match auth_provider
    const userId = 'local_user';

    // Create the walk record
    final walkedSegment = WalkedSegmentModel(
      userId: userId,
      segmentId: segmentId,
      cityId: cityId,
      walkedAt: DateTime.now(),
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

  // --- Clear all walked data ---
  // Resets tracking state. Used when switching cities or for testing.
  void clearWalkedSegments() {
    _matchingService.clear();
    state = const TrackingState();
  }
}

// --- Provider ---
// Usage:
//    final trackingState = ref.watch(trackingProvider);
//    final walkedCount = trackingState.walkedSegments.length;
//
//    ref.read(trackingProvider.notifier).startTracking();
//    ref.read(trackingProvider.notifier).stopTracking();
//    ref.read(trackingProvider.notifier).buildGrid(segments);
final trackingProvider =
StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref);
});