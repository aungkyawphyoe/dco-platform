class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.plan,
    required this.status,
    required this.emailVerified,
    this.displayName,
    this.profilePhotoMediaId,
    this.contactPhone,
    this.address,
    this.activeVehicleId,
    this.vehicleLimit,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? profilePhotoMediaId;
  final String? contactPhone;
  final String? address;
  final String role;
  final String plan;
  final String status;
  final bool emailVerified;
  final String? activeVehicleId;
  final int? vehicleLimit;
  final String? createdAt;

  bool get isProfileComplete => displayName != null && displayName!.isNotEmpty;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      profilePhotoMediaId: json['profile_photo_media_id'] as String?,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String?,
      role: json['role'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      emailVerified: json['email_verified'] as bool,
      activeVehicleId: json['active_vehicle_id'] as String?,
      vehicleLimit: json['vehicle_limit'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'profile_photo_media_id': profilePhotoMediaId,
    'contact_phone': contactPhone,
    'address': address,
    'role': role,
    'plan': plan,
    'status': status,
    'email_verified': emailVerified,
    'active_vehicle_id': activeVehicleId,
    'vehicle_limit': vehicleLimit,
    'created_at': createdAt,
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
