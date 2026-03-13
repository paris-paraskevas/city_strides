import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/road_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/tracking_provider.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final user     = ref.watch(authProvider);
    final location = ref.watch(locationProvider);
    final city     = ref.watch(cityProvider);
    final roads    = ref.watch(roadProvider);
    final tracking = ref.watch(trackingProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Strides — Debug'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _section('Auth'),
            _row('User ID',      user?.userId ?? 'null'),
            _row('Display Name', user?.displayName ?? 'null'),

            _section('Location'),
            _row('Is tracking',  location.isTracking.toString()),
            _row('Latitude',     location.currentPosition?.latitude.toStringAsFixed(6) ?? 'null'),
            _row('Longitude',    location.currentPosition?.longitude.toStringAsFixed(6) ?? 'null'),
            _row('Error',        location.errorMessage ?? 'none'),

            _section('City'),
            _row('Detected',     (city.currentCity != null).toString()),
            _row('City Name',    city.currentCity?.name ?? 'null'),
            _row('City ID',      city.currentCity?.cityId ?? 'null'),
            _row('Country',      city.currentCity?.country ?? 'null'),
            _row('Boundary pts', city.currentCity?.boundaryPolygon.length.toString() ?? 'null'),
            _row('Loading',      city.isLoading.toString()),
            _row('Error',        city.errorMessage ?? 'none'),

            _section('Roads'),
            _row('Segments loaded', roads.segments.length.toString()),
            _row('Loading',         roads.isLoading.toString()),
            _row('Error',           roads.errorMessage ?? 'none'),

            _section('Tracking'),
            _row('Is active',       tracking.isActive.toString()),
            _row('Grid ready',      tracking.isGridReady.toString()),
            _row('Segments walked', tracking.walkedSegmentIds.length.toString()),

            _section('Progress'),
            _row('Completion',      progress != null
                ? '${progress.completionPercent.toStringAsFixed(1)}%'
                : 'null'),
            _row('Segments walked', progress?.segmentsWalked.toString() ?? 'null'),
            _row('Total segments',  progress?.totalSegments.toString() ?? 'null'),

            const SizedBox(height: 24),

            // --- Load Larissa Centre Data ---
            // Uses the custom boundary approach: ring road streets + bbox
            ElevatedButton(
              onPressed: () {
                ref.read(cityProvider.notifier).loadCustomCity(
                  cityId: 'larissa_centre',
                  name: 'Larissa Centre',
                  country: 'Greece',
                  streetNames: const [
                    'Κίμωνος Σανδράκη',
                    'Αθανασίου Λάγου',
                    'Ηρώων Πολυτεχνείου',
                  ],
                  south: 39.625,
                  west: 22.400,
                  north: 39.650,
                  east: 22.435,
                );
                ref.read(roadProvider.notifier).loadRoadsInBbox(
                  cityId: 'larissa_centre',
                  south: 39.625,
                  west: 22.400,
                  north: 39.650,
                  east: 22.435,
                );
              },
              child: const Text('Load Larissa Centre Data'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                if (tracking.isActive) {
                  ref.read(trackingProvider.notifier).stopTracking();
                } else {
                  ref.read(trackingProvider.notifier).startTracking();
                }
              },
              child: Text(tracking.isActive ? 'Stop Tracking' : 'Start Tracking'),
            ),

          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ],
    ),
  );
}