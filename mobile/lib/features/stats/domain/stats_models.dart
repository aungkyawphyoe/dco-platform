/// One month's aggregated value for charts. [month] is 1-12.
class MonthValue {
  const MonthValue(this.year, this.month, this.value);

  final int year;
  final int month;
  final double value;

  DateTime get date => DateTime(year, month);
}

/// Sums [items] into chronological month buckets.
class MonthAccumulator {
  final _values = <DateTime, double>{};

  void add(DateTime date, double value) {
    final key = DateTime(date.year, date.month);
    _values[key] = (_values[key] ?? 0) + value;
  }

  List<MonthValue> get values {
    final months = [
      for (final entry in _values.entries)
        MonthValue(entry.key.year, entry.key.month, entry.value),
    ];
    months.sort((a, b) => a.date.compareTo(b.date));
    return months;
  }
}

/// A donut slice. [key] is a raw grouping key (expense category storage value,
/// service item name) or [DonutChart.otherKey] for the collapsed remainder.
class DonutSlice {
  const DonutSlice(this.key, this.value);

  final String key;
  final double value;
}

class DonutChart {
  const DonutChart(this.slices);

  static const otherKey = '\$other';

  final List<DonutSlice> slices;

  bool get isEmpty => slices.isEmpty;

  double get total => slices.fold(0.0, (sum, slice) => sum + slice.value);

  /// Groups positive totals desc; more than five groups → top four + Other.
  /// Zero and negative totals are omitted (FRD stats.md).
  factory DonutChart.fromTotals(Map<String, double> totals) {
    final positive = totals.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        return byValue != 0 ? byValue : a.key.compareTo(b.key);
      });
    if (positive.length <= 5) {
      return DonutChart([
        for (final entry in positive) DonutSlice(entry.key, entry.value),
      ]);
    }
    var rest = 0.0;
    for (final entry in positive.skip(4)) {
      rest += entry.value;
    }
    return DonutChart([
      for (final entry in positive.take(4)) DonutSlice(entry.key, entry.value),
      if (rest > 0) DonutSlice(otherKey, rest),
    ]);
  }
}
