import 'entities/fuel_catalog_type.dart';

abstract final class FuelTypeValidators {
  static const maxNameLength = 40;

  static String? name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length > maxNameLength) return 'Name must be $maxNameLength characters or fewer';
    return null;
  }

  static String? unit(FuelCatalogKind kind, String value) {
    if (!kind.units.contains(value)) return 'Choose a valid unit';
    return null;
  }
}

abstract final class FuelLogValidators {
  static const maxAmount = 100000.0;
  static const maxCost = 1000000000.0;

  static String? date(DateTime? value, {required DateTime now}) {
    if (value == null) return 'Date is required';
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(value.year, value.month, value.day);
    if (picked.isAfter(today)) return 'Date cannot be in the future';
    return null;
  }

  static String? fuelTypeId(String? value) {
    if (value == null || value.isEmpty) return 'Fuel type is required';
    return null;
  }

  static String? amount(String value) {
    final parsed = parseDecimal(value);
    if (parsed == null) return 'Amount is required';
    if (parsed <= 0) return 'Enter an amount greater than 0';
    if (parsed > maxAmount) return 'Amount is too large';
    return null;
  }

  static String? cost(String value) {
    final parsed = parseDecimal(value);
    if (parsed == null) return 'Cost is required';
    if (parsed < 0) return 'Enter a valid cost';
    if (parsed > maxCost) return 'Cost is too large';
    return null;
  }

  static double? parseDecimal(String value) {
    final trimmed = value.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  static int maxLogYear() => DateTime.now().year + 1;
}
