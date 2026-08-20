import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/maintenance/domain/due_calculator.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/plan_item.dart';
import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PlanItemTile extends StatelessWidget {
  const PlanItemTile({
    super.key,
    required this.item,
    required this.vehicle,
    required this.now,
    this.lengthUnit = MileageUnit.mi,
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
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.md),
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
                      Text(
                        _dueLine(item, vehicle, overdue, lengthUnit),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: overdue ? tokens.feedback.overdue : tokens.text.caption,
                        ),
                      ),
                      SizedBox(height: tokens.space.s1),
                      Text(
                        DueCalculator.intervalLabel(
                          intervalDays: item.intervalDays,
                          intervalDistance: item.intervalDistance == null
                              ? null
                              : lengthUnit.toDisplay(item.intervalDistance!),
                          unit: lengthUnit.label,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _dueLine(PlanItem item, Vehicle vehicle, bool overdue, MileageUnit unit) {
  if (overdue) {
    final parts = <String>[];
    if (item.nextDueMileage != null && vehicle.mileage > item.nextDueMileage!) {
      parts.add(MileageFormat.labeled(vehicle.mileage - item.nextDueMileage!, unit));
    }
    if (item.nextDueOn != null) {
      final days = DateTime.now().difference(DueCalculator.dateOnly(item.nextDueOn!)).inDays;
      if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
    }
    if (parts.isEmpty) return 'Overdue';
    return 'Overdue by ${parts.join(' / ')}';
  }
  final bits = <String>[];
  if (item.nextDueMileage != null) {
    bits.add(MileageFormat.labeled(item.nextDueMileage!, unit));
  }
  if (item.nextDueOn != null) {
    bits.add(DateFormat.MMMd().format(item.nextDueOn!));
  }
  if (bits.isEmpty) return 'No due date set';
  return 'Due: ${bits.join(' / ')}';
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.record,
    required this.lengthUnit,
    this.onTap,
  });

  final ServiceRecord record;
  final MileageUnit lengthUnit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final money = NumberFormat.simpleCurrency().format(record.totalCost);
    final odometer = MileageFormat.labeled(record.odometer, lengthUnit);
    final workshop = record.workshopName;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, 0, tokens.space.s4, tokens.space.s3),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.md),
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
    );
  }
}
