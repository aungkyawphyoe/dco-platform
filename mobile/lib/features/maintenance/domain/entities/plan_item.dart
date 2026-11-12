class PlanItem {
  const PlanItem({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.enabled,
    required this.updatedAt,
    required this.createdAt,
    this.baselineDueOn,
    this.baselineDueMileage,
    this.manualOn,
    this.manualServiceId,
    this.baselineEnabled = true,
    this.timeCount,
    this.timeUnit,
    this.warningDays,
    this.warningDistance,
    this.intervalDays,
    this.intervalDistance,
    this.nextDueMileage,
    this.nextDueOn,
    this.notes,
    this.catalogKey,
    this.createdBy,
    this.initialServiceRequired = false,
  });

  final String id;
  final String vehicleId;
  final String name;
  final DateTime? baselineDueOn;
  final double? baselineDueMileage;
  final DateTime? manualOn;
  final String? manualServiceId;
  final bool baselineEnabled;
  final int? timeCount;
  final String? timeUnit;
  final int? warningDays;
  final double? warningDistance;
  final int? intervalDays;
  final double? intervalDistance;
  final double? nextDueMileage;
  final DateTime? nextDueOn;
  final bool enabled;
  final bool initialServiceRequired;
  final String? notes;
  final String? catalogKey;
  final String? createdBy;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get recurring =>
      (timeCount != null && timeCount! > 0) ||
      (intervalDays != null && intervalDays! > 0) ||
      (intervalDistance != null && intervalDistance! > 0);

  PlanItem copyWith({
    String? name,
    int? timeCount,
    String? timeUnit,
    int? warningDays,
    double? warningDistance,
    int? intervalDays,
    double? intervalDistance,
    double? nextDueMileage,
    DateTime? nextDueOn,
    bool? enabled,
    String? notes,
    String? createdBy,
    bool clearIntervalDays = false,
    bool clearIntervalDistance = false,
    bool clearNextDueMileage = false,
    bool clearNextDueOn = false,
    bool clearNotes = false,
  }) {
    return PlanItem(
      id: id,
      vehicleId: vehicleId,
      name: name ?? this.name,
      baselineDueOn: baselineDueOn,
      baselineDueMileage: baselineDueMileage,
      manualOn: manualOn,
      manualServiceId: manualServiceId,
      baselineEnabled: baselineEnabled,
      timeCount: timeCount ?? this.timeCount,
      timeUnit: timeUnit ?? this.timeUnit,
      warningDays: warningDays ?? this.warningDays,
      warningDistance: warningDistance ?? this.warningDistance,
      intervalDays: clearIntervalDays
          ? null
          : intervalDays ?? this.intervalDays,
      intervalDistance: clearIntervalDistance
          ? null
          : intervalDistance ?? this.intervalDistance,
      nextDueMileage: clearNextDueMileage
          ? null
          : nextDueMileage ?? this.nextDueMileage,
      nextDueOn: clearNextDueOn ? null : nextDueOn ?? this.nextDueOn,
      enabled: enabled ?? this.enabled,
      initialServiceRequired: initialServiceRequired,
      notes: clearNotes ? null : notes ?? this.notes,
      catalogKey: catalogKey,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'name': name,
    'baseline_due_on': baselineDueOn?.toIso8601String().split('T').first,
    'baseline_due_mileage': baselineDueMileage,
    'manual_on': manualOn?.toIso8601String().split('T').first,
    'manual_service_id': manualServiceId,
    'baseline_enabled': baselineEnabled,
    'time_count': timeCount,
    'time_unit': timeUnit,
    'warning_days': warningDays,
    'warning_distance': warningDistance,
    'interval_days': intervalDays,
    'interval_distance': intervalDistance,
    'next_due_mileage': nextDueMileage,
    'next_due_on': nextDueOn?.toIso8601String().split('T').first,
    'enabled': enabled,
    'initial_service_required': initialServiceRequired,
    'notes': notes,
    'catalog_key': catalogKey,
    'created_by': createdBy,
  };
}

class PlanItemDraft {
  const PlanItemDraft({
    required this.name,
    required this.recurring,
    this.timeCount,
    this.timeUnit,
    this.warningDays,
    this.warningDistance,
    this.intervalDays,
    this.intervalDistance,
    this.date,
    this.mileage,
    this.notes,
    this.catalogKey,
    this.enabled = true,
  });

  final String name;
  final bool recurring;
  final int? timeCount;
  final String? timeUnit;
  final int? warningDays;
  final double? warningDistance;
  final int? intervalDays;
  final double? intervalDistance;
  final DateTime? date;
  final double? mileage;
  final String? notes;
  final String? catalogKey;
  final bool enabled;
}

enum TimeIntervalUnit {
  days,
  months,
  years;

  String get label => switch (this) {
    TimeIntervalUnit.days => 'Days',
    TimeIntervalUnit.months => 'Months',
    TimeIntervalUnit.years => 'Years',
  };

  int toDays(int value) => switch (this) {
    TimeIntervalUnit.days => value,
    TimeIntervalUnit.months => value * 30,
    TimeIntervalUnit.years => value * 365,
  };

  static ({int value, TimeIntervalUnit unit}) fromDays(int days) {
    if (days >= 365 && days % 365 == 0) {
      return (value: days ~/ 365, unit: TimeIntervalUnit.years);
    }
    if (days >= 30 && days % 30 == 0) {
      return (value: days ~/ 30, unit: TimeIntervalUnit.months);
    }
    return (value: days, unit: TimeIntervalUnit.days);
  }
}
