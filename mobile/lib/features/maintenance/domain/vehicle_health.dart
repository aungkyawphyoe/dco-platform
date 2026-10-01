import 'due_calculator.dart';
import 'entities/plan_item.dart';

enum VehicleHealth { good, dueSoon, attention }

class VehicleHealthSummary {
  const VehicleHealthSummary({
    required this.status,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.scheduledCount,
  });

  final VehicleHealth status;
  final int overdueCount;
  final int dueSoonCount;
  final int scheduledCount;

  int get visibleCount => overdueCount + dueSoonCount + scheduledCount;
}

/// Roll-up of plan item urgencies into a single vehicle health status.
///
/// This is derived only from real plan data — it never invents a state.
abstract final class VehicleHealthCalculator {
  static VehicleHealthSummary evaluate({
    required List<PlanItem> items,
    required double vehicleMileage,
    required DateTime now,
    required DueThresholds thresholds,
  }) {
    var overdue = 0;
    var dueSoon = 0;
    var scheduled = 0;
    for (final item in items) {
      switch (DueCalculator.urgency(
        item: item,
        vehicleMileage: vehicleMileage,
        now: now,
        thresholds: thresholds,
      )) {
        case PlanUrgency.overdue:
          overdue++;
        case PlanUrgency.dueSoon:
          dueSoon++;
        case PlanUrgency.scheduled:
          scheduled++;
        case PlanUrgency.hidden:
          break;
      }
    }
    final status = switch ((overdue, dueSoon)) {
      (> 0, _) => VehicleHealth.attention,
      (_, > 0) => VehicleHealth.dueSoon,
      _ => VehicleHealth.good,
    };
    return VehicleHealthSummary(
      status: status,
      overdueCount: overdue,
      dueSoonCount: dueSoon,
      scheduledCount: scheduled,
    );
  }
}
