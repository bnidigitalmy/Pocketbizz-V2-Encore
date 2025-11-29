/// Unit Conversion System for Stock Management
/// Converts between different measurement units for recipe calculations
/// 
/// Factor represents: 1 [fromUnit] = factor × [toUnit]
/// Example: 1 kg = 1000 gram, so kg→gram factor is 1000
library;

/// Supported unit conversion mappings
/// Each unit maps to other units with conversion factors
class UnitConversion {
  // Weight conversions
  static const Map<String, Map<String, double>> weightConversions = {
    'kg': {'kg': 1.0, 'gram': 1000.0, 'g': 1000.0},
    'gram': {'kg': 0.001, 'gram': 1.0, 'g': 1.0},
    'g': {'kg': 0.001, 'gram': 1.0, 'g': 1.0},
  };

  // Volume conversions
  static const Map<String, Map<String, double>> volumeConversions = {
    'liter': {'liter': 1.0, 'l': 1.0, 'ml': 1000.0, 'tbsp': 66.67, 'tsp': 200.0},
    'l': {'liter': 1.0, 'l': 1.0, 'ml': 1000.0, 'tbsp': 66.67, 'tsp': 200.0},
    'ml': {'liter': 0.001, 'l': 0.001, 'ml': 1.0, 'tbsp': 0.0667, 'tsp': 0.2},
    'tbsp': {'liter': 0.015, 'l': 0.015, 'ml': 15.0, 'tbsp': 1.0, 'tsp': 3.0},
    'tsp': {'liter': 0.005, 'l': 0.005, 'ml': 5.0, 'tbsp': 0.333, 'tsp': 1.0},
  };

  // Count conversions
  static const Map<String, Map<String, double>> countConversions = {
    'dozen': {'dozen': 1.0, 'pcs': 12.0, 'pieces': 12.0},
    'pcs': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0},
    'pieces': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0},
  };

  // All conversions combined
  static const Map<String, Map<String, double>> allConversions = {
    ...weightConversions,
    ...volumeConversions,
    ...countConversions,
  };

  /// Convert quantity from one unit to another
  /// 
  /// Returns converted quantity, or original quantity if conversion not possible
  /// Logs warnings in debug mode for missing conversions
  static double convert({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();

    // If units are the same, no conversion needed
    if (from == to) return quantity;

    // Check if conversion exists
    if (!allConversions.containsKey(from)) {
      _logWarning(
        '⚠️ Unit conversion warning: Unknown source unit "$fromUnit". '
        'Returning original quantity. This may cause incorrect cost calculations!'
      );
      return quantity;
    }

    if (!allConversions[from]!.containsKey(to)) {
      _logWarning(
        '⚠️ Unit conversion warning: Cannot convert from "$fromUnit" to "$toUnit". '
        'Incompatible units! Returning original quantity. '
        'This WILL cause incorrect cost calculations!'
      );
      return quantity;
    }

    // Convert: multiply by conversion factor
    final factor = allConversions[from]![to]!;
    final converted = quantity * factor;

    // Log conversion for debugging (only in debug mode)
    _logDebug(
      '🔄 Unit conversion: $quantity $fromUnit → ${converted.toStringAsFixed(4)} $toUnit'
    );

    return converted;
  }

  /// Check if conversion is possible between two units
  static bool canConvert(String fromUnit, String toUnit) {
    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();

    if (from == to) return true;

    return allConversions.containsKey(from) &&
           allConversions[from]!.containsKey(to);
  }

  /// Get all units that can be converted from the given unit
  static List<String> getCompatibleUnits(String unit) {
    final unitKey = unit.toLowerCase().trim();
    
    if (!allConversions.containsKey(unitKey)) {
      return [unit]; // Return original if not found
    }

    return allConversions[unitKey]!.keys.toList();
  }

  /// Get unit category (weight, volume, count)
  static String? getUnitCategory(String unit) {
    final unitKey = unit.toLowerCase().trim();

    if (weightConversions.containsKey(unitKey)) return 'weight';
    if (volumeConversions.containsKey(unitKey)) return 'volume';
    if (countConversions.containsKey(unitKey)) return 'count';

    return null;
  }

  /// Calculate cost per base unit
  /// 
  /// Example: Package of 500gram costs RM21.90
  /// Cost per gram = 21.90 / 500 = RM0.0438 per gram
  static double calculateCostPerUnit({
    required double packageSize,
    required String packageUnit,
    required double packagePrice,
    required String targetUnit,
  }) {
    // Convert package size to target unit
    final convertedSize = convert(
      quantity: packageSize,
      fromUnit: packageUnit,
      toUnit: targetUnit,
    );

    // Calculate cost per target unit
    return packagePrice / convertedSize;
  }

  /// Calculate total cost for a given quantity
  /// 
  /// Example: Need 250 grams, cost per gram is RM0.0438
  /// Total cost = 250 * 0.0438 = RM10.95
  static double calculateTotalCost({
    required double quantity,
    required String quantityUnit,
    required double costPerUnit,
    required String costUnit,
  }) {
    // Convert quantity to cost unit
    final convertedQuantity = convert(
      quantity: quantity,
      fromUnit: quantityUnit,
      toUnit: costUnit,
    );

    return convertedQuantity * costPerUnit;
  }

  /// Format quantity with unit for display
  static String formatQuantity(double quantity, String unit) {
    // Remove trailing zeros and unnecessary decimal point
    final formatted = quantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return '$formatted $unit';
  }

  // Debug logging helpers
  static void _logWarning(String message) {
    assert(() {
      print(message);
      return true;
    }());
  }

  static void _logDebug(String message) {
    assert(() {
      // Only log in debug mode
      print(message);
      return true;
    }());
  }
}

/// Common units for quick access
class Units {
  // Weight
  static const String kilogram = 'kg';
  static const String gram = 'gram';
  static const String g = 'g';

  // Volume
  static const String liter = 'liter';
  static const String l = 'l';
  static const String milliliter = 'ml';
  static const String tablespoon = 'tbsp';
  static const String teaspoon = 'tsp';

  // Count
  static const String dozen = 'dozen';
  static const String pieces = 'pcs';
  static const String piece = 'pieces';

  /// Get all available units grouped by category
  static Map<String, List<String>> get allUnits => {
    'Weight': [kilogram, gram, g],
    'Volume': [liter, l, milliliter, tablespoon, teaspoon],
    'Count': [dozen, pieces, piece],
  };

  /// Get flat list of all units
  static List<String> get flatList => [
    kilogram, gram, g,
    liter, l, milliliter, tablespoon, teaspoon,
    dozen, pieces, piece,
  ];
}

