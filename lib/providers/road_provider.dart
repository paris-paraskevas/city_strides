// Manages road segment data for the current city.
//
// Depends on cityProvider to know which city's roads to load.
// Uses OverpassService to fetch real road data from OpenStreetMap.
// Uses CacheService to store/retrieve road data locally.
//
// Data flow:
//   1. Check cache for road data
//   2. If cached → load from disk (instant, even for 14k+ segments)
//   3. If not cached → fetch from Overpass API → save to cache → display

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/road_segment_model.dart';
import '../services/overpass_service.dart';
import '../services/cache_service.dart';

// --- State class ---
// UNCHANGED — no UI changes needed.
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

  // --- Load roads for a city by OSM relation ID ---
  // Now with caching:
  //   1. Check if roads.json exists in cache for this city
  //   2. If yes → load from cache (fast)
  //   3. If no → fetch from Overpass API → save to cache
  Future<void> loadRoadsForCity({
    required int relationId,
    required String cityId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Check cache
      if (await _cacheService.areRoadsCached(cityId)) {
        // Cache hit — load from disk
        final cachedRoads = await _cacheService.loadCachedRoads(cityId);

        if (cachedRoads != null) {
          state = state.copyWith(
            segments: cachedRoads,
            isLoading: false,
          );
          return; // Done — no API call needed
        }
        // If loadCachedRoads returned null (corrupt file), fall through
        // to fetch from API below.
      }

      // Step 2: Cache miss — fetch from Overpass API
      final segments = await _overpassService.fetchRoads(
        relationId: relationId,
        cityId: cityId,
      );

      // Step 3: Save to cache for next time
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

  // --- Get a segment by ID ---
  RoadSegmentModel? getSegmentById(String segmentId) {
    try {
      return state.segments.firstWhere(
            (segment) => segment.segmentId == segmentId,
      );
    } catch (e) {
      return null;
    }
  }

  // --- Clear roads ---
  void clearRoads() {
    state = const RoadState();
  }
}

// --- Provider ---
// Usage:
//    final roadState = ref.watch(roadProvider);
//    ref.read(roadProvider.notifier).loadRoadsForCity(
//      relationId: 1370736,
//      cityId: 'osm_1370736',
//    );
final roadProvider =
StateNotifierProvider<RoadNotifier, RoadState>((ref) {
  return RoadNotifier(ref);
});