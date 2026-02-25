import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/city_provider.dart';
import '../../providers/progress_provider.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Latest'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLatestTab(),
          _buildAllTimeTab(),
        ],
      ),
    );
  }

  // --- Latest Tab ---
  // Shows stats for the current city the user is in.
  // Reads from cityProvider (for city name/country) and
  // progressProvider (for completion %, segments, distance).
  Widget _buildLatestTab() {
    final cityState = ref.watch(cityProvider);
    final progress = ref.watch(progressProvider);

    // Defensive state: no city loaded yet
    if (cityState.currentCity == null) {
      return const Center(
        child: Text(
          'Start walking to see your stats!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    // Defensive state: city loaded but no progress data yet
    if (progress == null) {
      return const Center(
        child: Text(
          'No progress recorded yet.\nStart walking to track your stats!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    final city = cityState.currentCity!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildCityStatsCard(
        country: city.country,
        cityName: city.name,
        completionPercent: progress.completionPercent,
        segmentsWalked: progress.segmentsWalked,
        totalSegments: progress.totalSegments,
        distanceWalkedMeters: progress.distanceWalkedMeters,
      ),
    );
  }

  // --- All Time Tab ---
  // Shows all cities the user has walked in, grouped by country.
  // Currently only mock Athens data exists — this will auto-populate
  // when more cities are added later.
  //
  // For now: reads the same single city + progress from providers.
  // Later: will read from a list of all CityProgressModels.
  Widget _buildAllTimeTab() {
    final cityState = ref.watch(cityProvider);
    final progress = ref.watch(progressProvider);

    // Defensive: no data at all
    if (cityState.currentCity == null || progress == null) {
      return const Center(
        child: Text(
          'No cities walked yet.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    // Only show cities where segmentsWalked > 0
    if (progress.segmentsWalked == 0) {
      return const Center(
        child: Text(
          'No cities walked yet.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    final city = cityState.currentCity!;

    // Group cities by country.
    // Right now we only have one city (Athens), so there's one group.
    // Later when we have a List<CityProgressModel>, we'll use
    // a Map<String, List<CityProgressModel>> grouped by country.
    // The structure is built to support that expansion.

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country header
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              city.country,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // City ExpansionTile
          Card(
            child: ExpansionTile(
              title: Text(city.name),
              subtitle: Text(
                '${progress.completionPercent.toStringAsFixed(1)}% complete',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCityStatsCard(
                    country: city.country,
                    cityName: city.name,
                    completionPercent: progress.completionPercent,
                    segmentsWalked: progress.segmentsWalked,
                    totalSegments: progress.totalSegments,
                    distanceWalkedMeters: progress.distanceWalkedMeters,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable city stats card ---
  // Used by both the Latest tab and inside each ExpansionTile
  // in the All Time tab. Keeps the layout consistent.
  Widget _buildCityStatsCard({
    required String country,
    required String cityName,
    required double completionPercent,
    required int segmentsWalked,
    required int totalSegments,
    required double distanceWalkedMeters,
  }) {
    // Convert metres to kilometres
    final distanceKm = distanceWalkedMeters / 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country name — H1 style
        Text(
          country,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),

        // City name — H2 style
        Text(
          cityName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),

        // Completion percentage text
        Text(
          '${completionPercent.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),

        // Linear progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: completionPercent/100,
            minHeight: 12,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
        const SizedBox(height: 16),

        // Segments walked / total
        Text(
          '$segmentsWalked / $totalSegments segments',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),

        // Distance walked in km
        Text(
          '${distanceKm.toStringAsFixed(2)} km walked',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}