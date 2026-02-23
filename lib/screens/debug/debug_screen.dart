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

    // Read current state from each provider
    final user        = ref.watch(authProvider);
    final location    = ref.watch(locationProvider);
    final city        = ref.watch(cityProvider);
    final roads       = ref.watch(roadProvider);
    final tracking    = ref.watch(trackingProvider);
    final progress    = ref.watch(progressProvider);

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
            _row('User ID',       user?.userId ?? 'null'),
            _row('Display Name',  user?.displayName ?? 'null'),

            _section('Location'),
            _row('Status',        location.status.name),
            _row('Latitude',      location.currentPosition?.latitude.toStringAsFixed(6) ?? 'null'),
            _row('Longitude',     location.currentPosition?.longitude.toStringAsFixed(6) ?? 'null'),

            _section('City'),
            _row('Loaded',        city.isLoaded.toString()),
            _row('City Name',     city.currentCity?.name ?? 'null'),
            _row('Boundary pts',  city.currentCity?.boundaryPolygon.length.toString() ?? 'null'),

            _section('Roads'),
            _row('Loaded',        roads.isLoaded.toString()),
            _row('Segment count', roads.segments.length.toString()),

            _section('Tracking'),
            _row('Is tracking',   tracking.isTracking.toString()),
            _row('Segments walked', tracking.walkedSegmentIds.length.toString()),

            _section('Progress'),
            _row('Completion',    progress != null
                ? '${progress.completionPercent.toStringAsFixed(1)}%'
                : 'null'),
            _row('Segments walked', progress?.segmentsWalked.toString() ?? 'null'),
            _row('Total segments',  progress?.totalSegments.toString() ?? 'null'),

            const SizedBox(height: 24),

            // Button to trigger mock city + road load
            ElevatedButton(
              onPressed: () {
                ref.read(cityProvider.notifier).loadMockCity();
                ref.read(roadProvider.notifier).loadRoadsForCity('athens_gr');
              },
              child: const Text('Load Mock Athens Data'),
            ),

            const SizedBox(height: 12),

            // Button to toggle tracking
            ElevatedButton(
              onPressed: () {
                if (tracking.isTracking) {
                  ref.read(trackingProvider.notifier).stopTracking();
                } else {
                  ref.read(trackingProvider.notifier).startTracking();
                }
              },
              child: Text(tracking.isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),

          ],
        ),
      ),
    );
  }

  // Helper: bold section header
  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  // Helper: one labelled row
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