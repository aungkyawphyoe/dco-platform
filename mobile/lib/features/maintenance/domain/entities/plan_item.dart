class PlanItem {
  const PlanItem({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.enabled,
    required this.updatedAt,
    required this.createdAt,
    this.intervalDays,
    this.intervalDistance,
    this.nextDueMileage,
    this.nextDueOn,
    this.notes,
    this.catalogKey,
  });

  final String id;
  final String vehicleId;
  final String name;
  final int? intervalDays;
  final double? intervalDistance;
  final double? nextDueMileage;
  final DateTime? nextDueOn;
  final bool enabled;
  final String? notes;
  final String? catalogKey;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get recurring =>
      (intervalDays != null && intervalDays! > 0) ||
      (intervalDistance != null && intervalDistance! > 0);

  PlanItem copyWith({
    String? name,
    int? intervalDays,
    double? intervalDistance,
    double? nextDueMileage,
    DateTime? nextDueOn,
    bool? enabled,
    String? notes,
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
      intervalDays: clearIntervalDays ? null : intervalDays ?? this.intervalDays,
      intervalDistance: clearIntervalDistance
          ? null
          : intervalDistance ?? this.intervalDistance,
      nextDueMileage: clearNextDueMileage ? null : nextDueMileage ?? this.nextDueMileage,
      nextDueOn: clearNextDueOn ? null : nextDueOn ?? this.nextDueOn,
      enabled: enabled ?? this.enabled,
      notes: clearNotes ? null : notes ?? this.notes,
      catalogKey: catalogKey,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'name': name,
    'interval_days': intervalDays,
    'interval_distance': intervalDistance,
    'next_due_mileage': nextDueMileage,
    'next_due_on': nextDueOn?.toIso8601String().split('T').first,
    'enabled': enabled,
    'notes': notes,
    'catalog_key': catalogKey,
  };
}

class PlanItemDraft {
  const PlanItemDraft({
    required this.name,
    required this.recurring,
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
