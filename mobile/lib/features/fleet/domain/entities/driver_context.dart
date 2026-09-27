import 'package:dco_mobile/features/fleet/domain/entities/driver_assignment.dart';
import 'package:dco_mobile/features/fleet/domain/entities/organization.dart';
import 'package:dco_mobile/features/fleet/domain/entities/org_vehicle.dart';

/// `GET /v1/drivers/my-vehicle` — driver's restricted context.
class DriverMyVehicle {
  const DriverMyVehicle({
    required this.organization,
    required this.assignment,
    required this.vehicle,
  });

  factory DriverMyVehicle.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    final assignment = json['assignment'];
    final vehicle = json['vehicle'];
    return DriverMyVehicle(
      organization: organization is Map<String, dynamic>
          ? Organization.fromJson(organization)
          : null,
      assignment: assignment is Map<String, dynamic>
          ? DriverAssignment.fromJson(assignment)
          : null,
      vehicle: vehicle is Map<String, dynamic>
          ? OrgVehicle.fromJson(vehicle)
          : null,
    );
  }

  final Organization? organization;
  final DriverAssignment? assignment;
  final OrgVehicle? vehicle;

  bool get hasAssignedVehicle => assignment != null && vehicle != null;
}
