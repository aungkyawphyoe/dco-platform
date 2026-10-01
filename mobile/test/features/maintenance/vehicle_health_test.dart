import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/vehicle_health.dart';
import 'package:flutter_test/flutter_test.dart';

PlanItem _item({
  String id = 'p1',
  DateTime? nextDueOn,
  double? nextDueMileage,
  bool enabled = true,
}) {
  final now = DateTime(2026, 8, 19);
  return PlanItem(
    id: id,
    vehicleId: 'v1',
    name: 'Service',
    enabled: enabled,
    nextDueOn: nextDueOn,
    nextDueMileage: nextDueMileage,
    updatedAt: now,
    createdAt: now,
  );
}

void main() {
  group('VehicleHealthCalculator', () {
    final now = DateTime(2026, 8, 19);
    const thresholds = DueThresholds.defaults;

    test('no plan items is good', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: const [],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.good);
      expect(summary.visibleCount, 0);
    });

    test('overdue item makes the vehicle need attention', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: [_item(id: 'a', nextDueOn: DateTime(2026, 8, 1))],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.attention);
      expect(summary.overdueCount, 1);
    });

    test('due-mileage overdue counts as attention', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: [_item(id: 'a', nextDueMileage: 9000)],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.attention);
    });

    test('due-soon without overdue is dueSoon', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: [_item(id: 'a', nextDueOn: DateTime(2026, 8, 30))],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.dueSoon);
      expect(summary.dueSoonCount, 1);
    });

    test('overdue wins over due-soon', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: [
          _item(id: 'a', nextDueOn: DateTime(2026, 8, 1)),
          _item(id: 'b', nextDueOn: DateTime(2026, 8, 25)),
        ],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.attention);
      expect(summary.overdueCount, 1);
      expect(summary.dueSoonCount, 1);
    });

    test('disabled and far-future items stay good', () {
      final summary = VehicleHealthCalculator.evaluate(
        items: [
          _item(id: 'a', nextDueOn: DateTime(2026, 8, 1), enabled: false),
          _item(id: 'b', nextDueOn: DateTime(2027, 8, 1)),
        ],
        vehicleMileage: 10000,
        now: now,
        thresholds: thresholds,
      );
      expect(summary.status, VehicleHealth.good);
      expect(summary.scheduledCount, 1);
    });
  });
}
