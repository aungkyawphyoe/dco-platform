import 'package:dco_mobile/core/entities/driving_license.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.plan,
    required this.status,
    required this.emailVerified,
    required this.mustChangePassword,
    this.displayName,
    this.profilePhotoMediaId,
    this.contactPhone,
    this.address,
    this.activeVehicleId,
    this.vehicleLimit,
    this.createdAt,
    this.drivingLicense,
  });

  final String id;
  final String email;
  final String username;
  final String role;
  final String plan;
  final String status;
  final bool emailVerified;
  final bool mustChangePassword;
  final String? displayName;
  final String? profilePhotoMediaId;
  final String? contactPhone;
  final String? address;
  final String? activeVehicleId;
  final int? vehicleLimit;
  final String? createdAt;
  final DrivingLicense? drivingLicense;

  bool get isProfileComplete => displayName != null && displayName!.isNotEmpty;

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? profilePhotoMediaId,
    String? contactPhone,
    String? address,
    String? role,
    String? plan,
    String? status,
    bool? emailVerified,
    bool? mustChangePassword,
    String? activeVehicleId,
    int? vehicleLimit,
    String? createdAt,
    DrivingLicense? drivingLicense,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profilePhotoMediaId: profilePhotoMediaId ?? this.profilePhotoMediaId,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      emailVerified: emailVerified ?? this.emailVerified,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      activeVehicleId: activeVehicleId ?? this.activeVehicleId,
      vehicleLimit: vehicleLimit ?? this.vehicleLimit,
      createdAt: createdAt ?? this.createdAt,
      drivingLicense: drivingLicense ?? this.drivingLicense,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      profilePhotoMediaId: json['profile_photo_media_id'] as String?,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String?,
      role: json['role'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      emailVerified: json['email_verified'] as bool,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      activeVehicleId: json['active_vehicle_id'] as String?,
      vehicleLimit: json['vehicle_limit'] as int?,
      createdAt: json['created_at'] as String?,
      drivingLicense: json['driving_license'] is Map
          ? DrivingLicense.fromJson(
              Map<String, dynamic>.from(json['driving_license'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'display_name': displayName,
    'profile_photo_media_id': profilePhotoMediaId,
    'contact_phone': contactPhone,
    'address': address,
    'role': role,
    'plan': plan,
    'status': status,
    'email_verified': emailVerified,
    'must_change_password': mustChangePassword,
    'active_vehicle_id': activeVehicleId,
    'vehicle_limit': vehicleLimit,
    'created_at': createdAt,
    'driving_license': drivingLicense?.toJson(),
  };
}

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final User user;
  final int? expiresIn;

  Session copyWithUser(User newUser) {
    return Session(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: newUser,
      expiresIn: expiresIn,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
