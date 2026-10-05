import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/stats/domain/expense_stats_calculator.dart';
import 'package:dco_mobile/features/stats/domain/stats_models.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({
  required String id,
  required DateTime incurredOn,
  double amount = 50,
  ExpenseCategory category = ExpenseCategory.parking,
}) {
  return Expense(
    id: id,
    vehicleId: 'v1',
    category: category,
    amount: amount,
    incurredOn: incurredOn,
    updatedAt: incurredOn,
    createdAt: incurredOn,
  );
}

ExpenseStats _compute(
  List<Expense> expenses, {
  StatsPeriod period = StatsPeriod.all,
}) {
  return ExpenseStats.compute(expenses: expenses, period: period);
}

void main() {
  group('KPIs', () {
    test('counts, sums, and averages per expense', () {
      final stats = _compute([
        _expense(id: 'a', incurredOn: DateTime(2026, 1, 4), amount: 40),
        _expense(id: 'b', incurredOn: DateTime(2026, 2, 4), amount: 60),
      ]);
      expect(stats.countInPeriod, 2);
      expect(stats.totalCost, 100);
      expect(stats.avgPerExpense, 50);
      expect(stats.hasAnyRecords, isTrue);
    });

    test('top category is the highest summed amount', () {
      final stats = _compute([
        _expense(
          id: 'a',
          incurredOn: DateTime(2026, 1, 4),
          amount: 30,
          category: ExpenseCategory.insurance,
        ),
        _expense(
          id: 'b',
          incurredOn: DateTime(2026, 2, 4),
          amount: 70,
          category: ExpenseCategory.tolls,
        ),
        _expense(
          id: 'c',
          incurredOn: DateTime(2026, 3, 4),
          amount: 25,
          category: ExpenseCategory.insurance,
        ),
      ]);
      expect(stats.topCategory, ExpenseCategory.tolls);
      expect(stats.topCategoryCost, 70);
    });

    test('top category ties resolve to the most recent occurrence', () {
      final stats = _compute([
        _expense(
          id: 'a',
          incurredOn: DateTime(2026, 5, 1),
          amount: 40,
          category: ExpenseCategory.parking,
        ),
        _expense(
          id: 'b',
          incurredOn: DateTime(2026, 1, 1),
          amount: 40,
          category: ExpenseCategory.tolls,
        ),
      ]);
      expect(stats.topCategory, ExpenseCategory.parking);
    });

    test('top category needs positive amount', () {
      final stats = _compute([
        _expense(
          id: 'a',
          incurredOn: DateTime(2026, 1, 1),
          amount: 0,
          category: ExpenseCategory.other,
        ),
      ]);
      expect(stats.topCategory, isNull);
      expect(stats.topCategoryCost, isNull);
    });

    test('most expensive expense takes max, ties → most recent, keeps category',
        () {
      final stats = _compute([
        _expense(
          id: 'a',
          incurredOn: DateTime(2026, 1, 1),
          amount: 200,
          category: ExpenseCategory.insurance,
        ),
        _expense(
          id: 'b',
          incurredOn: DateTime(2026, 6, 1),
          amount: 90,
          category: ExpenseCategory.parts,
        ),
      ]);
      expect(stats.mostExpensiveCost, 200);
      expect(stats.mostExpensiveOn, DateTime(2026, 1, 1));
      expect(stats.mostExpensiveCategory, ExpenseCategory.insurance);

      final tied = _compute([
        _expense(id: 'a', incurredOn: DateTime(2026, 1, 1), amount: 200),
        _expense(id: 'b', incurredOn: DateTime(2026, 6, 1), amount: 200),
      ]);
      expect(tied.mostExpensiveOn, DateTime(2026, 6, 1));
    });

    test('Year=All + Month=Jan matches every January across years', () {
      final stats = _compute(
        [
          _expense(id: 'a', incurredOn: DateTime(2024, 1, 10), amount: 10),
          _expense(id: 'b', incurredOn: DateTime(2025, 1, 10), amount: 20),
          _expense(id: 'c', incurredOn: DateTime(2025, 2, 10), amount: 40),
        ],
        period: const StatsPeriod(month: 1),
      );
      expect(stats.countInPeriod, 2);
      expect(stats.totalCost, 30);
    });
  });

  group('charts', () {
    test('monthly cost buckets by incurred-on month', () {
      final stats = _compute([
        _expense(id: 'a', incurredOn: DateTime(2026, 2, 1), amount: 15),
        _expense(id: 'b', incurredOn: DateTime(2026, 1, 1), amount: 25),
        _expense(id: 'c', incurredOn: DateTime(2026, 1, 20), amount: 5),
      ]);
      expect(stats.monthlyCost, hasLength(2));
      expect(stats.monthlyCost.first.month, 1);
      expect(stats.monthlyCost.first.value, 30);
      expect(stats.monthlyCost.last.month, 2);
      expect(stats.monthlyCost.last.value, 15);
    });

    test('donut groups amounts by category storage value', () {
      final stats = _compute([
        _expense(
          id: 'a',
          incurredOn: DateTime(2026, 1, 1),
          amount: 60,
          category: ExpenseCategory.tolls,
        ),
        _expense(
          id: 'b',
          incurredOn: DateTime(2026, 2, 1),
          amount: 40,
          category: ExpenseCategory.tolls,
        ),
        _expense(
          id: 'c',
          incurredOn: DateTime(2026, 3, 1),
          amount: 10,
          category: ExpenseCategory.parking,
        ),
        _expense(
          id: 'd',
          incurredOn: DateTime(2026, 4, 1),
          amount: 0,
          category: ExpenseCategory.parts,
        ),
      ]);
      expect(stats.donut.slices, hasLength(2));
      expect(stats.donut.slices.first.key, 'tolls');
      expect(stats.donut.slices.first.value, 100);
      expect(stats.donut.slices.last.key, 'parking');
      expect(stats.donut.total, 110);
    });

    test('seven positive categories collapse to top four plus Other', () {
      final stats = _compute([
        for (var i = 0; i < ExpenseCategory.values.length; i++)
          _expense(
            id: 'e$i',
            incurredOn: DateTime(2026, 1, i + 1),
            amount: (i + 1) * 10.0,
            category: ExpenseCategory.values[i],
          ),
      ]);
      expect(stats.donut.slices, hasLength(5));
      expect(stats.donut.slices.last.key, DonutChart.otherKey);
      // Sorted desc: other(70), parts(60), tolls(50), parking(40)
      // + Other-key(30 + 20 + 10 = 60).
      expect(stats.donut.slices.last.value, 60);
      expect(stats.donut.total, 280);
    });

    test('all-zero amounts render an empty donut', () {
      final stats = _compute([
        _expense(id: 'a', incurredOn: DateTime(2026, 1, 1), amount: 0),
      ]);
      expect(stats.donut.isEmpty, isTrue);
      expect(stats.countInPeriod, 1);
      expect(stats.totalCost, 0);
      expect(stats.avgPerExpense, 0);
    });
  });
}
