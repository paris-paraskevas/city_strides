// Map Screen — the core visual screen of City Strides.
//
// Displays:
//   - OpenStreetMap base tiles
//   - City boundary polygon (mock Athens)
//   - Road segments as coloured polylines
//   - User GPS position as a dot
//
// Uses ConsumerStatefulWidget because:
//   - initState() is needed to auto-load data on screen open
//   - MapController needs to persist across rebuilds
//   - ref is needed in multiple lifecycle methods
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/city_provider.dart';
import '../../providers/road_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/tracking_provider.dart';
// --- Widget class ---
// This is the "outer shell". Its only job is to create the State object.
// Think of it as the label on a box — actual contents are in _MapScreenState.
//
// ConsumerStatefulWidget = StatefulWidget + Riverpod access.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  // createState() is required by every StatefulWidget.
  // It tells Flutter: "here's the State class that manages this widget."
  // Flutter calls this once when the widget is first inserted into the tree.
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

// --- The State class ---
// This is where all the actual logic and UI lives.
// The underscore prefix (_) makes it private — nothing outside this file
// can reference _MapScreenState directly. This is standard Dart convention
// for State classes.
//
// ConsumerState<MapScreen> gives us:
//   - ref (available everywhere, not just build)
//   - initState(), dispose(), build() lifecycle methods
//   - setState() for local UI state (though we mostly use Riverpod)

class _MapScreenState extends ConsumerState<MapScreen> {

  // MapController lets us programmatically move/zoom the map.
  // We declare it here (not inside build) because:
  //   1. It needs to persist across rebuilds — if we created it in build(),
  //      a new one would be made every time the widget rebuilds, losing
  //      the current map position.
  //   2. We need to access it from multiple methods (initState, build, etc.)
  //
  // "late" means: "I promise this will be initialised before it's used,
  // but I can't initialise it right here at declaration time."
  // We initialise it in initState() below.
  late final MapController _mapController;

  // Default map centre — central Athens.
  // This is where the map will show on first load, before GPS kicks in.
  // We use a static const because this value never changes and can be
  // determined at compile time. "static" means it belongs to the class
  // itself rather than any instance, and "const" means it's a compile-time
  // constant.
  static const LatLng _defaultCentre = LatLng(37.9755, 23.7348);

  // Default zoom level — shows roughly a neighbourhood-scale view.
  // Zoom 15 in OpenStreetMap shows individual streets clearly.
  // Lower numbers = zoomed out (zoom 1 = whole world).
  // Higher numbers = zoomed in (zoom 18 = building level).
  static const double _defaultZoom = 15.0;

  @override
  void initState() {
    super.initState();

    // Create the map controller.
    // This must happen in initState, not at field declaration,
    // because MapController() performs initialisation work that
    // should happen during the widget lifecycle.
    _mapController = MapController();

    // Schedule data loading for after the widget tree is built.
    // Why not call ref.read() directly here?
    // Because during initState(), the widget isn't fully mounted yet.
    // Riverpod's ref needs the widget to be in the tree before it
    // can safely access providers. addPostFrameCallback waits until
    // the first frame is painted, then runs our code.
    //
    // The (_) parameter is a "throwaway" — addPostFrameCallback passes
    // a Duration (how long the frame took), but we don't need it,
    // so we use _ to indicate "ignore this value."
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // --- Load initial data ---
  // Separated into its own method for clarity.
  // This runs once after the screen first appears.
  void _loadInitialData() {
    // Load mock Athens city data (boundary polygon)
    ref.read(cityProvider.notifier).loadMockCity();

    // Load mock road segments for Athens
    ref.read(roadProvider.notifier).loadRoadsForCity('athens_gr');

    // Start GPS tracking
    // checkPermissions() asks the OS for location permission,
    // then startTracking() begins the GPS position stream.
    ref.read(locationProvider.notifier).checkPermissions().then((granted) {
      if (granted) {
        ref.read(locationProvider.notifier).startTracking();
      }
    });
  }

  @override
  void dispose() {
    // Clean up the map controller when the screen is destroyed.
    // This frees memory and prevents leaks.
    // Always dispose controllers you create — it's like closing
    // a file when you're done reading it.
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Watch providers ---
    // ref.watch() subscribes to provider state changes.
    // Every time any of these providers update their state,
    // this build() method runs again with the new data.
    //
    // This is the reactive magic of Riverpod: you don't manually
    // check for changes or call setState(). You just watch, and
    // Flutter handles the rest.
    final cityState = ref.watch(cityProvider);
    final roadState = ref.watch(roadProvider);
    final locationState = ref.watch(locationProvider);
    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Strides'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // For now, just display a placeholder message showing
      // what data is loaded. We'll replace this with the actual
      // FlutterMap widget in Step 2.
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('City: ${cityState.currentCity?.name ?? "Loading..."}'),
            Text('Roads: ${roadState.segments.length} segments'),
            Text('GPS: ${locationState.currentPosition != null ? "Active" : "Waiting..."}'),
            Text('Tracking: ${trackingState.isActive ? "On" : "Off"}'),
          ],
        ),
      ),
    );
  }
}


















