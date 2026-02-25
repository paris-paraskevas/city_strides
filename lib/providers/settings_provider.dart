// Manages app-level settings that are independent of the user's profile.
//
// Why a separate provider from authProvider?
// Settings like GPS accuracy and display units are app preferences,
// not user profile data. If the user logs out, we might still want
// to keep their preferred settings. Keeping them separate follows
// the "single responsibility" principle — each provider manages
// one concern.
//
// Currently stores settings in memory (resets on app restart).
// Later: persist to shared_preferences for settings that survive restarts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- State Class ---
// Holds all the settings values. Immutable — every change creates
// a new SettingsState via copyWith, which triggers Riverpod rebuilds.
//
// This follows the exact same pattern as your other state classes
// (LocationState, CityState, RoadState, TrackingState).
class SettingsState {
  final double distanceFilterMeters;  // GPS update frequency (min metres between updates)
  final String units;                  // 'km' or 'miles' for distance display

  // Constructor with default values.
  // Named parameters with defaults mean you can create a SettingsState
  // without passing anything: SettingsState() gives you the defaults.
  const SettingsState({
    this.distanceFilterMeters = 5.0,   // Default: 5m (matches your current location_provider)
    this.units = 'km',                 // Default: kilometres
  });

  // copyWith — creates a new instance with only the specified fields changed.
  // The ?? operator means: "use the new value if provided, otherwise keep the current one."
  // This is the same pattern used in all your other state classes and models.
  SettingsState copyWith({
    double? distanceFilterMeters,
    String? units,
  }) {
    return SettingsState(
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      units: units ?? this.units,
    );
  }
}

// --- Notifier ---
// Contains methods to modify settings. Each method creates a new
// SettingsState via copyWith, which Riverpod detects as a change
// and rebuilds any widget using ref.watch(settingsProvider).
class SettingsNotifier extends StateNotifier<SettingsState> {
  // super(const SettingsState()) — starts with all default values.
  // Unlike AuthNotifier which starts with null (no user), settings
  // always have a valid state from the start.
  SettingsNotifier() : super(const SettingsState());

  // --- Set GPS Distance Filter ---
  // Controls how far the user must walk before the next GPS update fires.
  // Lower = more accurate but more battery drain.
  // Higher = less accurate but saves battery.
  //
  // Valid range: 3.0 to 15.0 metres.
  // The clamp() method ensures the value stays within bounds even if
  // something unexpected is passed in.
  //
  // clamp(min, max) — returns min if value < min, max if value > max,
  // otherwise returns the value itself. Like a safety guardrail.
  void setDistanceFilter(double meters) {
    state = state.copyWith(
      distanceFilterMeters: meters.clamp(3.0, 15.0),
    );
  }

  // --- Set Display Units ---
  // Switches between 'km' and 'miles' for distance display throughout the app.
  // Only accepts valid values — ignores anything else.
  void setUnits(String newUnits) {
    if (newUnits != 'km' && newUnits != 'miles') return;
    state = state.copyWith(units: newUnits);
  }
}

// --- Provider ---
// Registers SettingsNotifier with Riverpod.
//
// Usage from widgets:
//   final settings = ref.watch(settingsProvider);          // Gets SettingsState, rebuilds on change
//   settings.distanceFilterMeters                          // Read a value
//   settings.units                                         // Read a value
//   ref.read(settingsProvider.notifier).setUnits('miles'); // Change a value
//   ref.read(settingsProvider.notifier).setDistanceFilter(10.0);
final settingsProvider =
StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});