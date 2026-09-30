import 'package:intl/intl.dart';

/// Year / Month filter selection for a stats screen.
///
/// `null` on either field means "All" (the default on open — FRD stats.md).
/// A month without a year matches that calendar month across every year.
class StatsPeriod {
  const StatsPeriod({this.year, this.month});

  /// Selected year, or null for All.
  final int? year;

  /// Selected calendar month (1-12), or null for All.
  final int? month;

  static const all = StatsPeriod();

  bool matches(DateTime date) {
    if (year != null && date.year != year) return false;
    if (month != null && date.month != month) return false;
    return true;
  }
}

/// Distinct years present in [dates], descending. The UI prepends `All`.
List<int> statsYearOptions(Iterable<DateTime> dates) {
  final years = dates.map((date) => date.year).toSet().toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}

/// Distinct months present in [dates] within [year], ascending.
/// With `year == null`, months present in any year.
List<int> statsMonthOptions(Iterable<DateTime> dates, {int? year}) {
  final months = <int>{};
  for (final date in dates) {
    if (year != null && date.year != year) continue;
    months.add(date.month);
  }
  return months.toList()..sort();
}

/// Axis / chart label rule: `MMM` when a year is selected, `MMM yy` for All.
String statsMonthLabel(DateTime month, {int? selectedYear}) {
  if (selectedYear != null) return DateFormat.MMM().format(month);
  return DateFormat('MMM yy').format(month);
}
