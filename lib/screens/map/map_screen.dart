// Map Screen — the core visual screen of City Strides.
//
// Displays:
//   - OpenStreetMap base tiles
//   - City boundary polygon
//   - Road segments as coloured polylines (grey=unwalked, green=walked)
//   - User GPS position as a dot
//
// City data is loaded from CityDefinition (see config/constants.dart).
// Camera centres on user GPS position if available, otherwise city default.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/city_provider.dart';
import '../../providers/road_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/progress_provider.dart';
import '../../config/constants.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/common/loading_indicator.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  ProviderSubscription<RoadState>? _roadSubscription;

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
      _wireCitySwitching();
    });
  }

  /// Loads city data for the given definition, or the default city.
  void _loadInitialData([CityDefinition? def]) {
    final city = def ?? AppConstants.knownCities.first;

    // Load city boundary + road segments via CityDefinition
    ref.read(cityProvider.notifier).loadFromDefinition(city);
    _loadRoadsForDefinition(city);

    // Start GPS tracking
    ref.read(locationProvider.notifier).checkPermissions().then((granted) {
      if (granted) {
        ref.read(locationProvider.notifier).startTracking();
      }
    });

    // Restore walked segments from disk once roads are available.
    _restoreWalkedData();
  }

  /// Loads road segments based on the CityDefinition type.
  void _loadRoadsForDefinition(CityDefinition def) {
    if (def.type == CityType.relation && def.relationId != null) {
      ref.read(roadProvider.notifier).loadRoadsForCity(
        relationId: def.relationId!,
        cityId: def.cityId,
      );
    } else if (def.bboxSouth != null) {
      ref.read(roadProvider.notifier).loadRoadsInBbox(
        cityId: def.cityId,
        south: def.bboxSouth!,
        west: def.bboxWest!,
        north: def.bboxNorth!,
        east: def.bboxEast!,
      );
    }
  }

  /// Loads previously walked segments from disk after roads are available.
  void _restoreWalkedData() {
    // Cancel any previous listener (e.g. from a city switch)
    _roadSubscription?.close();
    _roadSubscription = null;

    // If roads are already loaded, restore immediately
    final roadState = ref.read(roadProvider);
    if (roadState.segments.isNotEmpty && !roadState.isLoading) {
      _loadAndRecalculate();
      return;
    }

    // Otherwise wait for roads to finish loading
    _roadSubscription = ref.listenManual<RoadState>(roadProvider, (previous, next) {
      if (next.segments.isNotEmpty && !next.isLoading) {
        _roadSubscription?.close();
        _roadSubscription = null;
        _loadAndRecalculate();
      }
    });
  }

  Future<void> _loadAndRecalculate() async {
    final cityId = ref.read(cityProvider).cityId;
    if (cityId == null) return;
    await ref.read(trackingProvider.notifier).loadPersistedSegments(cityId);
    ref.read(progressProvider.notifier).recalculate();
  }

  /// Re-runs walked data restoration when the selected city changes.
  void _wireCitySwitching() {
    ref.listenManual<CityState>(cityProvider, (previous, next) {
      final prevId = previous?.selectedDefinition?.cityId;
      final nextId = next.selectedDefinition?.cityId;
      if (prevId != null && nextId != null && prevId != nextId) {
        _restoreWalkedData();
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
    _roadSubscription?.close();
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

    return _buildBody(cityState, roadState, locationState, trackingState);
  }

  /// Returns initial map centre: user GPS position if available,
  /// otherwise the selected city centre, otherwise Larissa fallback.
  LatLng _getInitialCentre() {
    final pos = ref.read(locationProvider).currentPosition;
    if (pos != null) {
      return LatLng(pos.latitude, pos.longitude);
    }
    final def = ref.read(cityProvider).selectedDefinition;
    if (def != null) {
      return def.defaultCentre;
    }
    return AppConstants.defaultFallbackCentre;
  }

  double _getInitialZoom() {
    final def = ref.read(cityProvider).selectedDefinition;
    return def?.defaultZoom ?? AppConstants.defaultFallbackZoom;
  }

  Widget _buildBody(
    CityState cityState,
    RoadState roadState,
    LocationState locationState,
    TrackingState trackingState,
  ) {
    // Show error if city or road loading failed
    final error = cityState.errorMessage ?? roadState.errorMessage;
    if (error != null) {
      return ErrorDisplay(
        message: error,
        onRetry: () => _loadInitialData(),
      );
    }

    // Show loading indicator while data loads
    if (cityState.isLoading || roadState.isLoading) {
      return const LoadingIndicator(label: 'Loading city data...');
    }

    return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _getInitialCentre(),
          initialZoom: _getInitialZoom(),
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
    );
  }
}