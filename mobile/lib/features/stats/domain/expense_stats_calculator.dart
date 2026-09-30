import '../../expenses/domain/entities/expense.dart';
import 'stats_models.dart';
import 'stats_period.dart';

/// KPI set for Expense Stats, computed over the active vehicle's expenses
/// (FRD stats.md).
class ExpenseStats {
  const ExpenseStats({
    required this.totalRecords,
    required this.countInPeriod,
    required this.totalCost,
    required this.topCategory,
    required this.topCategoryCost,
    required this.mostExpensiveCost,
    required this.mostExpensiveOn,
    required this.mostExpensiveCategory,
    required this.monthlyCost,
    required this.donut,
    required this.yearOptions,
    required this.monthOptions,
  });

  final int totalRecords;
  final int countInPeriod;
  final double totalCost;

  /// Category with the highest summed amount (> 0); ties → most recent.
  final ExpenseCategory? topCategory;
  final double? topCategoryCost;

  final double? mostExpensiveCost;
  final DateTime? mostExpensiveOn;
  final ExpenseCategory? mostExpensiveCategory;

  final List<MonthValue> monthlyCost;

  /// Σ amount grouped by category (zero-amount omitted) → top four + Other
  /// when > 5.
  final DonutChart donut;

  final List<int> yearOptions;
  final List<int> monthOptions;

  bool get hasAnyRecords => totalRecords > 0;
  bool get hasRecordsInPeriod => countInPeriod > 0;

  double? get avgPerExpense =>
      countInPeriod > 0 ? totalCost / countInPeriod : null;

  static ExpenseStats compute({
    required List<Expense> expenses,
    required StatsPeriod period,
  }) {
    final dates = expenses.map((expense) => expense.incurredOn);
    final yearOptions = statsYearOptions(dates);
    final monthOptions = statsMonthOptions(dates, year: period.year);

    final inPeriod =
        expenses
            .where((expense) => period.matches(expense.incurredOn))
            .toList();

    var totalCost = 0.0;
    final amountByCategory = <ExpenseCategory, double>{};
    final lastByCategory = <ExpenseCategory, DateTime>{};
    Expense? mostExpensive;

    for (final expense in inPeriod) {
      totalCost += expense.amount;
      amountByCategory[expense.category] =
          (amountByCategory[expense.category] ?? 0) + expense.amount;
      final seen = lastByCategory[expense.category];
      if (seen == null || expense.incurredOn.isAfter(seen)) {
        lastByCategory[expense.category] = expense.incurredOn;
      }
      if (mostExpensive == null ||
          expense.amount > mostExpensive.amount ||
          (expense.amount == mostExpensive.amount &&
              expense.incurredOn.isAfter(mostExpensive.incurredOn))) {
        mostExpensive = expense;
      }
    }

    ExpenseCategory? topCategory;
    double topAmount = 0;
    amountByCategory.forEach((category, amount) {
      if (amount < topAmount) return;
      if (amount > topAmount) {
        topCategory = category;
        topAmount = amount;
        return;
      }
      final best = topCategory;
      if (best != null && lastByCategory[category]!.isAfter(lastByCategory[best]!)) {
        topCategory = category;
      }
    });

    final monthlyCost = MonthAccumulator();
    for (final expense in inPeriod) {
      monthlyCost.add(expense.incurredOn, expense.amount);
    }

    return ExpenseStats(
      totalRecords: expenses.length,
      countInPeriod: inPeriod.length,
      totalCost: totalCost,
      topCategory: topAmount > 0 ? topCategory : null,
      topCategoryCost: topAmount > 0 ? topAmount : null,
      mostExpensiveCost: mostExpensive?.amount,
      mostExpensiveOn: mostExpensive?.incurredOn,
      mostExpensiveCategory: mostExpensive?.category,
      monthlyCost: monthlyCost.values,
      donut: DonutChart.fromTotals({
        for (final entry in amountByCategory.entries)
          entry.key.storage: entry.value,
      }),
      yearOptions: yearOptions,
      monthOptions: monthOptions,
    );
  }
}
