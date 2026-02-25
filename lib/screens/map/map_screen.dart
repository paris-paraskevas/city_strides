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
    // Athens, Greece — OSM relation ID 187890
    // https://www.openstreetmap.org/relation/187890
    const int athensRelationId = 187890;

    // Load real Athens city boundary from Overpass API
    ref.read(cityProvider.notifier).loadCityByRelationId(athensRelationId);

    // Load real road segments for Athens from Overpass API
    // cityId must match what fetchCityBoundary produces: 'osm_187890'
    ref.read(roadProvider.notifier).loadRoadsForCity(
      relationId: athensRelationId,
      cityId: 'osm_$athensRelationId',
    );

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

      // --- The Map ---
      // FlutterMap is the main map widget. It takes:
      //   - mapController: our controller for programmatic map movement
      //   - options: configuration (centre, zoom, limits)
      //   - children: the visual layers stacked on top of each other
      //
      // The children list is ordered bottom-to-top:
      //   First item = bottom layer (tiles), last item = top layer (markers).
      //   This is like stacking transparent sheets on an overhead projector.
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // initialCenter: where the map is centred when it first appears.
          // We use our default Athens coordinates for now.
          // Later, we'll update this to use the user's actual GPS position.
          initialCenter: _defaultCentre,

          // initialZoom: how zoomed in the map starts.
          // 15.0 shows individual streets — good for a walking app.
          initialZoom: _defaultZoom,

          // minZoom / maxZoom: prevents the user from zooming too far
          // in or out. Zoom 3 shows continents, zoom 18 shows buildings.
          // We limit the range to keep the experience sensible for a
          // city-scale walking app.
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          // --- Layer 1: OpenStreetMap Tiles ---
          // This is the background map — streets, buildings, parks, water.
          // Without this layer, you'd see a blank grey canvas.
          //
          // urlTemplate: the URL pattern for downloading tile images.
          //   {s} = subdomain (a, b, or c) — distributes requests across
          //         multiple servers so one server doesn't get overloaded.
          //   {z} = zoom level (0-18)
          //   {x} = tile column number
          //   {y} = tile row number
          //   flutter_map fills these in automatically based on what the
          //   user is looking at.
          //
          // userAgentPackageName: identifies your app to OpenStreetMap's
          //   servers. OSM is free but asks that apps identify themselves
          //   so they can contact you if your app sends too many requests.
          //   This is just good manners — using a fake or missing name
          //   could get your app's requests blocked.
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.city_strides',
          ),
          // --- Layer 2: City Boundary Polygon ---
          // Draws the city boundary as a semi-transparent overlay.
          // This shows the user which area "counts" for their city completion.
          //
          // We only draw it if a city is loaded (currentCity != null).
          // The "if" inside a list is a Dart feature called a
          // "collection if" — it conditionally includes an item in a list.
          // It's like saying: "only add this layer if we have city data."
          //
          // Without the if-check, we'd crash trying to access
          // boundaryPolygon on a null city when the screen first loads
          // (before loadMockCity() completes in addPostFrameCallback).
          if (cityState.currentCity != null)
            PolygonLayer(
              // polygons: a list of Polygon objects to draw.
              // We only have one city at a time, so the list has one item.
              polygons: [
                Polygon(
                  // points: the LatLng coordinates that define the shape.
                  // flutter_map connects them in order and closes the shape
                  // automatically (connects the last point back to the first).
                  points: cityState.currentCity!.boundaryPolygon,

                  // color: the fill colour inside the polygon.
                  // .withValues(alpha: 0.1) makes it nearly transparent.
                  // We use a very light fill so the map tiles underneath
                  // remain visible. Without transparency, the polygon would
                  // cover the map completely and you couldn't see streets.
                  //
                  // Why withValues(alpha:) instead of withOpacity()?
                  // withOpacity is older and works fine, but withValues is
                  // the newer recommended approach in Flutter. alpha: 0.1
                  // means 10% opaque (90% transparent).
                  color: Colors.blue.withValues(alpha: 0.1),

                  // borderColor: the outline colour of the polygon.
                  // A solid blue border makes the boundary clearly visible
                  // even though the fill is very faint.
                  borderColor: Colors.blue,

                  // borderStrokeWidth: how thick the outline is in pixels.
                  // 2.0 is visible without being overwhelming.
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),
          // --- Layer 3: Road Segments ---
          // Draws each road segment as a coloured line on the map.
          // Green = walked, grey = not yet walked.
          //
          // We only draw roads if there are segments loaded.
          // roadState.segments is the list of RoadSegmentModel objects
          // that road_provider loaded (our 3 mock Athens streets).
          if (roadState.segments.isNotEmpty)
            PolylineLayer(
              polylines: roadState.segments.map((segment) {
                // Check if this road has been walked by looking up its ID
                // in the tracking provider's walked segment set.
                // This is the Set<String> we built in Chat 5 — it gives
                // O(1) lookup speed, meaning it's instant regardless of
                // how many segments have been walked.
                final bool isWalked = trackingState.walkedSegmentIds.contains(
                  segment.segmentId,
                );

                return Polyline(
                  // points: the LatLng coordinates that make up this road.
                  // flutter_map draws a line connecting them in order.
                  // Our mock roads have 3 points each, so you'll see
                  // a line with two bends.
                  points: segment.polyline,

                  // color: green if walked, grey if not.
                  // This is a ternary expression: condition ? valueIfTrue : valueIfFalse
                  // It's a compact way to write an if/else that returns a value.
                  color: isWalked ? Colors.green : Colors.grey,

                  // strokeWidth: how thick the road line is in pixels.
                  // 4.0 makes roads clearly visible without dominating the map.
                  // Walked roads are slightly thicker (5.0) to make them
                  // stand out more — a subtle visual reward for progress.
                  strokeWidth: isWalked ? 5.0 : 4.0,
                );
              }).toList(),
            ),
          // --- Layer 4: User GPS Position ---
          // Shows a blue dot where the user currently is.
          //
          // We only show it if we have a GPS position.
          // locationState.currentPosition is null until the GPS
          // gets its first fix (which can take a few seconds after
          // permission is granted).
          if (locationState.currentPosition != null)
            MarkerLayer(
                markers: [
                  Marker(
                    // point: the GPS coordinate where the marker appears.
                    // We create a LatLng from the geolocator Position object.
                    //
                    // locationState.currentPosition is a geolocator Position,
                    // which has .latitude and .longitude properties.
                    // LatLng is flutter_map's coordinate type.
                    // They represent the same thing (a point on Earth) but
                    // come from different packages, so we convert.
                    point: LatLng(
                      locationState.currentPosition!.latitude,
                      locationState.currentPosition!.longitude,
                    ),

                    // width and height: the size of the marker widget in pixels.
                    // This defines the "hit box" — how much space the marker
                    // occupies on screen. The actual visual (our circle below)
                    // should fit within these dimensions.
                    width: 20.0,
                    height: 20.0,

                    // child: the widget to display at this coordinate.
                    // This can be ANY Flutter widget — an Icon, an Image,
                    // a Container, even a button.
                    //
                    // We use a Container styled as a circle:
                    //   - BoxDecoration with shape: BoxShape.circle makes
                    //     the container round instead of rectangular.
                    //   - Blue fill with a white border creates the classic
                    //     "GPS dot" look you see in Google Maps and similar apps.
                    //   - The border gives contrast against any map background
                    //     colour, so the dot is always visible whether it's
                    //     over a park (green), water (blue), or road (white).
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        )
                      ),
                    )
                  )
            ])
        ],
      )
    );
  }
}


















