// Calculates the user's walking completion percentage per city.
//
// Depends on:
//    - trackingProvider: for the set of walked segment IDs
//    - roadProvider: for the total number of road segments
//
// This is the provider that drives the main stat the user cares about:
// "I've walked 23% of Athens"
//
// The calculation is simple:
//   completionPercent = (segmentsWalked / totalSegments) * 100
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_progress_model.dart';
import 'tracking_provider.dart';
import 'road_provider.dart';
import 'city_provider.dart';

// --- StateNotifier ---
class ProgressNotifier extends StateNotifier<CityProgressModel?> {
  final Ref _ref;

  // Starts as null — no progress until a city is loaded and
  // tracking data exists.
  ProgressNotifier(this._ref) : super(null);

  // --- Recalculate progress ---
  // Reads the current city, road segments, and walked segments,
  // then calculates the completion percentage.
  //
  // This should be called whenever:
  //   - A new segment is walked (tracking state changes)
  //   - Road data is loaded for a city
  //   - The user switches cities
  void recalculate() {
    // Get current city
    final cityState = _ref.read(cityProvider);
    if (cityState.currentCity == null) {
      state = null;
      return;
    }

    // Get road data
    final roadState = _ref.read(roadProvider);
    if (roadState.segments.isEmpty) {
      state = null;
      return;
    }

    // Get tracking data
    final trackingState = _ref.read(trackingProvider);

    // Count how many segments in THIS city have been walked.
    // We filter by cityId because the user might have walked
    // segments in multiple cities, but we only want the count
    // for the current city.
    //
    // .where() filters a list based on a condition — like SQL WHERE.
    // .length gives us the count of matching items.
    final citySegmentIds = roadState.segments
        .map((segment) => segment.segmentId)
        .toSet();

    // Intersection: segments that are BOTH in this city's roads
    // AND in the walked set. This ensures we only count walks
    // that belong to the current city.
    final walkedInCity = trackingState.walkedSegmentIds
        .intersection(citySegmentIds);

    final int segmentsWalked = walkedInCity.length;
    final int totalSegments = roadState.segments.length;

    // Calculate distance walked by summing the length of each
    // walked segment.
    double distanceWalked = 0.0;
    for (final segmentId in walkedInCity) {
      final segment = _ref.read(roadProvider.notifier)
          .getSegmentById(segmentId);
      if (segment != null) {
        distanceWalked += segment.lengthMeters;
      }
    }

    // Calculate percentage, avoiding division by zero.
    // If there are no road segments, percentage is 0.
    final double percent = totalSegments > 0
        ? (segmentsWalked / totalSegments) * 100
        : 0.0;

    // Update state with the new progress model
    state = CityProgressModel(
      userId: 'local_user',
      cityId: cityState.currentCity!.cityId,
      segmentsWalked: segmentsWalked,
      totalSegments: totalSegments,
      distanceWalkedMeters: distanceWalked,
      completionPercent: percent,
      lastUpdated: DateTime.now(),
    );
  }

  // --- Clear progress ---
  // Resets to null. Used when switching cities or logging out.
  void clearProgress() {
    state = null;
  }
}

// --- Provider ---
// Usage:
//   final progress = ref.watch(progressProvider);
//   if (progress != null) {
//     print('${progress.completionPercent}% complete');
//     print('${progress.segmentsWalked} of ${progress.totalSegments} roads');
//   }
//
//   ref.read(progressProvider.notifier).recalculate();
final progressProvider =
StateNotifierProvider<ProgressNotifier, CityProgressModel?>((ref) {
  return ProgressNotifier(ref);
});