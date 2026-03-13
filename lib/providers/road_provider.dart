// Manages road segment data for the current city.
//
// Uses OverpassService to fetch real road data from OpenStreetMap.
// Uses CacheService to store/retrieve road data locally.
//
// Two modes of loading (added in Chat 13):
//   1. By OSM relation ID — fetches roads within an admin boundary (e.g. Athens)
//   2. By bounding box — fetches roads within a rectangle (e.g. Larissa Centre)
//
// Both modes use the same cache-first strategy:
//   Check cache → load from disk (instant) or fetch from API → save to cache

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/road_segment_model.dart';
import '../services/overpass_service.dart';
import '../services/cache_service.dart';

// --- State class ---
// UNCHANGED from previous version.
class RoadState {
  final List<RoadSegmentModel> segments;
  final bool isLoading;
  final String? errorMessage;

  const RoadState({
    this.segments = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  RoadState copyWith({
    List<RoadSegmentModel>? segments,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RoadState(
      segments: segments ?? this.segments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// --- StateNotifier ---
class RoadNotifier extends StateNotifier<RoadState> {
  final Ref _ref;
  final OverpassService _overpassService = OverpassService();
  final CacheService _cacheService = CacheService();

  RoadNotifier(this._ref) : super(const RoadState());

  // =========================================================================
  // MODE 1: Load by OSM relation ID (existing — for cities like Athens)
  // =========================================================================

  /// Loads roads within an OSM relation boundary.
  /// Cache-first: checks disk before calling API.
  Future<void> loadRoadsForCity({
    required int relationId,
    required String cityId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Check cache
      if (await _cacheService.areRoadsCached(cityId)) {
        final cachedRoads = await _cacheService.loadCachedRoads(cityId);
        if (cachedRoads != null) {
          state = state.copyWith(
            segments: cachedRoads,
            isLoading: false,
          );
          return;
        }
      }

      // Step 2: Cache miss — fetch from Overpass API
      final segments = await _overpassService.fetchRoads(
        relationId: relationId,
        cityId: cityId,
      );

      // Step 3: Save to cache
      await _cacheService.saveRoads(cityId, segments);

      // Step 4: Update state
      state = state.copyWith(
        segments: segments,
        isLoading: false,
      );
    } on OverpassException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load roads: $e',
      );
    }
  }

  // =========================================================================
  // MODE 2: Load by bounding box (new — Chat 13, for Larissa Centre)
  // =========================================================================

  /// Loads all walkable roads within a bounding box.
  ///
  /// Used when the city boundary is custom (not an OSM relation), so we
  /// can't use the area(id:...) Overpass syntax. Instead we query by
  /// raw latitude/longitude bounds.
  ///
  /// [cityId] — must match the CityModel.cityId for cache consistency.
  /// [south], [west], [north], [east] — the bounding box coordinates.
  ///
  /// The bbox should be calculated from the boundary polygon. For Larissa
  /// Centre, this is the bbox of the ring road that defines the boundary.
  Future<void> loadRoadsInBbox({
    required String cityId,
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Check cache
      if (await _cacheService.areRoadsCached(cityId)) {
        final cachedRoads = await _cacheService.loadCachedRoads(cityId);
        if (cachedRoads != null) {
          state = state.copyWith(
            segments: cachedRoads,
            isLoading: false,
          );
          return;
        }
      }

      // Step 2: Cache miss — fetch from Overpass API using bbox
      final segments = await _overpassService.fetchRoadsInBbox(
        cityId: cityId,
        south: south,
        west: west,
        north: north,
        east: east,
      );

      // Step 3: Save to cache
      await _cacheService.saveRoads(cityId, segments);

      // Step 4: Update state
      state = state.copyWith(
        segments: segments,
        isLoading: false,
      );
    } on OverpassException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load roads: $e',
      );
    }
  }

  // =========================================================================
  // SHARED METHODS (unchanged)
  // =========================================================================

  /// Get a segment by ID.
  RoadSegmentModel? getSegmentById(String segmentId) {
    try {
      return state.segments.firstWhere(
            (segment) => segment.segmentId == segmentId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear all road data.
  void clearRoads() {
    state = const RoadState();
  }
}

// --- Provider ---
final roadProvider =
StateNotifierProvider<RoadNotifier, RoadState>((ref) {
  return RoadNotifier(ref);
});