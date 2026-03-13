// Manages which city the user is currently in.
//
// Depends on locationProvider to get the user's GPS position.
// Uses OverpassService to fetch real city boundary data from OpenStreetMap.
// Uses CacheService to store/retrieve city data locally.
//
// Two modes of loading (added in Chat 13):
//   1. By OSM relation ID — for cities with admin boundaries (e.g. Athens)
//   2. By custom street names — for cities where we define the boundary
//      using a ring road perimeter (e.g. Larissa Centre)
//
// Both modes use the same cache-first strategy:
//   Check cache → load from disk (instant) or fetch from API → save to cache

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/city_model.dart';
import '../services/overpass_service.dart';
import '../services/cache_service.dart';
import 'location_provider.dart';

// --- State class ---
// UNCHANGED from previous version.
class CityState {
  final CityModel? currentCity;
  final bool isLoading;
  final String? errorMessage;

  const CityState({
    this.currentCity,
    this.isLoading = false,
    this.errorMessage,
  });

  CityState copyWith({
    CityModel? currentCity,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CityState(
      currentCity: currentCity ?? this.currentCity,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// --- State Notifier ---
class CityNotifier extends StateNotifier<CityState> {
  final Ref _ref;
  final OverpassService _overpassService = OverpassService();
  final CacheService _cacheService = CacheService();

  CityNotifier(this._ref) : super(const CityState());

  // =========================================================================
  // MODE 1: Load by OSM relation ID (existing — for cities like Athens)
  // =========================================================================

  /// Loads a city boundary from an OSM relation.
  /// Cache-first: checks disk before calling API.
  Future<void> loadCityByRelationId(int relationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cityId = 'osm_$relationId';

    try {
      // Step 1: Check cache
      if (await _cacheService.isCityCached(cityId)) {
        final cachedCity = await _cacheService.loadCachedCity(cityId);
        if (cachedCity != null) {
          state = state.copyWith(
            currentCity: cachedCity,
            isLoading: false,
          );
          return;
        }
      }

      // Step 2: Cache miss — fetch from Overpass API
      final city = await _overpassService.fetchCityBoundary(
        relationId: relationId,
      );

      // Step 3: Save to cache
      await _cacheService.saveCity(city);

      // Step 4: Update state
      state = state.copyWith(
        currentCity: city,
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
        errorMessage: 'Failed to load city: $e',
      );
    }
  }

  // =========================================================================
  // MODE 2: Load custom city boundary from street names (new — Chat 13)
  // =========================================================================

  /// Loads a city boundary defined by a ring of named streets.
  ///
  /// This is used when an OSM administrative boundary doesn't exist at
  /// the right scale (e.g. Larissa has a municipality boundary that's
  /// 335 km², but we only want the ~4 km² urban centre).
  ///
  /// [cityId] — unique ID for this custom city (e.g. 'larissa_centre')
  /// [name] — display name (e.g. 'Larissa Centre')
  /// [country] — country name (e.g. 'Greece')
  /// [streetNames] — names of streets forming the boundary ring
  /// [searchBbox] — bounding box to search for those streets within
  ///   (prevents matching streets with the same name in other cities)
  ///
  /// HOW IT WORKS:
  /// 1. Check cache — if we've fetched this boundary before, load it
  /// 2. If not cached — fetch the street geometries from Overpass
  /// 3. OverpassService stitches the OSM way segments into one polygon
  /// 4. Build a CityModel with that polygon
  /// 5. Save to cache for next time
  Future<void> loadCustomCity({
    required String cityId,
    required String name,
    required String country,
    required List<String> streetNames,
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Check cache
      if (await _cacheService.isCityCached(cityId)) {
        final cachedCity = await _cacheService.loadCachedCity(cityId);
        if (cachedCity != null) {
          state = state.copyWith(
            currentCity: cachedCity,
            isLoading: false,
          );
          return;
        }
      }

      // Step 2: Cache miss — fetch street geometries from Overpass
      final boundaryPolygon = await _overpassService.fetchBoundaryFromStreets(
        streetNames: streetNames,
        south: south,
        west: west,
        north: north,
        east: east,
      );

      // Step 3: Build CityModel with the stitched polygon
      final city = CityModel(
        cityId: cityId,
        name: name,
        country: country,
        boundaryPolygon: boundaryPolygon,
        totalRoadSegments: 0,       // Updated after roads load
        totalRoadLengthMeters: 0.0, // Updated after roads load
      );

      // Step 4: Save to cache
      await _cacheService.saveCity(city);

      // Step 5: Update state
      state = state.copyWith(
        currentCity: city,
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
        errorMessage: 'Failed to load city: $e',
      );
    }
  }

  // =========================================================================
  // SHARED METHODS (unchanged)
  // =========================================================================

  /// Detect city from GPS position.
  /// Future implementation — currently falls back to Athens.
  Future<void> detectCity() async {
    final locationState = _ref.read(locationProvider);

    if (locationState.currentPosition == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No GPS position available. Cannot detect city.',
      );
      return;
    }

    // TODO: Replace with real reverse-geocoding city detection.
    await loadCityByRelationId(1370736);
  }

  /// Manually set city (e.g. from a search result).
  void setCity(CityModel city) {
    state = state.copyWith(
      currentCity: city,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// Clear city state.
  void clearCity() {
    state = const CityState();
  }
}

// --- Provider ---
final cityProvider =
StateNotifierProvider<CityNotifier, CityState>((ref) {
  return CityNotifier(ref);
});