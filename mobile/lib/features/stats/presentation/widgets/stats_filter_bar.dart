import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/stats/domain/stats_period.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Year + Month dropdowns for a stats screen. Options are data-driven
/// (FRD stats.md): years descending, months within the selected year.
///
/// Changing the year resets Month to All so a stale month never points at a
/// year without that month.
class StatsFilterBar extends StatelessWidget {
  const StatsFilterBar({
    super.key,
    required this.period,
    required this.yearOptions,
    required this.monthOptions,
    required this.onChanged,
  });

  final StatsPeriod period;
  final List<int> yearOptions;
  final List<int> monthOptions;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space.s4,
        tokens.space.s2,
        tokens.space.s4,
        tokens.space.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(period.year),
              initialValue: period.year,
              decoration: InputDecoration(labelText: s.statsYear),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(s.statsAll)),
                for (final year in yearOptions)
                  DropdownMenuItem<int?>(value: year, child: Text('$year')),
              ],
              onChanged: (year) =>
                  onChanged(StatsPeriod(year: year)),
            ),
          ),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(period.month),
              initialValue: period.month,
              decoration: InputDecoration(labelText: s.statsMonth),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(s.statsAll)),
                for (final month in monthOptions)
                  DropdownMenuItem<int?>(
                    value: month,
                    child: Text(DateFormat.MMM().format(DateTime(2000, month))),
                  ),
              ],
              onChanged: (month) =>
                  onChanged(StatsPeriod(year: period.year, month: month)),
            ),
          ),
        ],
      ),
    );
  }
}
