import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/features/stats/domain/maintenance_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_models.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceLine _line(String name, {double? lineCost, String id = 'l'}) {
  return ServiceLine(id: '$name-$id', name: name, lineCost: lineCost);
}

ServiceRecord _record({
  required String id,
  required DateTime servicedOn,
  double totalCost = 100,
  List<ServiceLine> items = const [],
}) {
  return ServiceRecord(
    id: id,
    vehicleId: 'v1',
    title: 'Job $id',
    servicedOn: servicedOn,
    odometer: 10000,
    totalCost: totalCost,
    items: items,
    updatedAt: servicedOn,
    createdAt: servicedOn,
  );
}

MaintenanceStats _compute(
  List<ServiceRecord> records, {
  StatsPeriod period = StatsPeriod.all,
}) {
  return MaintenanceStats.compute(records: records, period: period);
}

void main() {
  group('KPIs', () {
    test('counts jobs and items, sums cost, averages per job', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          totalCost: 120,
          items: [_line('Oil Change', lineCost: 80), _line('Filter', lineCost: 20)],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 2, 5),
          totalCost: 80,
          items: [_line('Brakes', lineCost: 60)],
        ),
        _record(id: 'c', servicedOn: DateTime(2026, 3, 5), totalCost: 0),
      ]);
      expect(stats.totalRecords, 3);
      expect(stats.countInPeriod, 3);
      expect(stats.serviceItemCount, 3);
      expect(stats.totalCost, 200);
      expect(stats.avgJobCost, closeTo(200 / 3, 1e-9));
      expect(stats.hasAnyRecords, isTrue);
    });

    test('top service type is the highest summed line cost', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          items: [
            _line('Oil Change', lineCost: 30),
            _line('Brakes', lineCost: 90),
          ],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 2, 5),
          items: [_line('Oil Change', lineCost: 40)],
        ),
      ]);
      expect(stats.topServiceName, 'Brakes');
      expect(stats.topServiceCost, 90);
    });

    test('top service type ties resolve to the most recent occurrence', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 3, 1),
          items: [_line('Oil Change', lineCost: 50)],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 1, 1),
          items: [_line('Brakes', lineCost: 50)],
        ),
      ]);
      expect(stats.topServiceName, 'Oil Change');
      expect(stats.topServiceCost, 50);
    });

    test('top service type needs positive cost', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          items: [_line('Inspection', lineCost: null)],
        ),
      ]);
      expect(stats.topServiceName, isNull);
      expect(stats.topServiceCost, isNull);
    });

    test('most expensive job takes max cost, ties → most recent, first item', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          totalCost: 500,
          items: [_line('Transmission'), _line('Clutch')],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 4, 5),
          totalCost: 500,
          items: [_line('Suspension')],
        ),
        _record(id: 'c', servicedOn: DateTime(2026, 2, 5), totalCost: 900),
      ]);
      expect(stats.mostExpensiveCost, 900);
      expect(stats.mostExpensiveOn, DateTime(2026, 2, 5));
      expect(stats.mostExpensiveFirstItem, isNull);

      final tied = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          totalCost: 500,
          items: [_line('Transmission')],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 4, 5),
          totalCost: 500,
          items: [_line('Suspension')],
        ),
      ]);
      expect(tied.mostExpensiveCost, 500);
      expect(tied.mostExpensiveOn, DateTime(2026, 4, 5));
      expect(tied.mostExpensiveFirstItem, 'Suspension');
    });

    test('period filter excludes out-of-range records', () {
      final stats = _compute(
        [
          _record(id: 'a', servicedOn: DateTime(2025, 12, 31), totalCost: 300),
          _record(id: 'b', servicedOn: DateTime(2026, 1, 1), totalCost: 100),
        ],
        period: const StatsPeriod(year: 2026),
      );
      expect(stats.totalRecords, 2);
      expect(stats.countInPeriod, 1);
      expect(stats.totalCost, 100);
      expect(stats.avgJobCost, 100);
    });
  });

  group('charts', () {
    test('monthly cost buckets by serviced-on month', () {
      final stats = _compute([
        _record(id: 'a', servicedOn: DateTime(2026, 3, 1), totalCost: 10),
        _record(id: 'b', servicedOn: DateTime(2026, 1, 1), totalCost: 20),
        _record(id: 'c', servicedOn: DateTime(2026, 1, 15), totalCost: 5),
      ]);
      expect(stats.monthlyCost, hasLength(2));
      expect(stats.monthlyCost.first.month, 1);
      expect(stats.monthlyCost.first.value, 25);
      expect(stats.monthlyCost.last.month, 3);
      expect(stats.monthlyCost.last.value, 10);
    });

    test('donut groups line costs by name', () {
      final stats = _compute([
        _record(
          id: 'a',
          servicedOn: DateTime(2026, 1, 5),
          items: [
            _line('Oil Change', lineCost: 80),
            _line('Brakes', lineCost: 20),
          ],
        ),
        _record(
          id: 'b',
          servicedOn: DateTime(2026, 2, 5),
          items: [_line('Oil Change', lineCost: 10)],
        ),
      ]);
      expect(stats.donut.slices, hasLength(2));
      expect(stats.donut.slices.first.key, 'Oil Change');
      expect(stats.donut.slices.first.value, 90);
      expect(stats.donut.slices.last.key, 'Brakes');
      expect(stats.donut.total, 110);
    });
  });

  group('DonutChart.fromTotals', () {
    test('keeps up to five groups sorted desc', () {
      final donut = DonutChart.fromTotals({
        'b': 2,
        'a': 5,
        'c': 3,
        'd': 1,
        'e': 4,
      });
      expect(donut.slices.map((s) => s.key), ['a', 'e', 'c', 'b', 'd']);
      expect(donut.total, 15);
    });

    test('collapses beyond five into top four plus Other', () {
      final donut = DonutChart.fromTotals({
        'a': 60,
        'b': 50,
        'c': 40,
        'd': 30,
        'e': 20,
        'f': 10,
        'g': 5,
      });
      expect(donut.slices, hasLength(5));
      expect(
        donut.slices.map((s) => s.key),
        ['a', 'b', 'c', 'd', DonutChart.otherKey],
      );
      expect(donut.slices.last.value, 35); // e + f + g
      expect(donut.total, 215);
    });

    test('omits zero and negative totals', () {
      final donut = DonutChart.fromTotals({'a': 10, 'b': 0, 'c': -5});
      expect(donut.slices, hasLength(1));
      expect(donut.slices.single.key, 'a');
    });

    test('all-zero totals render an empty chart', () {
      expect(DonutChart.fromTotals({'a': 0, 'b': 0}).isEmpty, isTrue);
    });
  });
}
