// Service for persisting walked segment data locally.
//
// Saves walked segments as JSON files on the device so progress
// survives app restarts. Follows the same pattern as CacheService.
//
// File structure on device:
//   app_data/walked/{cityId}/walked.json
//
// Each city gets its own folder. This means:
//   - Multiple cities tracked independently
//   - Clearing one city doesn't affect others

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/walked_segment_model.dart';

class StorageService {

  // =========================================================================
  // PUBLIC METHODS — CHECK
  // =========================================================================

  /// Returns true if walked data exists for this city.
  Future<bool> hasWalkedData(String cityId) async {
    final file = await _getWalkedFile(cityId);
    return file.existsSync();
  }

  // =========================================================================
  // PUBLIC METHODS — SAVE
  // =========================================================================

  /// Saves walked segments to local storage as JSON.
  Future<void> saveWalkedSegments(
    String cityId,
    List<WalkedSegmentModel> segments,
  ) async {
    final file = await _getWalkedFile(cityId);
    await file.parent.create(recursive: true);

    final jsonList = segments.map((s) => s.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await file.writeAsString(jsonString);
  }

  // =========================================================================
  // PUBLIC METHODS — LOAD
  // =========================================================================

  /// Loads walked segments from local storage.
  /// Returns null if the file doesn't exist or can't be parsed.
  Future<List<WalkedSegmentModel>?> loadWalkedSegments(String cityId) async {
    try {
      final file = await _getWalkedFile(cityId);
      if (!file.existsSync()) return null;

      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) =>
              WalkedSegmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // PUBLIC METHODS — CLEAR
  // =========================================================================

  /// Deletes walked data for a specific city.
  Future<void> clearWalkedSegments(String cityId) async {
    final file = await _getWalkedFile(cityId);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // =========================================================================
  // PRIVATE METHODS — FILE PATHS
  // =========================================================================

  Future<Directory> _getWalkedRootDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/walked');
  }

  Future<Directory> _getCityDirectory(String cityId) async {
    final root = await _getWalkedRootDirectory();
    return Directory('${root.path}/$cityId');
  }

  Future<File> _getWalkedFile(String cityId) async {
    final dir = await _getCityDirectory(cityId);
    return File('${dir.path}/walked.json');
  }
}
