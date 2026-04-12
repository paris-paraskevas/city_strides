// Shared formatting utilities for distance, dates, and percentages.

/// Formats a distance in meters to a human-readable string.
/// Respects the user's unit preference ('km' or 'miles').
String formatDistance(double meters, String units) {
  if (units == 'miles') {
    final miles = meters / 1609.344;
    return '${miles.toStringAsFixed(2)} mi';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(2)} km';
}

/// Formats a DateTime as dd/MM/yyyy (Greek convention).
String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

/// Formats a percentage value to one decimal place.
String formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}
