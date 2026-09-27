class OrgMember {
  const OrgMember({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    required this.invitedBy,
  });

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      userId: json['user_id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      role: json['role'] as String? ?? 'org_driver',
      joinedAt: json['joined_at'] as String?,
      invitedBy: json['invited_by'] as String?,
    );
  }

  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final String? joinedAt;
  final String? invitedBy;

  String get label =>
      (displayName == null || displayName!.trim().isEmpty) ? email : displayName!.trim();

  bool get isAdmin => role == 'org_admin';
}

class OrgWorkshop {
  const OrgWorkshop({
    required this.id,
    required this.name,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.addedAt,
  });

  factory OrgWorkshop.fromJson(Map<String, dynamic> json) {
    return OrgWorkshop(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      addedAt: json['added_at'] as String?,
    );
  }

  final String id;
  final String name;
  final String status;
  final String? contactEmail;
  final String? contactPhone;
  final String? addedAt;
}
