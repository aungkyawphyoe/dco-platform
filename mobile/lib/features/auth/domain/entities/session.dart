class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.plan,
    required this.status,
    required this.emailVerified,
    this.displayName,
    this.activeVehicleId,
    this.vehicleLimit,
  });

  final String id;
  final String email;
  final String? displayName;
  final String role;
  final String plan;
  final String status;
  final bool emailVerified;
  final String? activeVehicleId;
  final int? vehicleLimit;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      emailVerified: json['email_verified'] as bool,
      activeVehicleId: json['active_vehicle_id'] as String?,
      vehicleLimit: json['vehicle_limit'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role,
    'plan': plan,
    'status': status,
    'email_verified': emailVerified,
    'active_vehicle_id': activeVehicleId,
    'vehicle_limit': vehicleLimit,
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

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
