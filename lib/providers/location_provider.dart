// Manages GPS location access and provides a stream of position updates.
//
// This provider handles:
//  - Checking and requesting location permissions
//  - Getting the current position (one-time)
//  - Providing a continuous stream of position updates for tracking
//
// Other providers (city_provider, tracking_provider) will depend on
// this to know where the user is.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// --- State class ---
// This holds everything the UI and other providers need to know about
// the user's location. Instead of just storing a Position, we bundle
// it with status info so screens can show appropriate messages
//
// Why a custom class instead of just Position?
// Because we also need to track whether we HAVE permission, whether
// GPS is enabled, and whether we're currently getting updates.
// Bundling it all together keeps things organised.
class LocationState {
  final Position? currentPosition;  // Latest GPS coordinates (null if unknown)
  final bool isTracking;            // Are we actively receiving GPS updates?
  final String? errorMessage;       // Any error (permission denied, GPS off, etc.)

  // const constructor - allows Dart to optimise this object since
  // all fields are known at compile time when using defaults.
  const LocationState({
    this.currentPosition,
    this.isTracking = false,
    this.errorMessage,
  });

  // copyWith for immutable state updates, same pattern as models
  LocationState copyWith({
    Position? currentPosition,
    bool? isTracking,
    String? errorMessage,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isTracking: isTracking ?? this.isTracking,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// --- StateNotifier ---
class LocationNotifier extends StateNotifier<LocationState> {
  // Start with empty state - no position, not tracking, no errors.
  LocationNotifier() : super(const LocationState());

  // _positionSubscription holds the GPS stream listener.
  // The underscore prefix (_) makes it private to this class - nothing
  // outside LocationNotifier can access it directly.
  // StreamSubscription is like a TV subscription: you "subscribe" to
  // receive GPS updates, and can "cancel" when you want to stop.
  dynamic _positionSubscription;

  // --- Check and request permissions ---
  // Returns true if we have permission and GPS is enabled.
  // Returns false and sets an error message if not.
  //
  // "async" means this method does work that takes time (talking to
  // the OS about permissions). It returns a Future<bool> - a promise
  // that will eventually contain true or false.
  // "await" pauses execution until the async work finishes
  Future<bool> checkPermissions() async {
    // Step 1: Is the GPS hardware/service turned on?
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled) {
      state = state.copyWith(
        errorMessage: 'Location services disabled. Please enable GPS.'
      );
      return false;
    }

    // Step 2: Does our app have permission to use location?
    LocationPermission permission = await Geolocator.checkPermission();

    // If we've never asked, ask now.
    if(permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      // If still denied after asking, inform the user.
      if(permission == LocationPermission.denied) {
        state = state.copyWith(
          errorMessage: 'Location permission denied. This app needs GPS to track walks:)'
        );
        return false;
      }
    }

    // "deniedForever" means the user checked "Don't ask again" in the
    // Android permission dialogue. We can't request again - they need to go to
    // phone Settings to enable it manually.
    if(permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        errorMessage: 'Location permission permanently denied. Please enable in phone Settings.'
      );
      return false;
    }

    // If we get here, we have permission! Clear any previous error.
    state = state.copyWith(errorMessage: null);
    return true;
  }

  // --- Get current position (one-time) ---
  // Useful for centering the map on startup.
  // Returns the Position, or null if something went wrong.
  Future<Position?> getCurrentPosition() async {
    // Check permissions first
    final hasPermission = await checkPermissions();
    if(!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high
        ),
      );

      state = state.copyWith(currentPosition: position);
      return position;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to get current position: $e',
      );
      return null;
    }
  }

  // --- Start listening for continuous GPS updates ---
  // This is what runs during a walk. The phone sends position updates
  // every few seconds, and we update state each time.
  //
  // distanceFilter: minimum distance (in meters) between updates.
  // Setting it to 5 means we only get a new position when the user has moved
  // at least 5 metres. This prevents flooding with updates
  // when standing still and saves battery.
  Future<void> startTracking() async {
    // Check permissions first
    final hasPermission = await checkPermissions();
    if(!hasPermission) return;

    // Don't start a second listener if we're already tracking
    if (state.isTracking) return;

    // LocationSettings configures how often and how accurately we
    // receive GPS updates from the device.
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );

    // Geolocator.getPositionStream() return a Stream<Position>.
    // A Stream is like a conveyor belt - it keeps delivering new Position
    // Objects as the user moves.
    //.listen() starts receiving items from the conveyor belt.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      // This function runs every time a new position arrives:
        (Position position) {
          state = state.copyWith(
            currentPosition: position,
            isTracking: true,
          );
        },
        // This function runs if the stream encounters an error:
        onError: (error) {
          state = state.copyWith(
            errorMessage: 'GPS tracking error: $error',
            isTracking: false,
          );
        },
    );

    state = state.copyWith(isTracking: true);
  }

  // --- Stop listening for GPS updates ---
  // Called when the user stops a walk or the app pauses tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    state = state.copyWith(isTracking: false);
  }

  // --- Cleanup ---
  // dispose() is called automatically by Riverpod when this provider
  // is no longer needed. We cancel the GPS stream to prevent memory
  // leaks and battery drain.
  //
  // @override means we're replacing the parent class's dispose method
  // with our own version. super.dispose() calls the original to make
  // sure all cleanup from the parent class also happens.
  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

// --- Provider ---
// Registered with Riverpod so any widget or other provider can access it.
//
// Usage:
//    final locationState = ref.watch(locationProvider);
//    if (locationState.currentPosition != null) {...}
//
//    ref.read(locationProvider.notifier).startTracking();
//    ref.read(locationProvider.notifier).stopTracking();
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState> ((ref) {
  return LocationNotifier();
});