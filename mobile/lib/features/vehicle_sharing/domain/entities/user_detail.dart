import 'package:dco_mobile/core/entities/driving_license.dart';

/// Payload of `GET /v1/users/:userId/detail`.
///
/// Only reachable for yourself or for someone you share a vehicle with —
/// the API answers 403 otherwise, which the repository maps to `null`.
class UserDetail {
  const UserDetail({
    required this.id,
    required this.email,
    this.displayName,
    this.contactPhone,
    this.address,
    this.profilePhotoMediaId,
    required this.role,
    required this.plan,
    required this.status,
    required this.emailVerified,
    this.activeVehicleId,
    this.vehicleLimit,
    required this.createdAt,
    this.drivingLicense,
    this.ownedVehicleIds = const [],
    this.sharedVehicles = const [],
  });

  final String id;
  final String email;
  final String? displayName;
  final String? contactPhone;
  final String? address;
  final String? profilePhotoMediaId;
  final String role;
  final String plan;
  final String status;
  final bool emailVerified;
  final String? activeVehicleId;
  final int? vehicleLimit;
  final DateTime createdAt;
  final DrivingLicense? drivingLicense;
  final List<String> ownedVehicleIds;
  final List<UserSharedVehicle> sharedVehicles;

  String get label => displayName ?? email;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String?,
      profilePhotoMediaId: json['profile_photo_media_id'] as String?,
      role: json['role'] as String? ?? 'owner',
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      emailVerified: json['email_verified'] as bool? ?? false,
      activeVehicleId: json['active_vehicle_id'] as String?,
      vehicleLimit: json['vehicle_limit'] as int?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      drivingLicense: json['driving_license'] == null
          ? null
          : DrivingLicense.fromJson(
              json['driving_license'] as Map<String, dynamic>,
            ),
      ownedVehicleIds: ((json['owned_vehicles'] as List?) ?? const [])
          .map((e) => (e as Map<String, dynamic>)['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
      sharedVehicles: ((json['shared_vehicles'] as List?) ?? const [])
          .map((e) => UserSharedVehicle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A vehicle the target user holds a share on, as reported by
/// `GET /v1/users/:userId/detail`.
class UserSharedVehicle {
  const UserSharedVehicle({
    required this.id,
    required this.name,
    this.nickname,
    required this.accessLevel,
    this.ownerId,
  });

  final String id;
  final String name;
  final String? nickname;
  final String accessLevel;
  final String? ownerId;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return name;
  }

  factory UserSharedVehicle.fromJson(Map<String, dynamic> json) {
    return UserSharedVehicle(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nickname: json['nickname'] as String?,
      accessLevel: json['access_level'] as String? ?? 'view',
      ownerId: json['owner_id'] as String?,
    );
  }
}
