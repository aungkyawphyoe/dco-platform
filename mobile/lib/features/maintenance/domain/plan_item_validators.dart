import 'entities/service_record.dart';

abstract final class PlanItemValidators {
  static const maxNameLength = 80;

  static String? name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length > maxNameLength) return 'Name must be $maxNameLength characters or fewer';
    return null;
  }

  static String? schedule({
    required bool recurring,
    int? intervalDays,
    double? intervalDistance,
    DateTime? date,
    double? mileage,
  }) {
    if (recurring) {
      final hasTime = intervalDays != null && intervalDays > 0;
      final hasDistance = intervalDistance != null && intervalDistance > 0;
      if (!hasTime && !hasDistance) {
        return 'Set a time interval, a mileage interval, or both';
      }
      return null;
    }
    if (date == null && mileage == null) {
      return 'Set a due date, a due mileage, or both';
    }
    return null;
  }

  static String? mileage(String value, {required bool required}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return required ? 'Mileage is required' : null;
    final parsed = double.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null || parsed < 0) return 'Enter a valid mileage';
    return null;
  }

  static double? parseMileage(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', ''));
  }

  static String? intervalCount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) return 'Enter a whole number greater than 0';
    return null;
  }

  static int? parseIntervalCount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}

abstract final class ServiceRecordValidators {
  static String? date(DateTime? value) {
    if (value == null) return 'Date is required';
    return null;
  }

  static String? odometer(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Mileage is required';
    final parsed = double.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null || parsed < 0) return 'Enter a valid mileage';
    return null;
  }

  static String? items(List<ServiceLineDraft> value) {
    if (value.isEmpty) return 'Add at least one service';
    return null;
  }

  static String? totalCost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Total is required';
    final parsed = double.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  static double? parseCost(String value) {
    final trimmed = value.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  static int maxServiceYear() => DateTime.now().year + 1;
}
