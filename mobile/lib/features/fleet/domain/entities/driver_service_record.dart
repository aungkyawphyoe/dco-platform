import 'package:dco_mobile/features/maintenance/domain/entities/service_record.dart';

/// Driver "Do myself" service record — created by
/// `POST /v1/drivers/vehicles/{vehicleId}/service-records`. Mirrors the
/// personal [ServiceRecord] shape for presentation parity.
class DriverServiceRecord {
  const DriverServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.servicedOn,
    required this.odometer,
    required this.totalCost,
    this.notes,
    this.items = const [],
  });

  factory DriverServiceRecord.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return DriverServiceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String? ?? '',
      servicedOn: DateTime.parse(json['serviced_on'] as String),
      odometer: (json['odometer'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      notes: json['notes'] as String?,
      items: items is List
          ? items
                .map(
                  (e) => ServiceLine(
                    id: e['id'] as String? ?? '',
                    name: e['name'] as String? ?? '',
                    planItemId: e['plan_item_id'] as String?,
                    lineCost: (e['line_cost'] as num?)?.toDouble(),
                  ),
                )
                .toList()
          : const [],
    );
  }

  final String id;
  final String vehicleId;
  final DateTime servicedOn;
  final double odometer;
  final double totalCost;
  final String? notes;
  final List<ServiceLine> items;
}

/// A row in the driver's merged maintenance history: a service record or a
/// maintenance-branch work order. Both are presented as completed/active
/// history entries.
class DriverHistoryEntry {
  const DriverHistoryEntry.serviceRecord({
    required this.id,
    required this.servicedOn,
    required this.odometer,
    required this.totalCost,
    this.title = '',
    this.notes,
    this.isWorkOrder = false,
  }) : workOrderStatus = null;

  const DriverHistoryEntry.workOrder({
    required this.id,
    required this.servicedOn,
    required this.odometer,
    required this.title,
    required this.workOrderStatus,
    this.totalCost,
    this.notes,
    this.isWorkOrder = true,
  });

  final String id;
  final DateTime servicedOn;
  final double odometer;
  final double? totalCost;
  final String title;
  final String? notes;
  final bool isWorkOrder;
  final String? workOrderStatus;
}
