import '../../garage/domain/entities/vehicle.dart';
import '../../maintenance/domain/due_calculator.dart';
import '../../maintenance/domain/entities/plan_item.dart';
import 'entities/notification.dart';
import 'reminder_policy.dart';

enum ReminderActionKind {
  /// Drop any OS schedule for this item and phase.
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
    required this.phase,
    required this.cycleKey,
    required this.fireAt,
  });

  final String planItemId;
  final ReminderPhase phase;

  /// Phase-scoped cycle key (see [ReminderPolicy.storedCycleKey]).
  final String cycleKey;
  final DateTime fireAt;
}

class ReminderAction {
  const ReminderAction({
    required this.kind,
    required this.phase,
    required this.planItemId,
    required this.vehicleId,
    required this.serviceName,
    required this.cycleKey,
    this.fireAt,
    this.dueReason,
    this.dueOn,
    this.dueMileage,
  });

  final ReminderActionKind kind;
  final ReminderPhase phase;
  final String planItemId;
  final String vehicleId;
  final String serviceName;

  /// Phase-scoped cycle key (see [ReminderPolicy.storedCycleKey]).
  final String cycleKey;
  final DateTime? fireAt;
  final NotificationDueReason? dueReason;
  final DateTime? dueOn;
  final double? dueMileage;
}

/// Pure mapping from vehicles + plan items → local reminder actions.
///
/// Emits at most two actions per item: one for [ReminderPhase.upcoming] and
/// one for [ReminderPhase.due].
abstract final class ReminderPlanner {
  static List<ReminderAction> plan({
    required List<Vehicle> garage,
    required List<PlanItem> items,
    required Set<String> deliveredCycleKeys,
    required List<ScheduledReminder> scheduled,
    required DateTime now,
    required DueThresholds thresholds,
  }) {
    final vehicles = {for (final vehicle in garage) vehicle.id: vehicle};
    final scheduledByPhase = {
      for (final row in scheduled) (row.planItemId, row.phase): row,
    };

    return [
      for (final item in items)
        ..._forItem(
          item: item,
          vehicle: vehicles[item.vehicleId],
          delivered: deliveredCycleKeys,
          scheduled: scheduledByPhase,
          now: now,
          thresholds: thresholds,
        ),
    ];
  }

  static List<ReminderAction> _forItem({
    required PlanItem item,
    required Vehicle? vehicle,
    required Set<String> delivered,
    required Map<(String, ReminderPhase), ScheduledReminder> scheduled,
    required DateTime now,
    required DueThresholds thresholds,
  }) {
    if (vehicle == null || !item.enabled || _noDueValue(item)) {
      return [for (final phase in ReminderPhase.values) _cancel(item, phase)];
    }

    final mileageHit = ReminderPolicy.mileageDueSoon(
      nextDueMileage: item.nextDueMileage,
      vehicleMileage: vehicle.mileage,
      thresholds: thresholds,
    );
    final dueAt = ReminderPolicy.windowStart(
      item.nextDueOn,
      phase: ReminderPhase.due,
      thresholds: thresholds,
    );
    final upcomingAt = ReminderPolicy.windowStart(
      item.nextDueOn,
      phase: ReminderPhase.upcoming,
      thresholds: thresholds,
    );
    final dateHit = dueAt != null && !dueAt.isAfter(now);
    final dueHit = mileageHit || dateHit;

    return [
      ..._duePhase(
        item: item,
        delivered: delivered,
        scheduled: scheduled,
        now: now,
        dueAt: dueAt,
        mileageHit: mileageHit,
        dateHit: dateHit,
        dueHit: dueHit,
      ),
      ..._upcomingPhase(
        item: item,
        delivered: delivered,
        scheduled: scheduled,
        now: now,
        upcomingAt: upcomingAt,
        dueHit: dueHit,
      ),
    ];
  }

  static List<ReminderAction> _duePhase({
    required PlanItem item,
    required Set<String> delivered,
    required Map<(String, ReminderPhase), ScheduledReminder> scheduled,
    required DateTime now,
    required DateTime? dueAt,
    required bool mileageHit,
    required bool dateHit,
    required bool dueHit,
  }) {
    const phase = ReminderPhase.due;
    final cycle = ReminderPolicy.storedCycleKey(item, phase);

    if (delivered.contains(ReminderPolicy.deliveredKey(item.id, cycle))) {
      return [_cancel(item, phase)];
    }

    if (dueHit) {
      return [
        _alreadyFired(scheduled[(item.id, phase)], cycle, now)
            ? _action(item, phase, ReminderActionKind.recordFeedOnly, cycle,
                fireAt: now, dueReason: _reason(dateHit, mileageHit))
            : _action(item, phase, ReminderActionKind.showNow, cycle,
                fireAt: now, dueReason: _reason(dateHit, mileageHit)),
      ];
    }

    if (dueAt != null) {
      return [
        _action(item, phase, ReminderActionKind.schedule, cycle, fireAt: dueAt),
      ];
    }

    // Mileage-only item that has not reached its threshold yet.
    return [_cancel(item, phase)];
  }

  static List<ReminderAction> _upcomingPhase({
    required PlanItem item,
    required Set<String> delivered,
    required Map<(String, ReminderPhase), ScheduledReminder> scheduled,
    required DateTime now,
    required DateTime? upcomingAt,
    required bool dueHit,
  }) {
    const phase = ReminderPhase.upcoming;
    final cycle = ReminderPolicy.storedCycleKey(item, phase);

    if (upcomingAt == null) return [_cancel(item, phase)];
    if (delivered.contains(ReminderPolicy.deliveredKey(item.id, cycle))) {
      return [_cancel(item, phase)];
    }

    if (upcomingAt.isAfter(now)) {
      return [
        _action(item, phase, ReminderActionKind.schedule, cycle, fireAt: upcomingAt),
      ];
    }

    // The upcoming window is open. Skip a second banner when the due reminder
    // is firing in the same pass.
    if (dueHit) return [_cancel(item, phase)];

    return [
      _alreadyFired(scheduled[(item.id, phase)], cycle, now)
          ? _action(item, phase, ReminderActionKind.recordFeedOnly, cycle,
              fireAt: now, dueReason: NotificationDueReason.date)
          : _action(item, phase, ReminderActionKind.showNow, cycle,
              fireAt: now, dueReason: NotificationDueReason.date),
    ];
  }

  static bool _alreadyFired(
    ScheduledReminder? scheduled,
    String cycle,
    DateTime now,
  ) {
    return scheduled != null &&
        scheduled.cycleKey == cycle &&
        !scheduled.fireAt.isAfter(now);
  }

  static bool _noDueValue(PlanItem item) =>
      item.nextDueOn == null && item.nextDueMileage == null;

  static NotificationDueReason _reason(bool dateHit, bool mileageHit) {
    return ReminderPolicy.dueReason(dateHit: dateHit, mileageHit: mileageHit);
  }

  static ReminderAction _cancel(PlanItem item, ReminderPhase phase) {
    return _action(item, phase, ReminderActionKind.cancel, _cycle(item, phase));
  }

  static ReminderAction _action(
    PlanItem item,
    ReminderPhase phase,
    ReminderActionKind kind,
    String cycle, {
    DateTime? fireAt,
    NotificationDueReason? dueReason,
  }) {
    return ReminderAction(
      kind: kind,
      phase: phase,
      planItemId: item.id,
      vehicleId: item.vehicleId,
      serviceName: item.name,
      cycleKey: cycle,
      fireAt: fireAt,
      dueReason: dueReason,
      dueOn: item.nextDueOn,
      dueMileage: item.nextDueMileage,
    );
  }

  static String _cycle(PlanItem item, ReminderPhase phase) =>
      ReminderPolicy.storedCycleKey(item, phase);
}
