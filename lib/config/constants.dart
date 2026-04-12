// App-wide constants and city definitions.
//
// CityDefinition holds everything needed to load and display a city:
// boundary data, road data, map camera defaults, and metadata.
//
// Two loading modes:
//   - custom: boundary from named streets + bbox (e.g. Larissa Centre)
//   - relation: boundary from OSM relation ID (e.g. Athens)
//
// To add a new city, add a CityDefinition entry to knownCities.

import 'package:latlong2/latlong.dart';

enum CityType { custom, relation }

class CityDefinition {
  final String cityId;
  final String name;
  final String country;
  final CityType type;
  final LatLng defaultCentre;
  final double defaultZoom;

  // For relation-based cities (e.g. Athens)
  final int? relationId;

  // For custom-boundary cities (e.g. Larissa Centre)
  final List<String>? streetNames;
  final double? bboxSouth;
  final double? bboxWest;
  final double? bboxNorth;
  final double? bboxEast;

  const CityDefinition({
    required this.cityId,
    required this.name,
    required this.country,
    required this.type,
    required this.defaultCentre,
    this.defaultZoom = 15.0,
    this.relationId,
    this.streetNames,
    this.bboxSouth,
    this.bboxWest,
    this.bboxNorth,
    this.bboxEast,
  });
}

class AppConstants {
  AppConstants._();

  static const String appVersion = '0.14.0';

  /// Default fallback centre (Larissa Centre) when GPS is unavailable.
  static const LatLng defaultFallbackCentre = LatLng(39.6383, 22.4161);
  static const double defaultFallbackZoom = 15.0;

  static const List<CityDefinition> knownCities = [
    // Larissa Centre — custom boundary from ring road streets
    CityDefinition(
      cityId: 'larissa_centre',
      name: 'Larissa Centre',
      country: 'Greece',
      type: CityType.custom,
      defaultCentre: LatLng(39.6383, 22.4161),
      defaultZoom: 15.0,
      streetNames: [
        '\u039A\u03AF\u03BC\u03C9\u03BD\u03BF\u03C2 \u03A3\u03B1\u03BD\u03B4\u03C1\u03AC\u03BA\u03B7',
        '\u0391\u03B8\u03B1\u03BD\u03B1\u03C3\u03AF\u03BF\u03C5 \u039B\u03AC\u03B3\u03BF\u03C5',
        '\u0397\u03C1\u03CE\u03C9\u03BD \u03A0\u03BF\u03BB\u03C5\u03C4\u03B5\u03C7\u03BD\u03B5\u03AF\u03BF\u03C5',
      ],
      bboxSouth: 39.625,
      bboxWest: 22.400,
      bboxNorth: 39.650,
      bboxEast: 22.435,
    ),
  ];
}
