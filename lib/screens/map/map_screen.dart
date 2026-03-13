// Map Screen — the core visual screen of City Strides.
//
// Displays:
//   - OpenStreetMap base tiles
//   - City boundary polygon (Larissa Centre ring road)
//   - Road segments as coloured polylines (grey=unwalked, green=walked)
//   - User GPS position as a dot
//
// LARISSA CENTRE BOUNDARY (Chat 13):
//   Instead of using an OSM administrative boundary (which is too large),
//   Larissa Centre is defined by its inner ring road:
//     Κίμωνος Σανδράκη → Αθανασίου Λάγου → Ηρώων Πολυτεχνείου
//   The ring road coordinates are fetched from Overpass, stitched into a
//   polygon, and used as both the visual boundary and the area to track.
//
// GPS-TO-TRACKING WIRING:
//   ref.listen connects GPS updates to road matching via the spatial grid.
//   Without this, road segments would never turn green.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/city_provider.dart';
import '../../providers/road_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/tracking_provider.dart';
import '../debug/debug_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;

  // =========================================================================
  // LARISSA CENTRE CONFIGURATION
  // =========================================================================

  // Default map centre — central Larissa.
  // From OSM node 57549546 (the city's main node).
  static const LatLng _defaultCentre = LatLng(39.6383, 22.4161);
  static const double _defaultZoom = 15.0;

  // Unique ID for this custom city definition.
  // Not 'osm_' prefix because this isn't an OSM relation — it's our own
  // custom boundary. This ID is used in the cache directory structure:
  //   cache/cities/larissa_centre/city.json
  //   cache/cities/larissa_centre/roads.json
  static const String _cityId = 'larissa_centre';

  // The three streets that form Larissa's inner ring road.
  // These change name as the road goes around the centre:
  //   Κίμωνος Σανδράκη (west/south side)
  //   → Αθανασίου Λάγου (east side)
  //   → Ηρώων Πολυτεχνείου (north side, along the Pineios river)
  //
  // IMPORTANT: Spelling must match OpenStreetMap EXACTLY.
  // If Overpass returns no results, check the spelling on
  // https://www.openstreetmap.org by searching for these streets.
  static const List<String> _boundaryStreetNames = [
    'Κίμωνος Σανδράκη',
    'Αθανασίου Λάγου',
    'Ηρώων Πολυτεχνείου',
  ];

  // Bounding box for searching — a generous rectangle around Larissa centre.
  // Used for two purposes:
  //   1. Finding the ring road street segments (search area)
  //   2. Fetching all walkable roads within the area
  //
  // This is slightly larger than the ring road itself to ensure:
  //   - All segments of the ring road are found (they might extend slightly
  //     beyond the visual boundary)
  //   - Roads just outside the ring are included (Option A from our discussion)
  //
  // Landmarks for reference:
  //   South (~39.625): below the southern ring road curve
  //   North (~39.650): above Αλκαζάρ park / Πηνειός river
  //   West  (~22.400): west of Νεάπολη
  //   East  (~22.435): east of Ηρώων Πολυτεχνείου
  static const double _bboxSouth = 39.625;
  static const double _bboxWest = 22.400;
  static const double _bboxNorth = 39.650;
  static const double _bboxEast = 22.435;

  // =========================================================================
  // LIFECYCLE
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _wireGpsToTracking();
    });
  }

  /// Loads city boundary and road segments for Larissa Centre.
  ///
  /// Both loads run concurrently — the boundary and roads don't depend
  /// on each other because we use the same predefined bounding box for
  /// both the street search and the road fetch.
  ///
  /// Loading flow:
  ///   cityProvider.loadCustomCity() → fetches ring road geometry → CityModel
  ///   roadProvider.loadRoadsInBbox() → fetches all walkable roads in bbox
  ///   Both check cache first → only hit the API on first run.
  void _loadInitialData() {
    // Load the custom boundary from ring road street names.
    // This calls OverpassService.fetchBoundaryFromStreets() which:
    //   1. Queries Overpass for the 3 street names within our bbox
    //   2. Gets back many small OSM way segments
    //   3. Stitches them into one continuous polygon
    //   4. Returns the polygon as List<LatLng>
    //   5. CityProvider wraps it in a CityModel and caches it
    ref.read(cityProvider.notifier).loadCustomCity(
      cityId: _cityId,
      name: 'Larissa Centre',
      country: 'Greece',
      streetNames: _boundaryStreetNames,
      south: _bboxSouth,
      west: _bboxWest,
      north: _bboxNorth,
      east: _bboxEast,
    );

    // Load all walkable road segments within the bounding box.
    // This uses the new fetchRoadsInBbox() method on OverpassService,
    // which is simpler than the relation-based fetchRoads() — it just
    // asks for all walkable highways inside a rectangle.
    ref.read(roadProvider.notifier).loadRoadsInBbox(
      cityId: _cityId,
      south: _bboxSouth,
      west: _bboxWest,
      north: _bboxNorth,
      east: _bboxEast,
    );

    // Start GPS tracking
    ref.read(locationProvider.notifier).checkPermissions().then((granted) {
      if (granted) {
        ref.read(locationProvider.notifier).startTracking();
      }
    });
  }

  /// Wires GPS updates to the tracking provider for road matching.
  ///
  /// ref.listen vs ref.watch:
  ///   - ref.watch: triggers a full widget rebuild when state changes
  ///   - ref.listen: runs a callback when state changes, WITHOUT rebuilding
  ///
  /// Flow:
  ///   GPS sensor → locationProvider updates currentPosition
  ///     → ref.watch in build() moves the blue dot (visual)
  ///     → ref.listen here calls processPosition() (matching logic)
  ///       → trackingProvider marks segment as walked
  ///         → ref.watch in build() recolours the road green (visual)
  void _wireGpsToTracking() {
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.currentPosition == null) return;
      if (!next.isTracking) return;

      final roadState = ref.read(roadProvider);
      final trackingState = ref.read(trackingProvider);

      // Build the spatial grid once when roads first become available.
      if (roadState.segments.isNotEmpty && !trackingState.isGridReady) {
        ref.read(trackingProvider.notifier).buildGrid(roadState.segments);
      }

      // Pass GPS position to tracking provider for road matching.
      ref.read(trackingProvider.notifier).processPosition(
        next.currentPosition!,
      );
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final cityState = ref.watch(cityProvider);
    final roadState = ref.watch(roadProvider);
    final locationState = ref.watch(locationProvider);
    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Strides'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCentre,
          initialZoom: _defaultZoom,
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          // Layer 1: OpenStreetMap background tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.city_strides',
          ),

          // Layer 2: City boundary polygon (ring road outline)
          if (cityState.currentCity != null)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: cityState.currentCity!.boundaryPolygon,
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),

          // Layer 3: Road segments (grey=unwalked, green=walked)
          if (roadState.segments.isNotEmpty)
            PolylineLayer(
              polylines: roadState.segments.map((segment) {
                final bool isWalked = trackingState.walkedSegmentIds.contains(
                  segment.segmentId,
                );

                return Polyline(
                  points: segment.polyline,
                  color: isWalked ? Colors.green.withValues(alpha: 0.6)
                      : Colors.grey.withValues(alpha: 0.6),
                  strokeWidth: isWalked ? 5.0 : 4.0,
                );
              }).toList(),
            ),

          // Layer 4: User GPS position dot
          if (locationState.currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                    locationState.currentPosition!.latitude,
                    locationState.currentPosition!.longitude,
                  ),
                  width: 20.0,
                  height: 20.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}