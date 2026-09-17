import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PlanItemTile extends StatelessWidget {
  const PlanItemTile({
    super.key,
    required this.item,
    required this.vehicle,
    required this.now,
    this.lengthUnit = MileageUnit.km,
    this.onTap,
    this.leadingAction,
  });

  final PlanItem item;
  final Vehicle vehicle;
  final DateTime now;
  final MileageUnit lengthUnit;
  final VoidCallback? onTap;
  final Widget? leadingAction;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final urgency = DueCalculator.urgency(
      item: item,
      vehicleMileage: vehicle.mileage,
      now: now,
    );
    final overdue = urgency == PlanUrgency.overdue;
    final dueSoon = urgency == PlanUrgency.dueSoon;
    final accent = overdue
        ? tokens.feedback.overdue
        : dueSoon
        ? tokens.feedback.dueSoon
        : tokens.status.infoFg;
    final accentBg = overdue
        ? tokens.status.dangerBg
        : dueSoon
        ? tokens.status.warningBg
        : tokens.status.infoBg;

    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, 0, tokens.space.s4, tokens.space.s3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          boxShadow: tokens.shadows.card,
        ),
        child: Material(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            child: Padding(
              padding: EdgeInsets.all(tokens.space.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leadingAction ??
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accentBg,
                          borderRadius: BorderRadius.circular(tokens.radius.sm),
                        ),
                        child: Icon(
                          overdue
                              ? Icons.priority_high
                              : dueSoon
                                  ? Icons.schedule
                                  : Icons.info_outline,
                          color: accent,
                        ),
                      ),
                  SizedBox(width: tokens.space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: tokens.space.s1),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(tokens.radius.sm),
                          child: LinearProgressIndicator(
                            value: _progress(item, vehicle, now),
                            minHeight: 4,
                            backgroundColor: tokens.background.input,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        SizedBox(height: tokens.space.s2),
                        ..._dueLine(item, vehicle, overdue, lengthUnit, s).map(
                          (line) => Padding(
                            padding: EdgeInsets.only(bottom: tokens.space.s1),
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: overdue ? tokens.feedback.overdue : tokens.text.caption,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: tokens.space.s1),
                        Text(
                          _remainingLine(item, vehicle, now, lengthUnit, s),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.text.secondary,
                          ),
                        ),
                        if (item.notes != null && item.notes!.isNotEmpty) ...[
                          SizedBox(height: tokens.space.s1),
                          Text(
                            item.notes!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.text.caption,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _dueLine(PlanItem item, Vehicle vehicle, bool overdue, MileageUnit unit, AppLocalizations s) {
  if (overdue) {
    final parts = <String>[];
    if (item.nextDueMileage != null && vehicle.mileage > item.nextDueMileage!) {
      parts.add(MileageFormat.labeled(vehicle.mileage - item.nextDueMileage!, unit));
    }
    if (item.nextDueOn != null) {
      final days = DateTime.now().difference(DueCalculator.dateOnly(item.nextDueOn!)).inDays;
      if (days > 0) parts.add(s.planItemTileOverdueBy(days));
    }
    if (parts.isEmpty) return [s.planItemTileOverdue];
    return ['${s.planItemTileOverdue} ${s.planItemTileOverdueBy(0)}'];
  }
  final lines = <String>[];
  if (item.nextDueMileage != null) {
    lines.add('${s.planItemTileNextMileage}${MileageFormat.labeled(item.nextDueMileage!, unit)}');
  }
  if (item.nextDueOn != null) {
    lines.add('${s.planItemTileNextDate}${DateFormat.yMMMd().format(item.nextDueOn!)}');
  }
  if (lines.isEmpty) return [s.planItemTileNoDueDate];
  return lines;
}

/// Returns the higher of the mileage fraction and the time fraction as the
/// progress bar value (clamped to [0, 1]). Falls back to null when neither
/// dimension has a usable interval, in which case Flutter renders the bar as
/// indeterminate-free empty track.
double? _progress(PlanItem item, Vehicle vehicle, DateTime now) {
  double? milesFrac;
  if (item.nextDueMileage != null && item.intervalDistance != null && item.intervalDistance! > 0) {
    final start = item.nextDueMileage! - item.intervalDistance!;
    final span = item.nextDueMileage! - start;
    if (span > 0) {
      milesFrac = ((vehicle.mileage - start) / span).clamp(0.0, 1.0);
    }
  }
  double? daysFrac;
  if (item.nextDueOn != null && item.intervalDays != null && item.intervalDays! > 0) {
    final start = item.nextDueOn!.subtract(Duration(days: item.intervalDays!));
    final span = item.nextDueOn!.difference(start).inDays.toDouble();
    if (span > 0) {
      daysFrac = (DueCalculator.dateOnly(now).difference(start).inDays / span).clamp(0.0, 1.0);
    }
  }
  if (milesFrac == null && daysFrac == null) return null;
  final a = milesFrac ?? 0;
  final b = daysFrac ?? 0;
  return a > b ? a : b;
}

String _remainingLine(PlanItem item, Vehicle vehicle, DateTime now, MileageUnit unit, AppLocalizations s) {
  final parts = <String>[];
  if (item.nextDueMileage != null) {
    final remaining = item.nextDueMileage! - vehicle.mileage;
    if (remaining >= 0) {
      parts.add('${s.planItemTileRemaining}${MileageFormat.labeled(remaining, unit)}');
    }
  }
  if (item.nextDueOn != null) {
    final days = DueCalculator.dateOnly(item.nextDueOn!).difference(DueCalculator.dateOnly(now)).inDays;
    if (days >= 0) {
      parts.add('${s.planItemTileTimeLeft}$days ${days == 1 ? s.planItemTileDay : s.planItemTileDays}');
    }
  }
  return parts.join('  ·  ');
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.record,
    required this.lengthUnit,
    required this.currency,
    this.onTap,
  });

  final ServiceRecord record;
  final MileageUnit lengthUnit;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final money = MoneyFormat.labeled(record.totalCost, currency);
    final odometer = MileageFormat.labeled(record.odometer, lengthUnit);
    final workshop = record.workshopName;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, 0, tokens.space.s4, tokens.space.s3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          boxShadow: tokens.shadows.card,
        ),
        child: Material(
          color: tokens.background.card,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            child: Padding(
              padding: EdgeInsets.all(tokens.space.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(record.servicedOn),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                      ),
                      const Spacer(),
                      Text(
                        money,
                        style: GoogleFonts.ibmPlexMono(
                          color: tokens.text.secondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space.s1),
                  Text(record.title, style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: tokens.space.s1),
                  Text(
                    workshop == null || workshop.isEmpty ? odometer : '$odometer  $workshop',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
