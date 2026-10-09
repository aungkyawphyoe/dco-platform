/// Navigation snapshot from `GET /v1/me/entitlements`.
///
/// UI hint only: the API re-checks plan, membership, organization status,
/// and role on every protected operation.
class Entitlements {
  const Entitlements({
    required this.plan,
    required this.vehicleSharing,
    required this.organization,
    required this.features,
  });

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    return Entitlements(
      plan: json['plan'] as String? ?? 'free',
      vehicleSharing: VehicleSharingEntitlement.fromJson(
        (json['vehicle_sharing'] as Map<String, dynamic>?) ?? const {},
      ),
      organization: organization is Map<String, dynamic>
          ? OrganizationContext.fromJson(organization)
          : null,
      features: FleetFeatures.fromJson(
        (json['features'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  final String plan;
  final VehicleSharingEntitlement vehicleSharing;
  final OrganizationContext? organization;
  final FleetFeatures features;

  /// True only for active members of an active Enterprise organization.
  bool get canUseFleet => features.fleet && organization != null;
}

class VehicleSharingEntitlement {
  const VehicleSharingEntitlement({
    required this.available,
    required this.canShare,
    required this.perVehicle,
    required this.total,
    required this.activeShares,
  });

  factory VehicleSharingEntitlement.fromJson(Map<String, dynamic> json) {
    final limits = (json['limits'] as Map<String, dynamic>?) ?? const {};
    return VehicleSharingEntitlement(
      available: json['available'] as bool? ?? false,
      canShare: json['can_share'] as bool? ?? false,
      // `null` = unlimited (standard/fleet); missing key = free-plan caps.
      perVehicle:
          limits.containsKey('per_vehicle') ? limits['per_vehicle'] as int? : 1,
      total: limits.containsKey('total') ? limits['total'] as int? : 1,
      activeShares: json['active_shares'] as int? ?? 0,
    );
  }

  final bool available;
  final bool canShare;
  final int? perVehicle;
  final int? total;
  final int activeShares;
}

class OrganizationContext {
  const OrganizationContext({
    required this.id,
    required this.type,
    required this.plan,
    required this.status,
    required this.role,
  });

  factory OrganizationContext.fromJson(Map<String, dynamic> json) {
    return OrganizationContext(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'business',
      plan: json['plan'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'pending',
      role: json['role'] as String? ?? 'org_driver',
    );
  }

  final String id;
  final String type;
  final String plan;
  final String status;

  /// Org role: `org_admin` | `org_manager` | `org_mechanic` | `org_driver`.
  final String role;

  bool get isActiveEnterprise => plan == 'enterprise' && status == 'active';
  bool get isDriver => role == 'org_driver';
  bool get canManageOrg => role == 'org_admin';
  bool get canOperate => role == 'org_admin' || role == 'org_manager';
}

class FleetFeatures {
  const FleetFeatures({required this.vehicleSharing, required this.fleet});

  factory FleetFeatures.fromJson(Map<String, dynamic> json) {
    return FleetFeatures(
      vehicleSharing: json['vehicle_sharing'] as bool? ?? false,
      fleet: json['fleet'] as bool? ?? false,
    );
  }

  final bool vehicleSharing;
  final bool fleet;
}
