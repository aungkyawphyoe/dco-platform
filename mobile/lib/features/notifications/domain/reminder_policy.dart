import '../../../core/units/mileage_unit.dart';
import '../../maintenance/domain/due_calculator.dart';
import '../../maintenance/domain/entities/plan_item.dart';
import 'entities/notification.dart';

/// The two local OS reminders a plan item gets per due cycle.
enum ReminderPhase {
  /// Fires 30 days before the due date (date-based items only).
  upcoming,

  /// Fires on the due date, or immediately when remaining mileage drops to
  /// the due-soon threshold.
  due,
}

/// When a local OS reminder should fire for a plan item.
///
/// Time: upcoming at local 09:00, 30 days before [PlanItem.nextDueOn]; due at
/// local 09:00 on [PlanItem.nextDueOn]. Mileage: remaining distance < 100 km
/// or 60 mi, using the owner's length unit, evaluated in the foreground.
/// Whichever condition hits first.
abstract final class ReminderPolicy {
  static const upcomingDays = 30;
  static const soonMiles = 60.0;
  static const soonKilometers = 100.0;
  static const titleMax = 80;
  static const bodyMax = 140;
  static const fireHour = 9;

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

  /// Cycle key scoped to one phase so the upcoming and due reminders of the
  /// same cycle dedupe independently.
  static String storedCycleKey(PlanItem item, ReminderPhase phase) {
    final base = cycleKey(item);
    return phase == ReminderPhase.upcoming ? '$base#upcoming' : base;
  }

  static String deliveredKey(String planItemId, String cycle) => '$planItemId::$cycle';

  /// Stable Android/iOS notification id for a plan item and phase (31-bit).
  /// The two phases never share an id.
  static int osId(String planItemId, {ReminderPhase phase = ReminderPhase.due}) {
    int hash;
    final hex = planItemId.replaceAll('-', '');
    if (hex.length >= 8) {
      hash = int.parse(hex.substring(0, 8), radix: 16);
    } else {
      hash = 0;
      for (final code in planItemId.codeUnits) {
        hash = 0x7fffffff & (hash * 31 + code);
      }
    }
    final base = hash & 0x3fffffff;
    return phase == ReminderPhase.upcoming ? base | 0x40000000 : base;
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

  /// Local 09:00 fire time for [phase]: 30 days before the due date for
  /// [ReminderPhase.upcoming], the due date itself for [ReminderPhase.due].
  /// Null when the item has no due date.
  static DateTime? windowStart(DateTime? nextDueOn, {required ReminderPhase phase}) {
    if (nextDueOn == null) return null;
    final due = DueCalculator.dateOnly(nextDueOn);
    final day = phase == ReminderPhase.upcoming
        ? due.subtract(Duration(days: upcomingDays))
        : due;
    return DateTime(day.year, day.month, day.day, fireHour);
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
