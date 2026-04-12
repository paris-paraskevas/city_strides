// Manages app-level settings that are independent of the user's profile.
//
// Settings like GPS accuracy and display units are app preferences,
// not user profile data. Persisted via shared_preferences so they
// survive app restarts.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- State Class ---
class SettingsState {
  final double distanceFilterMeters;
  final String units;

  const SettingsState({
    this.distanceFilterMeters = 5.0,
    this.units = 'km',
  });

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
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadFromPrefs();
  }

  static const _keyDistanceFilter = 'settings_distance_filter';
  static const _keyUnits = 'settings_units';

  /// Loads saved settings from shared_preferences on startup.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final distance = prefs.getDouble(_keyDistanceFilter);
    final units = prefs.getString(_keyUnits);

    state = state.copyWith(
      distanceFilterMeters: distance,
      units: units,
    );
  }

  /// Sets the GPS distance filter (3.0 to 15.0 metres).
  void setDistanceFilter(double meters) {
    final clamped = meters.clamp(3.0, 15.0);
    state = state.copyWith(distanceFilterMeters: clamped);
    _saveDouble(_keyDistanceFilter, clamped);
  }

  /// Sets display units ('km' or 'miles').
  void setUnits(String newUnits) {
    if (newUnits != 'km' && newUnits != 'miles') return;
    state = state.copyWith(units: newUnits);
    _saveString(_keyUnits, newUnits);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

// --- Provider ---
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
