// Manages which city the user is currently in.
//
// Depends on locationProvider to get the user's GPS position.
// Uses OverpassService to fetch real city boundary data from OpenStreetMap.
//
// Two ways to load a city:
//   1. loadCityByRelationId() — fetch by OSM relation ID (for testing/manual)
//   2. detectCity() — auto-detect from GPS position (future implementation)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../services/overpass_service.dart';
import 'location_provider.dart';

// --- State class ---
// Holds the current city (if detected) plus status information.
// UNCHANGED from before — the UI code that reads CityState doesn't
// need to change at all. This is the benefit of the service layer pattern:
// the data source changes, but the state shape stays the same.
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

  // The service instance that handles Overpass API communication.
  // We create it once and reuse it for all requests.
  //
  // New concept — Dependency injection (simple version):
  // The notifier "owns" the service. This keeps the service lifetime
  // tied to the provider. Later, if we wanted to swap in a mock service
  // for testing, we'd pass it in via the constructor instead.
  final OverpassService _overpassService = OverpassService();

  CityNotifier(this._ref) : super(const CityState());

  // --- Load city by OSM relation ID ---
  // Fetches a specific city's boundary from Overpass API.
  // This is our primary method for now (Option C from our discussion).
  //
  // [relationId] — the OpenStreetMap relation ID.
  //   Athens, Greece = 187890
  //   You can find IDs at: https://www.openstreetmap.org
  //
  // New concept — try/catch with custom exceptions:
  // The service throws OverpassException with a human-readable message.
  // We catch it here and store the message in errorMessage so the UI
  // can display it. The "on OverpassException" part means we only
  // catch our specific exception type — other errors bubble up normally.
  Future<void> loadCityByRelationId(int relationId) async {
    // Set loading state — the UI will show a loading indicator
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Call the Overpass service to fetch the real boundary
      final city = await _overpassService.fetchCityBoundary(
        relationId: relationId,
      );

      // Success — update state with the real city data
      state = state.copyWith(
        currentCity: city,
        isLoading: false,
      );
    } on OverpassException catch (e) {
      // Overpass-specific error — show the message to the user
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      // Unexpected error — network failure, JSON parse error, etc.
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load city: $e',
      );
    }
  }

  // --- Detect city from GPS position ---
  // This will eventually:
  //   1. Read the user's current position from locationProvider
  //   2. Query Overpass for city boundaries near that position
  //   3. Set the matching city as currentCity
  //
  // For now, it falls back to loading Athens by relation ID.
  // We'll implement real GPS-based detection in a future chat.
  Future<void> detectCity() async {
    // Read current location (one-time)
    final locationState = _ref.read(locationProvider);

    if (locationState.currentPosition == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No GPS position available. Cannot detect city.',
      );
      return;
    }

    // TODO: Replace with real reverse-geocoding city detection.
    // For now, load Athens as the default city.
    await loadCityByRelationId(187890);
  }

  // --- Manually set city ---
  // Allows the user to select a city from a list instead of
  // relying on GPS detection. Useful for browsing other cities'
  // progress or when GPS detection doesn't work.
  void setCity(CityModel city) {
    state = state.copyWith(
      currentCity: city,
      isLoading: false,
      errorMessage: null,
    );
  }

  // --- Clear city ---
  // Resets to no city selected.
  void clearCity() {
    state = const CityState();
  }
}

// --- Provider ---
// Usage:
//    final cityState = ref.watch(cityProvider);
//    final cityName = cityState.currentCity?.name ?? 'No city';
//
//    // Load Athens by relation ID:
//    ref.read(cityProvider.notifier).loadCityByRelationId(187890);
//
//    // Or auto-detect from GPS:
//    ref.read(cityProvider.notifier).detectCity();
final cityProvider =
StateNotifierProvider<CityNotifier, CityState>((ref) {
  return CityNotifier(ref);
});