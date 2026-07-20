// lib/utils/weight_converter.dart
// Converts kg ↔ lbs for display. Internal storage is always kg.
// Usage: WeightConverter.display(pf.weightKg, pf.weightUnit)

class WeightConverter {
  WeightConverter._();

  static const double _kgToLbs = 2.20462;

  /// Format weight for display based on the user's stored unit preference.
  /// Drops trailing .0 for whole numbers.
  /// e.g. display(70.0, 'lbs') → '154.3 lbs'
  ///      display(70.0, 'kg')  → '70 kg'
  static String display(double kg, String unit) {
    if (unit == 'lbs') {
      final lbs = kg * _kgToLbs;
      return lbs == lbs.truncateToDouble()
          ? '${lbs.toInt()} lbs'
          : '${lbs.toStringAsFixed(1)} lbs';
    }
    return kg == kg.truncateToDouble()
        ? '${kg.toInt()} kg'
        : '${kg.toStringAsFixed(1)} kg';
  }

  /// Convert a user-entered value back to kg for storage.
  static double toKg(double value, String unit) =>
      unit == 'lbs' ? value / _kgToLbs : value;

  /// Convert kg to the user's preferred unit for display (raw number).
  static double fromKg(double kg, String unit) =>
      unit == 'lbs' ? kg * _kgToLbs : kg;

  /// Unit label only: 'kg' or 'lbs'.
  static String label(String unit) => unit == 'lbs' ? 'lbs' : 'kg';
}
