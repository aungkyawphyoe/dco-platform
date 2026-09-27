import 'package:dco_mobile/features/fleet/domain/entities/driver_assignment.dart';
import 'package:dco_mobile/features/fleet/domain/entities/driver_context.dart';
import 'package:dco_mobile/features/fleet/domain/entities/fleet_mode.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/org_vehicle.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization_member.dart';
import 'package:dco_mobile/features/fleet/domain/entities/shift_mileage.dart';
import 'package:dco_mobile/features/fleet/domain/entities/vehicle_cost.dart';
import 'package:dco_mobile/features/fleet/domain/entities/warranty_template.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FleetMode', () {
    test('parses known values and falls back to personal', () {
      expect(FleetMode.fromStorage('fleet'), FleetMode.fleet);
      expect(FleetMode.fromStorage('driver'), FleetMode.driver);
      expect(FleetMode.fromStorage(null), FleetMode.personal);
      expect(FleetMode.fromStorage('bogus'), FleetMode.personal);
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

  group('ShiftMileage.fromJson', () {
    test('active shift has no end and no km driven', () {
      final shift = ShiftMileage.fromJson(const {
        'id': 'shift-1',
        'start_odometer_km': 1000,
        'start_at': '2026-03-01T07:00:00Z',
      });

      expect(shift.isActive, isTrue);
      expect(shift.endOdometerKm, isNull);
      expect(shift.kmDriven, isNull);
    });

    test('ended shift exposes driven kilometres', () {
      final shift = ShiftMileage.fromJson(const {
        'id': 'shift-2',
        'start_odometer_km': 1000,
        'end_odometer_km': 1085,
        'km_driven': 85,
        'end_at': '2026-03-01T17:00:00Z',
      });

      expect(shift.isActive, isFalse);
      expect(shift.kmDriven, 85);
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

  group('Organization members and workshops', () {
    test('member label prefers display name and admin flag', () {
      final named = OrgMember.fromJson(const {
        'user_id': 'u1',
        'email': 'a@b.test',
        'display_name': 'Aye',
        'role': 'org_admin',
      });
      final anonymous = OrgMember.fromJson(const {'user_id': 'u2', 'email': 'b@c.test'});

      expect(named.label, 'Aye');
      expect(named.isAdmin, isTrue);
      expect(anonymous.label, 'b@c.test');
      expect(anonymous.role, 'org_driver');
      expect(anonymous.isAdmin, isFalse);
    });

    test('workshop defaults to pending', () {
      final workshop = OrgWorkshop.fromJson(const {'id': 'ws-1', 'name': 'Bay Auto'});

      expect(workshop.status, 'pending');
      expect(workshop.contactEmail, isNull);
    });
  });

  group('VehicleCost and analytics', () {
    test('parses analytics with nested vehicle costs', () {
      final analytics = FleetAnalytics.fromJson(const {
        'vehicle_count': 3,
        'total_fleet_spend': 1234.5,
        'average_cost_per_km': 0.42,
        'lemon_count': 1,
        'open_work_orders': 2,
        'active_assignments': 3,
        'upcoming_maintenance_count': 4,
        'vehicles': [
          {
            'vehicle_id': 'veh-1',
            'tco': 900.0,
            'cost_per_km': 0.5,
            'total_km_driven': 1800,
            'utilization_rate': 80,
            'name': 'Van 1',
            'license_plate': 'AB-1234',
          },
        ],
      });

      expect(analytics.vehicleCount, 3);
      expect(analytics.totalFleetSpend, 1234.5);
      expect(analytics.lemonCount, 1);
      expect(analytics.vehicles.single.utilizationRate, 80);
      expect(analytics.vehicles.single.licensePlate, 'AB-1234');
    });

    test('sparse analytics payload gets zeroes', () {
      final analytics = FleetAnalytics.fromJson(const {});

      expect(analytics.vehicleCount, 0);
      expect(analytics.averageCostPerKm, 0);
      expect(analytics.vehicles, isEmpty);
    });

    test('lemon report carries threshold and items', () {
      final report = LemonReport.fromJson(const {
        'threshold_cost_per_km': 0.6,
        'items': [
          {'vehicle_id': 'veh-9', 'cost_per_km': 0.9},
        ],
      });

      expect(report.thresholdCostPerKm, 0.6);
      expect(report.items.single.vehicleId, 'veh-9');
    });
  });

  group('WarrantyTemplate.fromJson', () {
    test('parses template with coverage lists', () {
      final template = WarrantyTemplate.fromJson(const {
        'id': 'wt-1',
        'org_id': 'org-1',
        'name': '2y/40k',
        'duration_years': 2,
        'mileage_limit_km': 40000,
        'coverage_categories': ['engine', 'gearbox'],
        'exclusions': 'Wear items',
        'approved_workshop_ids': ['ws-1'],
      });

      expect(template.durationYears, 2);
      expect(template.mileageLimitKm, 40000);
      expect(template.coverageCategories, ['engine', 'gearbox']);
      expect(template.approvedWorkshopIds, ['ws-1']);
    });

    test('defaults duration and empty lists', () {
      final template = WarrantyTemplate.fromJson(const {'id': 'wt-2'});

      expect(template.durationYears, 1);
      expect(template.coverageCategories, isEmpty);
      expect(template.approvedWorkshopIds, isEmpty);
    });
  });
}
