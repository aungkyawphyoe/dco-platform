/// Organization as returned by `GET /v1/organizations/me`.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.plan,
    required this.status,
    required this.role,
    required this.contactEmail,
    required this.contactPhone,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'business',
      plan: json['plan'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'pending',
      role: json['role'] as String? ?? 'org_driver',
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
    );
  }

  final String id;
  final String name;
  final String type;
  final String plan;
  final String status;

  /// Org role: `org_admin` | `org_manager` | `org_mechanic` | `org_driver`.
  final String role;
  final String? contactEmail;
  final String? contactPhone;

  bool get isActiveEnterprise => plan == 'enterprise' && status == 'active';
  bool get isDriver => role == 'org_driver';
  bool get canManageOrg => role == 'org_admin';
  bool get canOperate => role == 'org_admin' || role == 'org_manager';
  bool get canAddVehicles => role == 'org_admin' || role == 'org_manager';
}

class MyOrganization {
  const MyOrganization({required this.organization, required this.fleetAccess});

  factory MyOrganization.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    return MyOrganization(
      organization: organization is Map<String, dynamic>
          ? Organization.fromJson(organization)
          : null,
      fleetAccess: json['fleet_access'] as bool? ?? false,
    );
  }

  /// Null when the user is not a member of any organization.
  final Organization? organization;

  /// True only when the organization is Enterprise and active.
  final bool fleetAccess;
}
