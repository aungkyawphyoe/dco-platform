class VehicleValidators {
  const VehicleValidators._();

  static String? name(String value) {
    if (value.trim().isEmpty) return 'Name is required';
    return null;
  }

  static String? make(String value) {
    if (value.trim().isEmpty) return 'Make is required';
    return null;
  }

  static String? model(String value) {
    if (value.trim().isEmpty) return 'Model is required';
    return null;
  }

  static String? year(String value, {DateTime? now}) {
    if (value.trim().isEmpty) return 'Year is required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid year';
    final max = (now ?? DateTime.now()).year + 1;
    if (parsed < 1900 || parsed > max) return 'Year must be between 1900 and $max';
    return null;
  }

  static int? parseYear(String value) => int.tryParse(value.trim());

  static String? licensePlate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'License plate is required';
    if (trimmed.length > 20) return 'License plate must be 20 characters or fewer';
    return null;
  }

  static String? mileage(String value) {
    if (value.trim().isEmpty) return 'Mileage is required';
    final parsed = double.tryParse(value.trim().replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid mileage';
    if (parsed < 0) return 'Mileage cannot be negative';
    return null;
  }

  static double? parseMileage(String value) {
    return double.tryParse(value.trim().replaceAll(',', ''));
  }

  static String? vin(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length != 17) return 'VIN must be 17 characters';
    return null;
  }
}
