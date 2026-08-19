import 'entities/plan_item.dart';

enum PlanUrgency { overdue, dueSoon, scheduled, hidden }

class NextDue {
  const NextDue({this.on, this.mileage});

  final DateTime? on;
  final double? mileage;
}

/// Pure due-date / due-mileage math. Upcoming = overdue or due-soon.
abstract final class DueCalculator {
  static const soonDays = 30;
  static const soonDistance = 500.0;

  static DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static NextDue fromDraft({
    required PlanItemDraft draft,
    required DateTime now,
    required double currentMileage,
  }) {
    if (draft.recurring) {
      final startDate = draft.date ?? dateOnly(now);
      final startMiles = draft.mileage ?? currentMileage;
      return NextDue(
        on: draft.intervalDays != null ? addDays(startDate, draft.intervalDays!) : null,
        mileage: draft.intervalDistance != null ? startMiles + draft.intervalDistance! : null,
      );
    }
    return NextDue(on: draft.date == null ? null : dateOnly(draft.date!), mileage: draft.mileage);
  }

  static NextDue afterService({
    required PlanItem item,
    required DateTime servicedOn,
    required double odometer,
  }) {
    if (!item.recurring) {
      return const NextDue();
    }
    return NextDue(
      on: item.intervalDays != null ? addDays(dateOnly(servicedOn), item.intervalDays!) : null,
      mileage: item.intervalDistance != null ? odometer + item.intervalDistance! : null,
    );
  }

  static DateTime addDays(DateTime start, int days) => dateOnly(start).add(Duration(days: days));

  static PlanUrgency urgency({
    required PlanItem item,
    required double vehicleMileage,
    required DateTime now,
  }) {
    if (!item.enabled) return PlanUrgency.hidden;
    final today = dateOnly(now);
    final dueOn = item.nextDueOn == null ? null : dateOnly(item.nextDueOn!);
    final dueMiles = item.nextDueMileage;
    if (dueOn == null && dueMiles == null) return PlanUrgency.hidden;

    var overdue = false;
    var dueSoon = false;
    if (dueOn != null) {
      if (!dueOn.isAfter(today)) {
        overdue = true;
      } else if (dueOn.difference(today).inDays <= soonDays) {
        dueSoon = true;
      }
    }
    if (dueMiles != null) {
      if (vehicleMileage >= dueMiles) {
        overdue = true;
      } else if (dueMiles - vehicleMileage <= soonDistance) {
        dueSoon = true;
      }
    }
    if (overdue) return PlanUrgency.overdue;
    if (dueSoon) return PlanUrgency.dueSoon;
    return PlanUrgency.scheduled;
  }

  static bool isUpcoming(PlanUrgency value) =>
      value == PlanUrgency.overdue || value == PlanUrgency.dueSoon;

  /// Smaller is more due. Used to pick Dashboard "Next Maintenance" and sort lists.
  static int remainingScore(PlanItem item, double mileage, DateTime now) {
    final today = dateOnly(now);
    final days = item.nextDueOn == null
        ? 1 << 20
        : dateOnly(item.nextDueOn!).difference(today).inDays;
    final miles = item.nextDueMileage == null ? 1 << 20 : (item.nextDueMileage! - mileage).round();
    return days < miles ? days : miles;
  }

  static int compareSoonest(PlanItem a, PlanItem b, double mileage, DateTime now) {
    final urgencyDelta = urgency(
      item: a,
      vehicleMileage: mileage,
      now: now,
    ).index.compareTo(
      urgency(item: b, vehicleMileage: mileage, now: now).index,
    );
    if (urgencyDelta != 0) return urgencyDelta;
    return remainingScore(a, mileage, now).compareTo(remainingScore(b, mileage, now));
  }

  static PlanItem? nearest({
    required List<PlanItem> items,
    required double vehicleMileage,
    required DateTime now,
  }) {
    final visible = items
        .where(
          (item) =>
              urgency(item: item, vehicleMileage: vehicleMileage, now: now) != PlanUrgency.hidden,
        )
        .toList();
    if (visible.isEmpty) return null;
    visible.sort((a, b) => compareSoonest(a, b, vehicleMileage, now));
    return visible.first;
  }

  static String intervalLabel({int? intervalDays, double? intervalDistance, String unit = 'mi'}) {
    final parts = <String>[];
    if (intervalDays != null && intervalDays > 0) {
      final decoded = TimeIntervalUnit.fromDays(intervalDays);
      final noun = switch (decoded.unit) {
        TimeIntervalUnit.days => decoded.value == 1 ? 'day' : 'days',
        TimeIntervalUnit.months => decoded.value == 1 ? 'month' : 'months',
        TimeIntervalUnit.years => decoded.value == 1 ? 'year' : 'years',
      };
      parts.add('${decoded.value} $noun');
    }
    if (intervalDistance != null && intervalDistance > 0) {
      final miles = intervalDistance.truncateToDouble() == intervalDistance
          ? intervalDistance.toStringAsFixed(0)
          : intervalDistance.toString();
      parts.add('$miles $unit');
    }
    if (parts.isEmpty) return 'One-time';
    return 'Every ${parts.join(' or ')}';
  }
}
