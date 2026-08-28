import '../../../core/units/mileage_unit.dart';
import '../../maintenance/domain/due_calculator.dart';
import '../../maintenance/domain/entities/plan_item.dart';
import 'entities/notification.dart';

/// When a local OS reminder should fire for a plan item.
///
/// Time: remaining days < [soonDays]. Mileage: remaining distance < 100 km or
/// 60 mi, using the owner's length unit. Whichever condition hits first.
abstract final class ReminderPolicy {
  static const soonDays = 7;
  static const soonMiles = 60.0;
  static const soonKilometers = 100.0;
  static const titleMax = 80;
  static const bodyMax = 140;
  static const fireHour = 9;

  static const osTitle = 'Maintenance Reminder';

  static String osBody(String serviceName) => clip(serviceName, bodyMax);

  static String clip(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return trimmed.substring(0, max);
  }

  static String cycleKey(PlanItem item) {
    final date = item.nextDueOn == null
        ? ''
        : DueCalculator.dateOnly(item.nextDueOn!).toIso8601String().split('T').first;
    final miles = item.nextDueMileage == null ? '' : item.nextDueMileage!.toString();
    return '$date|$miles';
  }

  static String deliveredKey(String planItemId, String cycle) => '$planItemId::$cycle';

  /// Stable Android/iOS notification id for a plan item (31-bit).
  static int osId(String planItemId) {
    final hex = planItemId.replaceAll('-', '');
    if (hex.length >= 8) {
      return int.parse(hex.substring(0, 8), radix: 16) & 0x7fffffff;
    }
    var hash = 0;
    for (final code in planItemId.codeUnits) {
      hash = 0x7fffffff & (hash * 31 + code);
    }
    return hash;
  }

  /// Stored-miles remaining at or below this value is "due soon" for [unit].
  static double soonDistanceMiles(MileageUnit unit) {
    return unit == MileageUnit.km ? MileageUnit.km.toStorage(soonKilometers) : soonMiles;
  }

  static bool mileageDueSoon({
    required double? nextDueMileage,
    required double vehicleMileage,
    required MileageUnit lengthUnit,
  }) {
    if (nextDueMileage == null) return false;
    return nextDueMileage - vehicleMileage <= soonDistanceMiles(lengthUnit);
  }

  /// Local 09:00 on the day remaining time first drops below [soonDays].
  /// Null when the item has no due date.
  static DateTime? dateWindowStart(DateTime? nextDueOn) {
    if (nextDueOn == null) return null;
    final due = DueCalculator.dateOnly(nextDueOn);
    final windowDay = due.subtract(const Duration(days: soonDays));
    return DateTime(windowDay.year, windowDay.month, windowDay.day, fireHour);
  }

  static NotificationDueReason dueReason({
    required bool dateHit,
    required bool mileageHit,
  }) {
    if (dateHit && mileageHit) return NotificationDueReason.both;
    if (mileageHit) return NotificationDueReason.mileage;
    return NotificationDueReason.date;
  }
}
