// Bottom sheet for selecting which city to walk in.
//
// Shows all known cities from AppConstants.knownCities.
// Tapping a city loads its boundary, roads, and walked data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/city_provider.dart';
import '../../providers/road_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/progress_provider.dart';

class CityPickerSheet extends ConsumerWidget {
  const CityPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityState = ref.watch(cityProvider);
    final currentCityId = cityState.cityId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select City',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        ...AppConstants.knownCities.map((def) {
          final isSelected = def.cityId == currentCityId;
          return ListTile(
            leading: Icon(
              Icons.location_city,
              color: isSelected ? AppTheme.primary : null,
            ),
            title: Text(
              def.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(def.country),
            trailing: isSelected
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () {
              _selectCity(ref, def);
              Navigator.pop(context);
            },
          );
        }),
        // Detect from GPS button
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(cityProvider.notifier).detectCity();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.gps_fixed),
            label: const Text('Detect from GPS'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _selectCity(WidgetRef ref, CityDefinition def) {
    // Clear old data
    ref.read(trackingProvider.notifier).clearWalkedSegments();
    ref.read(progressProvider.notifier).clearProgress();

    // Load new city boundary + roads.
    // Walked segment restoration is handled by map_screen._restoreWalkedData()
    // which waits for roads to finish loading before restoring + recalculating.
    ref.read(cityProvider.notifier).loadFromDefinition(def);

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
}
