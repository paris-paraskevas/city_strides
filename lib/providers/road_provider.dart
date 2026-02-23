// Manages road segment data for the current city.
//
// Depends on cityProvider to know which city's roads to load.
// Roads are fetched from OpenStreetMap via the Overpass API
//
// Currently uses hardcoded mock road segments for development.
// Later: will call overpass_service.dart to fetch real road data.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/road_segment_model.dart';

// --- State class ---
// Holds the list of road segments for the current city,
// plus loading and error status.
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

  RoadNotifier(this._ref) : super(const RoadState());

  // --- Load roads for a city ---
  // Fetches all road segments within a city's boundaries.
  //
  // Currently loads mock data for Athens.
  // Later: will call overpass_service.dart with the city's boundary
  // polygon to fetch real road segments from OpenStreetMap.
  //
  // The cityId parameter tells us which city to load roads for.
  // This matters because we'll cache roads per city — if the user
  // switches cities, we load different roads.
  Future<void> loadRoadsForCity(String cityId) async {
    state = state.copyWith(isLoading: true);

    // TODO: Replace with real Overpass API call via overpass_service.dart
    // Real implementation will:
    //        1. Build an Overpass QL query for roads within the city boundary
    //        2. Send HTTP request to Overpass API
    //        3. Parse the response into RoadSegmentModel objects
    //        4. Calculate lengthMeters for each segment
    //        5. Cache the results locally so we don't re-fetch every session

    // Mock data: 3 fake road segments in Athens
    final mockSegments = [
      RoadSegmentModel(
          segmentId: 'osm_101',
          cityId: cityId,
          name: 'Ermou Street',
          polyline: [
            LatLng(37.9755, 23.7275),
            LatLng(37.9758, 23.7310),
            LatLng(37.9760, 23.7348),
          ],
          lengthMeters: 650.0,
      ),
      RoadSegmentModel(
        segmentId: 'osm_102',
        cityId: cityId,
        name: 'Stadiou Street',
        polyline: [
          LatLng(37.9780, 23.7290),
          LatLng(37.9785, 23.7335),
          LatLng(37.9788, 23.7370),
        ],
        lengthMeters: 720.0,
      ),
      RoadSegmentModel(
        segmentId: 'osm_103',
        cityId: cityId,
        name: 'Panepistimiou Street',
        polyline: [
          LatLng(37.9795, 23.7285),
          LatLng(37.9798, 23.7325),
          LatLng(37.9800, 23.7360),
        ],
        lengthMeters: 680.0,
      ),
    ];

    state = state.copyWith(
      segments: mockSegments,
      isLoading: false,
      errorMessage: null,
    );
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
//    ref.read(roadProvider.notifier).loadRoadsForCity('athens_gr');
final roadProvider =
    StateNotifierProvider<RoadNotifier, RoadState>((ref) {
  return RoadNotifier(ref);
    });