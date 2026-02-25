// Manages which city the user is currently in.
//
// Depends on locationProvider to get the user's GPS position.
// Uses OverpassService to fetch real city boundary data from OpenStreetMap.
// Uses CacheService to store/retrieve city data locally.
//
// Data flow:
//   1. Check cache for city data
//   2. If cached → load from disk (instant)
//   3. If not cached → fetch from Overpass API → save to cache → display

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../services/overpass_service.dart';
import '../services/cache_service.dart';
import 'location_provider.dart';

// --- State class ---
// UNCHANGED — no UI changes needed.
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

  // --- Load city by OSM relation ID ---
  // Now with caching:
  //   1. Build the cityId from the relation ID
  //   2. Check if city.json exists in cache
  //   3. If yes → load from cache (fast, no internet needed)
  //   4. If no → fetch from Overpass API → save to cache
  Future<void> loadCityByRelationId(int relationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // The cityId format matches what OverpassService produces
    final cityId = 'osm_$relationId';

    try {
      // Step 1: Check cache
      if (await _cacheService.isCityCached(cityId)) {
        // Cache hit — load from disk
        final cachedCity = await _cacheService.loadCachedCity(cityId);

        if (cachedCity != null) {
          state = state.copyWith(
            currentCity: cachedCity,
            isLoading: false,
          );
          return; // Done — no need to call the API
        }
        // If loadCachedCity returned null (corrupt file), fall through
        // to fetch from API below.
      }

      // Step 2: Cache miss — fetch from Overpass API
      final city = await _overpassService.fetchCityBoundary(
        relationId: relationId,
      );

      // Step 3: Save to cache for next time
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

  // --- Detect city from GPS position ---
  // Future implementation — currently falls back to Athens.
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

  // --- Manually set city ---
  void setCity(CityModel city) {
    state = state.copyWith(
      currentCity: city,
      isLoading: false,
      errorMessage: null,
    );
  }

  // --- Clear city ---
  void clearCity() {
    state = const CityState();
  }
}

// --- Provider ---
// Usage:
//    final cityState = ref.watch(cityProvider);
//    ref.read(cityProvider.notifier).loadCityByRelationId(1370736);
final cityProvider =
StateNotifierProvider<CityNotifier, CityState>((ref) {
  return CityNotifier(ref);
});