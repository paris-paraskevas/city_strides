// Manages road segment data for the current city.
//
// Depends on cityProvider to know which city's roads to load.
// Uses OverpassService to fetch real road data from OpenStreetMap.
//
// Roads are fetched separately from city boundaries (two-query strategy)
// so the map can show the city outline while roads load in the background.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/road_segment_model.dart';
import '../services/overpass_service.dart';

// --- State class ---
// UNCHANGED — the UI code that reads RoadState doesn't need any changes.
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

  RoadNotifier(this._ref) : super(const RoadState());

  // --- Load roads for a city by OSM relation ID ---
  // Fetches all walkable road segments within a city's boundaries
  // from the Overpass API.
  //
  // [relationId] — the OpenStreetMap relation ID for the city.
  // [cityId] — the cityId string to assign to each segment
  //   (should match CityModel.cityId, e.g. 'osm_187890').
  //
  // Note: This can take 10-30+ seconds for large cities like Athens
  // because there are thousands of road segments to download and parse.
  // The isLoading flag lets the UI show a progress indicator.
  Future<void> loadRoadsForCity({
    required int relationId,
    required String cityId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final segments = await _overpassService.fetchRoads(
        relationId: relationId,
        cityId: cityId,
      );

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
  // Useful when tracking_provider needs to look up a specific
  // segment that the user just walked.
  // Returns null if the segment isn't found.
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
  // Resets to empty state. Called when the user leaves a city
  // or when we need to load a different city's roads.
  void clearRoads() {
    state = const RoadState();
  }
}

// --- Provider ---
// Usage:
//    final roadState = ref.watch(roadProvider);
//    final totalRoads = roadState.segments.length;
//
//    ref.read(roadProvider.notifier).loadRoadsForCity(
//      relationId: 187890,
//      cityId: 'osm_187890',
//    );
final roadProvider =
StateNotifierProvider<RoadNotifier, RoadState>((ref) {
  return RoadNotifier(ref);
});