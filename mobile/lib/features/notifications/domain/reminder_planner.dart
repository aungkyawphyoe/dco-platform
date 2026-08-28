import '../../garage/domain/entities/vehicle.dart';
import '../../maintenance/domain/entities/plan_item.dart';
import 'entities/notification.dart';
import 'reminder_policy.dart';

enum ReminderActionKind {
  /// Drop any OS schedule for this item.
  cancel,

  /// Schedule an OS notification at [ReminderAction.fireAt].
  schedule,

  /// Show the OS banner now and write a feed row.
  showNow,

  /// Feed row only — the OS already displayed a previously scheduled alarm.
  recordFeedOnly,
}

class ScheduledReminder {
  const ScheduledReminder({
    required this.planItemId,
    required this.cycleKey,
    required this.fireAt,
  });

  final String planItemId;
  final String cycleKey;
  final DateTime fireAt;
}

class ReminderAction {
  const ReminderAction({
    required this.kind,
    required this.planItemId,
    required this.vehicleId,
    required this.serviceName,
    required this.cycleKey,
    this.fireAt,
    this.dueReason,
  });

  final ReminderActionKind kind;
  final String planItemId;
  final String vehicleId;
  final String serviceName;
  final String cycleKey;
  final DateTime? fireAt;
  final NotificationDueReason? dueReason;
}

/// Pure mapping from vehicles + plan items → local reminder actions.
abstract final class ReminderPlanner {
  static List<ReminderAction> plan({
    required List<Vehicle> garage,
    required List<PlanItem> items,
    required Set<String> deliveredCycleKeys,
    required List<ScheduledReminder> scheduled,
    required DateTime now,
    required MileageUnit lengthUnit,
  }) {
    final vehicles = {for (final vehicle in garage) vehicle.id: vehicle};
    final scheduledByItem = {for (final row in scheduled) row.planItemId: row};

    return [
      for (final item in items)
        _forItem(
          item: item,
          vehicle: vehicles[item.vehicleId],
          delivered: deliveredCycleKeys,
          scheduled: scheduledByItem[item.id],
          now: now,
          lengthUnit: lengthUnit,
        ),
    ];
  }

  static ReminderAction _forItem({
    required PlanItem item,
    required Vehicle? vehicle,
    required Set<String> delivered,
    required ScheduledReminder? scheduled,
    required DateTime now,
    required MileageUnit lengthUnit,
  }) {
    final cycle = ReminderPolicy.cycleKey(item);
    final cancel = ReminderAction(
      kind: ReminderActionKind.cancel,
      planItemId: item.id,
      vehicleId: item.vehicleId,
      serviceName: item.name,
      cycleKey: cycle,
    );

    if (vehicle == null || !item.enabled) return cancel;
    if (item.nextDueOn == null && item.nextDueMileage == null) return cancel;

    final mileageHit = ReminderPolicy.mileageDueSoon(
      nextDueMileage: item.nextDueMileage,
      vehicleMileage: vehicle.mileage,
      lengthUnit: lengthUnit,
    );
    final windowStart = ReminderPolicy.dateWindowStart(item.nextDueOn);
    final dateHit = windowStart != null && !windowStart.isAfter(now);
    final deliveredThisCycle = delivered.contains(
      ReminderPolicy.deliveredKey(item.id, cycle),
    );

    if (deliveredThisCycle) {
      return cancel;
    }

    if (mileageHit || dateHit) {
      final reason = ReminderPolicy.dueReason(dateHit: dateHit, mileageHit: mileageHit);
      final osAlreadyFired = scheduled != null &&
          scheduled.cycleKey == cycle &&
          !scheduled.fireAt.isAfter(now);
      return ReminderAction(
        kind: osAlreadyFired ? ReminderActionKind.recordFeedOnly : ReminderActionKind.showNow,
        planItemId: item.id,
        vehicleId: item.vehicleId,
        serviceName: item.name,
        cycleKey: cycle,
        fireAt: now,
        dueReason: reason,
      );
    }

    if (windowStart != null) {
      return ReminderAction(
        kind: ReminderActionKind.schedule,
        planItemId: item.id,
        vehicleId: item.vehicleId,
        serviceName: item.name,
        cycleKey: cycle,
        fireAt: windowStart,
        dueReason: NotificationDueReason.date,
      );
    }

    return cancel;
  }
}
