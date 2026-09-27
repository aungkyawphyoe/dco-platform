/// Per-vehicle cost metric from the analytics endpoints.
class VehicleCost {
  const VehicleCost({
    required this.vehicleId,
    required this.tco,
    required this.costPerKm,
    required this.totalKmDriven,
    required this.maintenanceCost,
    required this.fuelCost,
    required this.wearCost,
    required this.utilizationRate,
    this.name,
    this.licensePlate,
  });

  factory VehicleCost.fromJson(Map<String, dynamic> json) {
    return VehicleCost(
      vehicleId: json['vehicle_id'] as String? ?? '',
      tco: (json['tco'] as num?)?.toDouble() ?? 0,
      costPerKm: (json['cost_per_km'] as num?)?.toDouble() ?? 0,
      totalKmDriven: (json['total_km_driven'] as num?)?.toInt() ?? 0,
      maintenanceCost: (json['maintenance_cost'] as num?)?.toDouble() ?? 0,
      fuelCost: (json['fuel_cost'] as num?)?.toDouble() ?? 0,
      wearCost: (json['wear_cost'] as num?)?.toDouble() ?? 0,
      utilizationRate: (json['utilization_rate'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      licensePlate: json['license_plate'] as String?,
    );
  }

  final String vehicleId;
  final double tco;
  final double costPerKm;
  final int totalKmDriven;
  final double maintenanceCost;
  final double fuelCost;
  final double wearCost;
  final int utilizationRate;
  final String? name;
  final String? licensePlate;
}

class FleetAnalytics {
  const FleetAnalytics({
    required this.vehicleCount,
    required this.totalFleetSpend,
    required this.averageCostPerKm,
    required this.lemonCount,
    required this.openWorkOrders,
    required this.activeAssignments,
    required this.upcomingMaintenanceCount,
    required this.vehicles,
  });

  factory FleetAnalytics.fromJson(Map<String, dynamic> json) {
    return FleetAnalytics(
      vehicleCount: (json['vehicle_count'] as num?)?.toInt() ?? 0,
      totalFleetSpend: (json['total_fleet_spend'] as num?)?.toDouble() ?? 0,
      averageCostPerKm: (json['average_cost_per_km'] as num?)?.toDouble() ?? 0,
      lemonCount: (json['lemon_count'] as num?)?.toInt() ?? 0,
      openWorkOrders: (json['open_work_orders'] as num?)?.toInt() ?? 0,
      activeAssignments: (json['active_assignments'] as num?)?.toInt() ?? 0,
      upcomingMaintenanceCount:
          (json['upcoming_maintenance_count'] as num?)?.toInt() ?? 0,
      vehicles: ((json['vehicles'] as List?) ?? const [])
          .map((e) => VehicleCost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int vehicleCount;
  final double totalFleetSpend;
  final double averageCostPerKm;
  final int lemonCount;
  final int openWorkOrders;
  final int activeAssignments;
  final int upcomingMaintenanceCount;
  final List<VehicleCost> vehicles;
}

class LemonReport {
  const LemonReport({required this.thresholdCostPerKm, required this.items});

  factory LemonReport.fromJson(Map<String, dynamic> json) {
    return LemonReport(
      thresholdCostPerKm:
          (json['threshold_cost_per_km'] as num?)?.toDouble() ?? 0,
      items: ((json['items'] as List?) ?? const [])
          .map((e) => VehicleCost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final double thresholdCostPerKm;
  final List<VehicleCost> items;
}
