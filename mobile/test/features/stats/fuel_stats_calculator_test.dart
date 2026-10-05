import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/features/fuel/domain/entities/fuel_log.dart';
import 'package:dco_mobile/features/stats/domain/fuel_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

FuelLog _log({
  required String id,
  required DateTime loggedOn,
  double amount = 40,
  double cost = 50,
  String unit = 'L',
  double? odometer,
  FuelLogKind kind = FuelLogKind.refuel,
  DateTime? createdAt,
}) {
  return FuelLog(
    id: id,
    userId: 'u1',
    vehicleId: 'v1',
    kind: kind,
    fuelTypeId: 'f1',
    fuelTypeName: kind == FuelLogKind.charge ? 'Electricity' : 'Petrol',
    unit: unit,
    loggedOn: loggedOn,
    amount: amount,
    cost: cost,
    odometer: odometer,
    updatedAt: loggedOn,
    createdAt: createdAt ?? loggedOn,
  );
}

FuelStats _compute(
  List<FuelLog> logs, {
  StatsPeriod period = StatsPeriod.all,
  MileageUnit lengthUnit = MileageUnit.km,
  FuelStatsMode mode = FuelStatsMode.refuel,
}) {
  return FuelStats.compute(
    logs: logs,
    period: period,
    lengthUnit: lengthUnit,
    mode: mode,
  );
}

void main() {
  group('StatsPeriod', () {
    test('month without year matches every year', () {
      const period = StatsPeriod(month: 1);
      expect(period.matches(DateTime(2024, 1, 5)), isTrue);
      expect(period.matches(DateTime(2026, 1, 31)), isTrue);
      expect(period.matches(DateTime(2026, 2, 1)), isFalse);
    });

    test('year narrows the month match', () {
      const period = StatsPeriod(year: 2025, month: 6);
      expect(period.matches(DateTime(2025, 6, 10)), isTrue);
      expect(period.matches(DateTime(2024, 6, 10)), isFalse);
      expect(period.matches(DateTime(2025, 7, 10)), isFalse);
    });

    test('year options descend, month options respect the year', () {
      final dates = [
        DateTime(2024, 3, 1),
        DateTime(2026, 3, 1),
        DateTime(2026, 7, 1),
        DateTime(2025, 11, 1),
      ];
      expect(statsYearOptions(dates), [2026, 2025, 2024]);
      expect(statsMonthOptions(dates), [3, 7, 11]);
      expect(statsMonthOptions(dates, year: 2026), [3, 7]);
      expect(statsMonthOptions(dates, year: 2024), [3]);
    });

    test('month label is MMM with a selected year and MMM yy for All', () {
      final jan = DateTime(2025, 1, 15);
      expect(statsMonthLabel(jan, selectedYear: 2025), 'Jan');
      expect(statsMonthLabel(jan, selectedYear: null), 'Jan 25');
    });
  });

  group('segment pairing', () {
    test('pairs consecutive readings; non-reading logs do not break pairs', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 1, 10), odometer: 100),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 20), odometer: 150),
        _log(id: 'c', loggedOn: DateTime(2026, 1, 30)),
        _log(id: 'd', loggedOn: DateTime(2026, 2, 10), odometer: 200),
      ]);
      expect(stats.segments, hasLength(2));
      expect(stats.totalDeltaMiles, 100);
      expect(stats.segments.first.on, DateTime(2026, 1, 20));
      expect(stats.segments.last.on, DateTime(2026, 2, 10));
    });

    test('decreasing pair is skipped without breaking its neighbor', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 100),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 10), odometer: 90),
        _log(id: 'c', loggedOn: DateTime(2026, 1, 20), odometer: 150),
      ]);
      expect(stats.segments, hasLength(1));
      expect(stats.hasSegments, isFalse);
      expect(stats.totalDeltaMiles, isNull);
      expect(stats.consumption, isNull);
      expect(stats.costPer100, isNull);
      expect(stats.countInPeriod, 3);
      expect(stats.totalCost, 150);
    });

    test('delta above the outlier bound is skipped (6,000 mi bound)', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 0),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 10), odometer: 7000),
      ]);
      expect(stats.segments, isEmpty);
    });

    test('bound follows the display unit (10,000 km ≈ 6,214 mi)', () {
      final within = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 0),
          _log(id: 'b', loggedOn: DateTime(2026, 1, 10), odometer: 6100),
        ],
        lengthUnit: MileageUnit.km,
      );
      expect(within.segments, hasLength(1));

      final beyond = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 0),
          _log(id: 'b', loggedOn: DateTime(2026, 1, 10), odometer: 6300),
        ],
        lengthUnit: MileageUnit.km,
      );
      expect(beyond.segments, isEmpty);
    });

    test('a segment needs both readings inside the period', () {
      final logs = [
        _log(id: 'a', loggedOn: DateTime(2025, 12, 31), odometer: 100),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 5), odometer: 150),
        _log(id: 'c', loggedOn: DateTime(2026, 1, 20), odometer: 200),
      ];
      final janOnly = _compute(logs, period: const StatsPeriod(month: 1));
      expect(janOnly.segments, hasLength(1));
      expect(janOnly.segments.single.deltaMiles, 50);

      final all = _compute(logs);
      expect(all.segments, hasLength(2));
    });

    test('ties order by created-at then id', () {
      final first = _log(
        id: 'b',
        loggedOn: DateTime(2026, 1, 10),
        odometer: 150,
        createdAt: DateTime(2026, 1, 10, 8),
      );
      final second = _log(
        id: 'a',
        loggedOn: DateTime(2026, 1, 10),
        odometer: 100,
        createdAt: DateTime(2026, 1, 10, 12),
      );
      final stats = _compute([
        first,
        second,
        _log(id: 'c', loggedOn: DateTime(2026, 1, 20), odometer: 200),
      ]);
      // created-at order puts b(150) before a(100): the b→a pair is
      // invalid, leaving only a→c. Ordering by id would yield two pairs.
      expect(stats.segments, hasLength(1));
      expect(stats.segments.single.deltaMiles, 100);
    });
  });

  group('refuel consumption and cost', () {
    test('km display with L volume → l/100 km and cost per 100 km', () {
      final stats = _compute(
        [
          _log(
            id: 'a',
            loggedOn: DateTime(2026, 1, 1),
            odometer: 100,
            cost: 0,
            amount: 0,
          ),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 162.1371192237334, // +62.137119... mi = 100 km
            amount: 8,
            cost: 80,
          ),
          _log(
            id: 'c',
            loggedOn: DateTime(2026, 2, 1),
            odometer: 224.2742384474668,
            amount: 8,
            cost: 80,
          ),
        ],
        lengthUnit: MileageUnit.km,
      );
      expect(stats.totalDeltaMiles, closeTo(124.2742384474668, 1e-9));
      expect(stats.consumption, closeTo(8.0, 1e-9));
      expect(stats.costPer100, closeTo(80.0, 1e-9));
    });

    test('km display with gal volume → l/100km', () {
      final stats = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 100, unit: 'gal'),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 160,
            amount: 2,
            cost: 10,
            unit: 'gal',
          ),
          _log(
            id: 'c',
            loggedOn: DateTime(2026, 1, 25),
            odometer: 220,
            amount: 2,
            cost: 10,
            unit: 'gal',
          ),
        ],
        lengthUnit: MileageUnit.km,
      );
      expect(stats.segments, hasLength(2));
      // Odometer stored in miles: 100→160→220 mi = 160.9→257.5→354.1 km
      // Delta = 193.1 km. Fuel = 4 gal = 15.14 L. Consumption = 15.14/1.931*100 = 7.84 L/100km
      expect(stats.consumption, closeTo(7.84, 0.02));
    });

    test('km display converts gal volume to liters', () {
      final stats = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 100, unit: 'gal'),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 162.1371192237334, // 100 km
            amount: 5,
            cost: 20,
            unit: 'gal',
          ),
          _log(
            id: 'c',
            loggedOn: DateTime(2026, 1, 25),
            odometer: 224.2742384474668,
            amount: 5,
            cost: 20,
            unit: 'gal',
          ),
        ],
        lengthUnit: MileageUnit.km,
      );
      // 10 gal over 200 km → liters/100 km.
      expect(stats.consumption, closeTo(5 * 3.785411784, 1e-9));
    });

    test('mixed volume units → consumption null, per-unit volume totals', () {
      final stats = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 100, unit: 'L', amount: 0, cost: 0),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 160,
            amount: 10,
            unit: 'L',
          ),
          _log(
            id: 'c',
            loggedOn: DateTime(2026, 1, 25),
            odometer: 220,
            amount: 4,
            unit: 'gal',
          ),
        ],
      );
      expect(stats.consumption, isNull);
      expect(stats.singleUnit, isNull);
      expect(stats.avgCostPerUnit, isNull);
      expect(stats.volumeByUnit, {'L': 10.0, 'gal': 4.0});
      expect(stats.totalDeltaMiles, 120);
      expect(stats.costPer100, isNotNull);
    });

    test('avg cost per unit is total cost divided by single-unit volume', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 1, 1), amount: 30, cost: 45),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 10), amount: 20, cost: 30),
      ]);
      expect(stats.volumeByUnit, {'L': 50.0});
      expect(stats.totalCost, 75);
      expect(stats.avgCostPerUnit, closeTo(1.5, 1e-9));
    });

    test('most expensive ties go to the most recent record', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 1, 1), cost: 90),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 20), cost: 90),
        _log(id: 'c', loggedOn: DateTime(2026, 1, 10), cost: 80),
      ]);
      expect(stats.mostExpensiveCost, 90);
      expect(stats.mostExpensiveOn, DateTime(2026, 1, 20));
    });
  });

  group('charge mode', () {
    test('efficiency is display distance divided by kWh', () {
      final stats = _compute(
        [
          _log(
            id: 'a',
            loggedOn: DateTime(2026, 1, 1),
            odometer: 100,
            amount: 0,
            cost: 0,
            unit: 'kWh',
            kind: FuelLogKind.charge,
          ),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 162.1371192237334, // 100 km
            amount: 20,
            cost: 12,
            unit: 'kWh',
            kind: FuelLogKind.charge,
          ),
          _log(
            id: 'c',
            loggedOn: DateTime(2026, 1, 25),
            odometer: 224.2742384474668,
            amount: 20,
            cost: 12,
            unit: 'kWh',
            kind: FuelLogKind.charge,
          ),
        ],
        lengthUnit: MileageUnit.km,
        mode: FuelStatsMode.charge,
      );
      expect(stats.mode, FuelStatsMode.charge);
      expect(stats.segments, hasLength(2));
      expect(stats.consumption, closeTo(5.0, 1e-9)); // 200 km / 40 kWh
      expect(stats.volumeByUnit, {'kWh': 40.0});
      expect(stats.avgCostPerUnit, closeTo(0.6, 1e-9));
    });
  });

  group('charts data', () {
    test('monthly cost buckets by record month, chronological', () {
      final stats = _compute([
        _log(id: 'a', loggedOn: DateTime(2026, 2, 3), cost: 10),
        _log(id: 'b', loggedOn: DateTime(2026, 1, 4), cost: 20),
        _log(id: 'c', loggedOn: DateTime(2026, 1, 20), cost: 5),
        _log(id: 'd', loggedOn: DateTime(2025, 12, 31), cost: 7),
      ]);
      expect(stats.monthlyCost, hasLength(3));
      expect(stats.monthlyCost.first.year, 2025);
      expect(stats.monthlyCost.first.month, 12);
      expect(stats.monthlyCost.first.value, 7);
      expect(stats.monthlyCost[1].value, 25);
      expect(stats.monthlyCost[2].value, 10);
    });

    test('efficiency points only exist for months with a usable segment', () {
      final stats = _compute(
        [
          _log(id: 'a', loggedOn: DateTime(2026, 1, 1), odometer: 100, amount: 0, cost: 0),
          _log(
            id: 'b',
            loggedOn: DateTime(2026, 1, 15),
            odometer: 162.1371192237334,
            amount: 8,
            cost: 80,
          ),
          _log(id: 'c', loggedOn: DateTime(2026, 2, 1), cost: 30),
          _log(id: 'd', loggedOn: DateTime(2026, 3, 1), cost: 40),
        ],
        lengthUnit: MileageUnit.km,
      );
      // January has the only segment; February and March are gaps.
      expect(stats.monthlyCost.map((m) => m.month), [1, 2, 3]);
      expect(stats.monthlyEfficiency, hasLength(1));
      expect(stats.monthlyEfficiency.single.month, 1);
      expect(stats.monthlyEfficiency.single.value, closeTo(8.0, 1e-9));
    });

    test('empty data yields empty charts but valid option lists', () {
      final stats = _compute([]);
      expect(stats.totalRecords, 0);
      expect(stats.hasAnyRecords, isFalse);
      expect(stats.monthlyCost, isEmpty);
      expect(stats.monthlyEfficiency, isEmpty);
      expect(stats.yearOptions, isEmpty);
      expect(stats.yearOptions, isEmpty);
    });

    test('period filter narrows counts and totals', () {
      final logs = [
        _log(id: 'a', loggedOn: DateTime(2025, 6, 1), cost: 100),
        _log(id: 'b', loggedOn: DateTime(2026, 6, 2), cost: 50),
        _log(id: 'c', loggedOn: DateTime(2026, 7, 3), cost: 20),
      ];
      final stats = _compute(logs, period: const StatsPeriod(year: 2026));
      expect(stats.totalRecords, 3);
      expect(stats.countInPeriod, 2);
      expect(stats.totalCost, 70);
      expect(stats.hasRecordsInPeriod, isTrue);

      final none = _compute(logs, period: const StatsPeriod(year: 2023));
      expect(none.hasRecordsInPeriod, isFalse);
      expect(none.hasAnyRecords, isTrue);
    });
  });
}
