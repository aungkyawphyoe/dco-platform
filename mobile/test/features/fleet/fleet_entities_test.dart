import 'package:dco_mobile/features/fleet/domain/entities/driver_assignment.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/org_vehicle.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_service_record.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FleetMode', () {
    test('parses driver and falls back to personal', () {
      expect(FleetMode.fromStorage('driver'), FleetMode.driver);
      expect(FleetMode.fromStorage(null), FleetMode.personal);
      expect(FleetMode.fromStorage('bogus'), FleetMode.personal);
      // Legacy stored fleet-management mode degrades to personal — fleet
      // management lives on the Fleet Portal.
      expect(FleetMode.fromStorage('fleet'), FleetMode.personal);
    });
  });

  group('OrgVehicle.fromJson', () {
    test('parses full showroom vehicle', () {
      final vehicle = OrgVehicle.fromJson({
        'id': 'veh-1',
        'name': 'Fleet Van 1',
        'nickname': 'Blue',
        'make': 'Toyota',
        'model': 'Hiace',
        'year': 2023,
        'license_plate': 'AB-1234',
        'vin': '1HGBH41JXMN109186',
        'color': 'White',
        'fuel_type': 'diesel',
        'mileage': 15000,
        'mileage_unit': 'km',
        'photo_media_id': 'media-1',
        'archived': false,
        'lifecycle_template': 'showroom',
        'status': 'reserved',
        'revenue_label': 'SKU-001',
        'assigned_driver_id': 'user-9',
        'added_at': '2026-01-01T00:00:00Z',
      });

      expect(vehicle.displayName, 'Blue');
      expect(vehicle.status, 'reserved');
      expect(vehicle.lifecycleTemplate, 'showroom');
      expect(vehicle.assignedDriverId, 'user-9');
      expect(vehicle.mileage, 15000);
    });

    test('applies defaults for sparse payloads', () {
      final vehicle = OrgVehicle.fromJson(const {'id': 'veh-2'});

      expect(vehicle.displayName, '');
      expect(vehicle.lifecycleTemplate, 'showroom');
      expect(vehicle.status, 'available');
      expect(vehicle.fuelType, 'petrol');
      expect(vehicle.mileage, 0);
      expect(vehicle.archived, isFalse);
      expect(vehicle.nickname, isNull);
    });
  });

  group('WorkOrder.fromJson', () {
    test('parses open work order with photos', () {
      final wo = WorkOrder.fromJson({
        'id': 'wo-1',
        'org_id': 'org-1',
        'vehicle_id': 'veh-1',
        'reported_by': 'user-2',
        'reported_at': '2026-02-01T08:00:00Z',
        'odometer_km': 42000,
        'issue_type': 'engine',
        'description': 'Rough idle',
        'urgency': 'high',
        'photos': ['media-a', 'media-b'],
        'status': 'in_progress',
        'assigned_to': 'mech-1',
      });

      expect(wo.isOpen, isTrue);
      expect(wo.photos, hasLength(2));
      expect(wo.urgency, 'high');
      expect(wo.assignedTo, 'mech-1');
    });

    test('completed order is closed and sparse payload gets defaults', () {
      final wo = WorkOrder.fromJson(const {'id': 'wo-2', 'status': 'completed'});

      expect(wo.isOpen, isFalse);
      expect(wo.status, 'completed');
      expect(wo.issueType, 'other');
      expect(wo.photos, isEmpty);
      expect(wo.urgency, 'medium');
    });
  });

  group('Inspection parsing', () {
    test('parses template with required and optional items', () {
      final template = InspectionTemplate.fromJson({
        'id': 'tpl-1',
        'org_id': 'org-1',
        'name': 'Pre-trip',
        'items': [
          {'item_name': 'Tyres', 'required': true},
          {'item_name': 'Radio', 'required': false},
        ],
      });

      expect(template.items, hasLength(2));
      expect(template.items.first.itemName, 'Tyres');
      expect(template.items.first.required, isTrue);
      expect(template.items.last.required, isFalse);
    });

    test('parses inspection results with defaults', () {
      final inspection = Inspection.fromJson({
        'id': 'insp-1',
        'org_id': 'org-1',
        'vehicle_id': 'veh-1',
        'status': 'failed',
        'items': [
          {'item_name': 'Tyres', 'result': 'not_ok', 'notes': 'Bald rear'},
        ],
      });

      expect(inspection.status, 'failed');
      expect(inspection.items.single.result, 'not_ok');
      expect(inspection.items.single.required, isFalse);
      expect(inspection.items.single.toJson(), {
        'item_name': 'Tyres',
        'result': 'not_ok',
        'notes': 'Bald rear',
      });
      expect(inspection.items.single.toJson().containsKey('photo_media_id'), isFalse);
    });
  });

  group('DriverServiceRecord.fromJson', () {
    test('parses a do-myself log with plan-linked item lines', () {
      final record = DriverServiceRecord.fromJson(const {
        'id': 'sr-1',
        'vehicle_id': 'veh-1',
        'serviced_on': '2026-10-01',
        'odometer': 950,
        'total_cost': 75,
        'items': [
          {'id': 'li-1', 'name': 'Oil change', 'line_cost': 75, 'plan_item_id': 'plan-1'},
        ],
      });

      expect(record.servicedOn, DateTime(2026, 10, 1));
      expect(record.odometer, 950);
      expect(record.totalCost, 75);
      expect(record.items.single.name, 'Oil change');
      expect(record.items.single.planItemId, 'plan-1');
    });

    test('history merges service records and maintenance work orders', () {
      final record = DriverHistoryEntry.serviceRecord(
        id: 'sr-1',
        servicedOn: DateTime(2026, 10, 1),
        odometer: 950,
        totalCost: 75,
        title: 'Oil change',
      );
      final workOrder = DriverHistoryEntry.workOrder(
        id: 'wo-1',
        servicedOn: DateTime(2026, 10, 5),
        odometer: 1000,
        title: 'Brake wear',
        workOrderStatus: 'reported',
      );

      expect(record.isWorkOrder, isFalse);
      expect(workOrder.isWorkOrder, isTrue);
      expect(workOrder.workOrderStatus, 'reported');
      final sorted = [record, workOrder]
        ..sort((a, b) => b.servicedOn.compareTo(a.servicedOn));
      expect(sorted.first.id, 'wo-1');
    });
  });

  group('DriverAssignment and DriverMyVehicle', () {
    test('active assignment status', () {
      final active = DriverAssignment.fromJson(const {
        'id': 'as-1',
        'org_id': 'org-1',
        'vehicle_id': 'veh-1',
        'driver_id': 'user-2',
        'status': 'active',
      });
      final past = DriverAssignment.fromJson(const {
        'id': 'as-2',
        'status': 'ended',
        'unassigned_at': '2026-03-01T00:00:00Z',
      });

      expect(active.isActive, isTrue);
      expect(past.isActive, isFalse);
    });

    test('driver context with and without a vehicle', () {
      final assigned = DriverMyVehicle.fromJson(const {
        'organization': {'id': 'org-1', 'name': 'Acme', 'type': 'business', 'plan': 'enterprise', 'status': 'active', 'role': 'org_driver'},
        'assignment': {'id': 'as-1', 'status': 'active'},
        'vehicle': {'id': 'veh-1', 'name': 'Van'},
      });
      final unassigned = DriverMyVehicle.fromJson(const {
        'organization': null,
        'assignment': null,
        'vehicle': null,
      });

      expect(assigned.hasAssignedVehicle, isTrue);
      expect(assigned.organization?.name, 'Acme');
      expect(assigned.vehicle?.id, 'veh-1');
      expect(unassigned.hasAssignedVehicle, isFalse);
      expect(unassigned.organization, isNull);
    });
  });
}
