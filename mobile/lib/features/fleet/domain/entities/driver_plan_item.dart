/// Plan item on the driver's assigned vehicle — `publicPlan` payload from
/// `GET /drivers/vehicles/{vehicleId}/plan-items` (online-first, no local
/// cache).
class DriverPlanItem {
  const DriverPlanItem({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.intervalDays,
    this.intervalDistance,
    this.nextDueMileage,
    this.nextDueOn,
    required this.enabled,
    this.notes,
    this.catalogKey,
    this.createdBy,
  });

  factory DriverPlanItem.fromJson(Map<String, dynamic> json) {
    return DriverPlanItem(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      intervalDays: (json['interval_days'] as num?)?.toInt(),
      intervalDistance: (json['interval_distance'] as num?)?.toDouble(),
      nextDueMileage: (json['next_due_mileage'] as num?)?.toInt(),
      nextDueOn: json['next_due_on'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      notes: json['notes'] as String?,
      catalogKey: json['catalog_key'] as String?,
      createdBy: json['created_by'] as String?,
    );
  }

  final String id;
  final String vehicleId;
  final String name;
  final int? intervalDays;

  /// Interval distance in kilometers.
  final double? intervalDistance;

  /// Next due odometer in kilometers.
  final int? nextDueMileage;

  /// Next due date, `YYYY-MM-DD`.
  final String? nextDueOn;
  final bool enabled;
  final String? notes;
  final String? catalogKey;
  final String? createdBy;

  /// Overdue when the due date has passed or the vehicle's mileage has
  /// reached the next-due mileage (either triggers it).
  bool isOverdue({required DateTime now, required int currentMileage}) {
    final dueOn = nextDueOn == null ? null : DateTime.tryParse(nextDueOn!);
    final overdueOn = dueOn != null &&
        DateTime(dueOn.year, dueOn.month, dueOn.day)
            .isBefore(DateTime(now.year, now.month, now.day));
    final overdueMileage =
        nextDueMileage != null && currentMileage >= nextDueMileage!;
    return overdueOn || overdueMileage;
  }
}

/// Suggested item from the vehicle's assigned maintenance template set —
/// `GET /drivers/vehicles/{vehicleId}/suggested-plan-items`.
class DriverSuggestedPlanItem {
  const DriverSuggestedPlanItem({
    required this.catalogKey,
    required this.name,
    this.intervalDays,
    this.intervalDistance,
    this.vehicleClass,
  });

  factory DriverSuggestedPlanItem.fromJson(Map<String, dynamic> json) {
    return DriverSuggestedPlanItem(
      catalogKey: json['catalog_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      intervalDays: (json['interval_days'] as num?)?.toInt(),
      intervalDistance: (json['interval_distance'] as num?)?.toDouble(),
      vehicleClass: json['vehicle_class'] as String?,
    );
  }

  final String catalogKey;
  final String name;
  final int? intervalDays;

  /// Interval distance in kilometers.
  final double? intervalDistance;
  final String? vehicleClass;

  /// The server requires a time interval, a distance interval, or both —
  /// items without either cannot be added to the plan.
  bool get hasInterval =>
      (intervalDays != null && intervalDays! > 0) ||
      (intervalDistance != null && intervalDistance! > 0);
}
