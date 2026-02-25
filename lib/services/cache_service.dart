// Service for caching city boundary and road segment data locally.
//
// Saves Overpass API responses as JSON files on the device so the app
// doesn't need to re-download thousands of road segments every time
// it starts.
//
// File structure on device:
//   app_data/cache/cities/osm_1370736/city.json
//   app_data/cache/cities/osm_1370736/roads.json
//
// Each city gets its own folder by cityId. This means:
//   - Multiple cities cached independently
//   - Clearing one city doesn't affect others
//   - Check if cached by checking if the folder/file exists
//
// Usage:
//   final cache = CacheService();
//   final cached = await cache.isCityCached('osm_1370736');
//   if (cached) {
//     final city = await cache.loadCachedCity('osm_1370736');
//     final roads = await cache.loadCachedRoads('osm_1370736');
//   }

import 'dart:convert'; // jsonEncode / jsonDecode
import 'dart:io';      // File, Directory — filesystem access

import 'package:path_provider/path_provider.dart'; // Gets app's local storage path

import '../models/city_model.dart';
import '../models/road_segment_model.dart';

class CacheService {

  // =========================================================================
  // PUBLIC METHODS — CHECK CACHE
  // =========================================================================

  /// Checks whether a city's boundary data is cached locally.
  ///
  /// [cityId] — e.g. 'osm_1370736'
  /// Returns true if city.json exists for this city.
  Future<bool> isCityCached(String cityId) async {
    final file = await _getCityFile(cityId);
    return file.existsSync();
  }

  /// Checks whether a city's road data is cached locally.
  ///
  /// [cityId] — e.g. 'osm_1370736'
  /// Returns true if roads.json exists for this city.
  Future<bool> areRoadsCached(String cityId) async {
    final file = await _getRoadsFile(cityId);
    return file.existsSync();
  }

  // =========================================================================
  // PUBLIC METHODS — SAVE TO CACHE
  // =========================================================================

  /// Saves a CityModel to the local cache as JSON.
  ///
  /// Creates the directory structure if it doesn't exist yet.
  ///
  /// New concept — File I/O in Dart:
  /// Dart's dart:io library provides File and Directory classes for
  /// reading/writing files. These are async operations (the device's
  /// storage is slower than memory), so we use await.
  ///
  /// file.writeAsString() writes text to a file, creating it if it
  /// doesn't exist or overwriting if it does.
  Future<void> saveCity(CityModel city) async {
    final file = await _getCityFile(city.cityId);

    // Create the directory if it doesn't exist.
    // recursive: true means it creates parent directories too.
    // Without this, writing to cache/cities/osm_1370736/city.json
    // would fail if cache/cities/osm_1370736/ doesn't exist yet.
    await file.parent.create(recursive: true);

    // Convert the CityModel to JSON string and write it.
    // city.toJson() gives us a Map, jsonEncode turns it into a String.
    final jsonString = jsonEncode(city.toJson());
    await file.writeAsString(jsonString);
  }

  /// Saves a list of RoadSegmentModels to the local cache as JSON.
  ///
  /// This file can be several MB for large cities (14k+ segments),
  /// but that's fine for local storage.
  Future<void> saveRoads(String cityId, List<RoadSegmentModel> roads) async {
    final file = await _getRoadsFile(cityId);
    await file.parent.create(recursive: true);

    // Convert each road to JSON, then wrap in a list.
    // .map() transforms each RoadSegmentModel into a Map via toJson().
    // jsonEncode turns the whole list of Maps into a JSON string.
    final jsonList = roads.map((road) => road.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await file.writeAsString(jsonString);
  }

  // =========================================================================
  // PUBLIC METHODS — LOAD FROM CACHE
  // =========================================================================

  /// Loads a cached CityModel from local storage.
  ///
  /// Returns null if the file doesn't exist or can't be parsed.
  /// The provider should check isCityCached() first, but we handle
  /// the null case defensively just in case.
  Future<CityModel?> loadCachedCity(String cityId) async {
    try {
      final file = await _getCityFile(cityId);

      if (!file.existsSync()) return null;

      // Read the JSON string from the file
      final jsonString = await file.readAsString();

      // Decode the string into a Map, then construct a CityModel
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return CityModel.fromJson(jsonMap);
    } catch (e) {
      // If anything goes wrong (corrupt file, format change, etc.),
      // return null and let the provider re-fetch from the API.
      return null;
    }
  }

  /// Loads cached road segments from local storage.
  ///
  /// Returns null if the file doesn't exist or can't be parsed.
  Future<List<RoadSegmentModel>?> loadCachedRoads(String cityId) async {
    try {
      final file = await _getRoadsFile(cityId);

      if (!file.existsSync()) return null;

      final jsonString = await file.readAsString();

      // The JSON is a list of road objects.
      // jsonDecode gives us a List<dynamic>, and we convert each
      // item to a RoadSegmentModel via fromJson().
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) =>
          RoadSegmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // PUBLIC METHODS — CLEAR CACHE
  // =========================================================================

  /// Deletes all cached data for a specific city.
  ///
  /// Removes the entire city folder (city.json + roads.json).
  Future<void> clearCityCache(String cityId) async {
    final dir = await _getCityDirectory(cityId);
    if (dir.existsSync()) {
      // recursive: true deletes the folder and everything inside it.
      await dir.delete(recursive: true);
    }
  }

  /// Deletes ALL cached city data.
  ///
  /// Useful for a "clear all data" button in settings.
  Future<void> clearAllCache() async {
    final dir = await _getCacheRootDirectory();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  // =========================================================================
  // PRIVATE METHODS — FILE PATHS
  // =========================================================================

  /// Gets the root cache directory: app_data/cache/cities/
  ///
  /// New concept — path_provider:
  /// getApplicationDocumentsDirectory() returns the app's private storage
  /// folder. On Android this is something like:
  ///   /data/data/com.example.city_strides/app_flutter/
  /// Each app gets its own folder — other apps can't access it.
  /// Files here persist until the app is uninstalled or explicitly deleted.
  Future<Directory> _getCacheRootDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/cache/cities');
  }

  /// Gets a specific city's cache directory: cache/cities/osm_1370736/
  Future<Directory> _getCityDirectory(String cityId) async {
    final root = await _getCacheRootDirectory();
    return Directory('${root.path}/$cityId');
  }

  /// Gets the city.json file path for a specific city.
  Future<File> _getCityFile(String cityId) async {
    final dir = await _getCityDirectory(cityId);
    return File('${dir.path}/city.json');
  }

  /// Gets the roads.json file path for a specific city.
  Future<File> _getRoadsFile(String cityId) async {
    final dir = await _getCityDirectory(cityId);
    return File('${dir.path}/roads.json');
  }
}