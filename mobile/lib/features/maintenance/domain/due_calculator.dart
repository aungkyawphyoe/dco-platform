import '../../../core/units/mileage_unit.dart';
import 'entities/plan_item.dart';

enum PlanUrgency { overdue, dueSoon, scheduled, hidden }

class NextDue {
  const NextDue({this.on, this.mileage});

  final DateTime? on;
  final double? mileage;
}

/// How far in advance a plan item counts as "soon" (upcoming).
///
/// User-configurable in Settings → Reminders; drives both the in-app
/// Upcoming grouping and the local OS reminder schedule.
class DueThresholds {
  const DueThresholds({required this.soonDays, required this.soonDistanceKm});

  static const minDays = 7;
  static const maxDays = 60;
  static const minKm = 100.0;
  static const maxKm = 1000.0;
  static const stepKm = 100.0;

  static const defaults = DueThresholds(soonDays: 30, soonDistanceKm: 500);

  /// Days before the due date (7–60) that a plan item becomes upcoming.
  final int soonDays;

  /// Remaining distance in km (100–1000, 100 km steps) that a plan item
  /// becomes upcoming. Stored in km; compared against the odometer after
  /// converting to the canonical storage unit (miles).
  final double soonDistanceKm;

  /// Clamps [soonDays] to 7–60 and snaps [soonDistanceKm] to the 100 km grid
  /// between 100 and 1000.
  static DueThresholds fromValues({
    required int soonDays,
    required double soonDistanceKm,
  }) {
    final days = soonDays.clamp(minDays, maxDays).toInt();
    var km = (soonDistanceKm / stepKm).round() * stepKm;
    km = km.clamp(minKm, maxKm).toDouble();
    return DueThresholds(soonDays: days, soonDistanceKm: km);
  }

  /// Threshold converted to the canonical stored unit (miles).
  double get soonDistanceMiles => MileageUnit.km.toStorage(soonDistanceKm);

  @override
  bool operator ==(Object other) =>
      other is DueThresholds &&
      other.soonDays == soonDays &&
      other.soonDistanceKm == soonDistanceKm;

  @override
  int get hashCode => Object.hash(soonDays, soonDistanceKm);

  @override
  String toString() => 'DueThresholds($soonDays days, $soonDistanceKm km)';
}

/// Pure due-date / due-mileage math. Upcoming = overdue or due-soon.
abstract final class DueCalculator {
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
    required DueThresholds thresholds,
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
      } else if (dueOn.difference(today).inDays <= thresholds.soonDays) {
        dueSoon = true;
      }
    }
    if (dueMiles != null) {
      if (vehicleMileage >= dueMiles) {
        overdue = true;
      } else if (dueMiles - vehicleMileage <= thresholds.soonDistanceMiles) {
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

  static int compareSoonest(
    PlanItem a,
    PlanItem b,
    double mileage,
    DateTime now,
    DueThresholds thresholds,
  ) {
    final urgencyDelta = urgency(
      item: a,
      vehicleMileage: mileage,
      now: now,
      thresholds: thresholds,
    ).index.compareTo(
      urgency(item: b, vehicleMileage: mileage, now: now, thresholds: thresholds).index,
    );
    if (urgencyDelta != 0) return urgencyDelta;
    return remainingScore(a, mileage, now).compareTo(remainingScore(b, mileage, now));
  }

  static PlanItem? nearest({
    required List<PlanItem> items,
    required double vehicleMileage,
    required DateTime now,
    required DueThresholds thresholds,
  }) {
    final visible = items
        .where(
          (item) =>
              urgency(
                item: item,
                vehicleMileage: vehicleMileage,
                now: now,
                thresholds: thresholds,
              ) !=
              PlanUrgency.hidden,
        )
        .toList();
    if (visible.isEmpty) return null;
    visible.sort((a, b) => compareSoonest(a, b, vehicleMileage, now, thresholds));
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
      parts.add('${intervalDistance.round()} $unit');
    }
    if (parts.isEmpty) return 'One-time';
    return 'Every ${parts.join(' or ')}';
  }
}
