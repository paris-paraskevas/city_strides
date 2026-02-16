// Manages which city the user is currently in.
//
// Depends on locationProvider to get the user's GPS position.
// Uses city boundary data to determine which city contains that position
//
// Currently uses a hardcoded city for development.
// Later: will query the Overpass API for city boundaries and use
// point-in-polygon checks to detect the current city.

  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:latlong2/latlong.dart';
  import '../models/city_model.dart';
  import 'location_provider.dart';

  // --- State class ---
  // Holds the current city (if detected) plus status information
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
    // The Ref lets this provider read other providers.
    // This is how providers communicate with each other in Riverpod
    // We store it so we can access locationProvider from our methods.
    final Ref _ref;

    CityNotifier(this._ref) : super(const CityState());

    // -- Load mock city for development ---
    // Creates a hardcoded Athens city for testing.
    // Later: this will be replaced by real Overpass API lookups.
    //
    // The boundary polygon is a simplified rectangle - the real one
    // from OpenStreetMap will have hundreds of points
    void loadMockCity() {
      state = state.copyWith(
        currentCity: CityModel(
            cityId: 'athens_gr',
            name: 'Athens',
            country: 'Greece',
            boundaryPolygon: [
              LatLng(37.95, 23.70),   // NW corner
              LatLng(37.95, 23.76),   // NE corner
              LatLng(37.97, 23.76),   // SE corner
              LatLng(37.97, 23.70),   // SW corner
            ],
          totalRoadSegments: 0,       // Unknown until we fetch road data
          totalRoadLengthMeters: 0.0,
        ),
        isLoading: false,
      );
    }

    // --- Detect city from GPS position ---
    // This is the method that will eventually:
    //  1. Read the user's current position from locationProvider
    //  2. Query the Overpass API for city boundaries near that position
    //  3. Check which boundary polygon contains the position
    //  4. Set the matching city as currentCity
    //
    //  For now, it just loads the mock city.
    Future<void> detectCity() async {
      state = state.copyWith(isLoading: true);

      // Read current location (one-time)
      final locationState = _ref.read(locationProvider);

      if(locationState.currentPosition == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No GPS position available. Cannot detect city.',
        );
        return;
      }

      // TODO: Replace with real Overpass API city boundary lookup
      // For now, just load the mock city regardless of position
      loadMockCity();
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
// Notice the (ref) parameter - we pass it to CityNotifier so it can
// access other providers. This is the standard Riverpod pattern for
// provider-to-provider communication.
//
// Usage:
//    final cityState = ref.watch(cityProvider);
//    final cityName = cityState.currentCity?.name ?? 'No city';
//
//    ref.read(cityProvider.notifier).detectCity();
final cityProvider =
    StateNotifierProvider<CityNotifier, CityState>((ref) {
  return CityNotifier(ref);
});
