/// Navigation snapshot from `GET /v1/me/entitlements`.
///
/// UI hint only: the API re-checks plan, membership, organization status,
/// and role on every protected operation.
class Entitlements {
  const Entitlements({
    required this.plan,
    required this.family,
    required this.organization,
    required this.features,
  });

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    return Entitlements(
      plan: json['plan'] as String? ?? 'free',
      family: FamilyEntitlement.fromJson(
        (json['family'] as Map<String, dynamic>?) ?? const {},
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
  final FamilyEntitlement family;
  final OrganizationContext? organization;
  final FleetFeatures features;

  /// True only for active members of an active Enterprise organization.
  bool get canUseFleet => features.fleet && organization != null;
}

class FamilyEntitlement {
  const FamilyEntitlement({
    required this.available,
    required this.role,
    required this.canCreate,
    required this.canManage,
  });

  factory FamilyEntitlement.fromJson(Map<String, dynamic> json) {
    return FamilyEntitlement(
      available: json['available'] as bool? ?? false,
      role: json['role'] as String?,
      canCreate: json['can_create'] as bool? ?? false,
      canManage: json['can_manage'] as bool? ?? false,
    );
  }

  final bool available;
  final String? role;
  final bool canCreate;
  final bool canManage;
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
  const FleetFeatures({required this.family, required this.fleet});

  factory FleetFeatures.fromJson(Map<String, dynamic> json) {
    return FleetFeatures(
      family: json['family'] as bool? ?? false,
      fleet: json['fleet'] as bool? ?? false,
    );
  }

  final bool family;
  final bool fleet;
}
