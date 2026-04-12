// Central theme definition for City Strides.
//
// All color decisions live here. Screens should use Theme.of(context)
// for Material widget colors (AppBar, buttons, etc.) and AppTheme
// constants for custom colors (map layers, progress bars, etc.).

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // --- Brand Colors ---
  static const Color primary = Colors.teal;
  static const Color primaryLight = Color(0xFFB2DFDB);  // teal.shade100
  static const Color primaryDark = Color(0xFF00796B);    // teal.shade700

  // --- Map Colors ---
  static const Color boundary = Colors.blue;
  static const Color walkedRoad = Colors.green;
  static const Color unwalkedRoad = Colors.grey;
  static const Color userDot = Colors.blue;
  static const Color userDotBorder = Colors.white;
  static const double boundaryAlpha = 0.1;
  static const double roadAlpha = 0.6;

  // --- Semantic Colors ---
  static const Color danger = Colors.red;
  static const Color warning = Colors.orange;

  // --- Text Colors ---
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static Color textHint = Colors.grey.shade600;
  static Color textMuted = Colors.grey.shade500;

  // --- Theme Data ---
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      useMaterial3: true,
    );
  }
}
