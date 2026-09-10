import 'package:dco_mobile/core/units/mileage_unit.dart';

enum FamilyStatus {
  active,
  archived;

  String get storage => name;

  static FamilyStatus parse(String value) {
    return FamilyStatus.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => throw FormatException('Unknown family status: $value'),
    );
  }
}

enum FamilyRole {
  primaryOwner,
  member,
  driver;

  String get storage => switch (this) {
    FamilyRole.primaryOwner => 'primary_owner',
    FamilyRole.member => 'member',
    FamilyRole.driver => 'driver',
  };

  String get label => switch (this) {
    FamilyRole.primaryOwner => 'Primary Owner',
    FamilyRole.member => 'Member',
    FamilyRole.driver => 'Driver',
  };

  static FamilyRole parse(String value) {
    return FamilyRole.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => throw FormatException('Unknown family role: $value'),
    );
  }
}

enum GrantPermission {
  full,
  driveOnly;

  String get storage => switch (this) {
    GrantPermission.full => 'full',
    GrantPermission.driveOnly => 'drive_only',
  };

  static GrantPermission parse(String value) {
    return GrantPermission.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => throw FormatException('Unknown grant permission: $value'),
    );
  }
}

enum LicenseStatus {
  valid,
  expiringSoon,
  expired,
  none;

  String get storage => switch (this) {
    LicenseStatus.valid => 'valid',
    LicenseStatus.expiringSoon => 'expiring_soon',
    LicenseStatus.expired => 'expired',
    LicenseStatus.none => 'none',
  };

  static LicenseStatus parse(String value) {
    return LicenseStatus.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => LicenseStatus.none,
    );
  }
}

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.shareCode,
    this.qrCodeData,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.archivedAt,
    this.myRole,
  });

  final String id;
  final String name;
  final String shareCode;
  final String? qrCodeData;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String? myRole;

  FamilyStatus get statusEnum => FamilyStatus.parse(status);

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      shareCode: json['share_code'] as String,
      qrCodeData: json['qr_code_data'] as String?,
      status: json['status'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      archivedAt: json['archived_at'] != null ? DateTime.parse(json['archived_at'] as String) : null,
      myRole: json['my_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'share_code': shareCode,
    'qr_code_data': qrCodeData,
    'status': status,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'archived_at': archivedAt?.toIso8601String(),
    'my_role': myRole,
  };
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    required this.vehicleCount,
    this.licenseStatus,
  });

  final String id;
  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final DateTime joinedAt;
  final String? invitedBy;
  final int vehicleCount;
  final String? licenseStatus;

  FamilyRole get roleEnum => FamilyRole.parse(role);
  LicenseStatus get licenseStatusEnum => licenseStatus != null ? LicenseStatus.parse(licenseStatus!) : LicenseStatus.none;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      invitedBy: json['invited_by'] as String?,
      vehicleCount: json['vehicle_count'] as int,
      licenseStatus: json['license_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'email': email,
    'display_name': displayName,
    'role': role,
    'joined_at': joinedAt.toIso8601String(),
    'invited_by': invitedBy,
    'vehicle_count': vehicleCount,
    'license_status': licenseStatus,
  };
}

class VehicleGrant {
  const VehicleGrant({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.grantedBy,
    required this.permission,
    required this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String userId;
  final String grantedBy;
  final String permission;
  final DateTime createdAt;

  GrantPermission get permissionEnum => GrantPermission.parse(permission);

  factory VehicleGrant.fromJson(Map<String, dynamic> json) {
    return VehicleGrant(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      userId: json['user_id'] as String,
      grantedBy: json['granted_by'] as String,
      permission: json['permission'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'user_id': userId,
    'granted_by': grantedBy,
    'permission': permission,
    'created_at': createdAt.toIso8601String(),
  };
}

class DrivingLicense {
  const DrivingLicense({
    required this.id,
    required this.userId,
    this.licenseNumber,
    this.issuingCountry,
    required this.expiryDate,
    this.categories,
    this.frontMediaId,
    this.backMediaId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? licenseNumber;
  final String? issuingCountry;
  final DateTime expiryDate;
  final String? categories;
  final String? frontMediaId;
  final String? backMediaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  LicenseStatus get status {
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return LicenseStatus.expired;
    if (diff <= 14) return LicenseStatus.expiringSoon;
    return LicenseStatus.valid;
  }

  factory DrivingLicense.fromJson(Map<String, dynamic> json) {
    return DrivingLicense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      licenseNumber: json['license_number'] as String?,
      issuingCountry: json['issuing_country'] as String?,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      categories: json['categories'] as String?,
      frontMediaId: json['front_media_id'] as String?,
      backMediaId: json['back_media_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'license_number': licenseNumber,
    'issuing_country': issuingCountry,
    'expiry_date': expiryDate.toIso8601String().split('T').first,
    'categories': categories,
    'front_media_id': frontMediaId,
    'back_media_id': backMediaId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class FamilyDocument {
  const FamilyDocument({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.category,
    this.notes,
    this.mediaId,
    required this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String name;
  final String category;
  final String? notes;
  final String? mediaId;
  final DateTime createdAt;

  factory FamilyDocument.fromJson(Map<String, dynamic> json) {
    return FamilyDocument(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      notes: json['notes'] as String?,
      mediaId: json['media_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AssignedDriver {
  const AssignedDriver({
    required this.userId,
    required this.displayName,
    required this.permission,
    required this.licenseStatus,
  });

  final String userId;
  final String displayName;
  final String permission;
  final String licenseStatus;

  GrantPermission get permissionEnum => GrantPermission.parse(permission);
  LicenseStatus get licenseStatusEnum => LicenseStatus.parse(licenseStatus);

  factory AssignedDriver.fromJson(Map<String, dynamic> json) {
    return AssignedDriver(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      permission: json['permission'] as String,
      licenseStatus: json['license_status'] as String,
    );
  }
}

class FamilyVehicleDetail {
  const FamilyVehicleDetail({
    required this.id,
    required this.userId,
    required this.name,
    this.nickname,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.vin,
    this.color,
    required this.fuelType,
    required this.mileage,
    required this.mileageUnit,
    this.purchaseDate,
    this.purchasePrice,
    this.photoMediaId,
    required this.archived,
    this.archivedAt,
    required this.updatedAt,
    required this.grants,
    required this.documents,
    required this.assignedDrivers,
  });

  final String id;
  final String userId;
  final String name;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final String fuelType;
  final double mileage;
  final String mileageUnit;
  final String? purchaseDate;
  final double? purchasePrice;
  final String? photoMediaId;
  final bool archived;
  final String? archivedAt;
  final DateTime updatedAt;
  final List<VehicleGrant> grants;
  final List<FamilyDocument> documents;
  final List<AssignedDriver> assignedDrivers;

  factory FamilyVehicleDetail.fromJson(Map<String, dynamic> json) {
    return FamilyVehicleDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String?,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      licensePlate: json['license_plate'] as String,
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      fuelType: json['fuel_type'] as String,
      mileage: (json['mileage'] as num).toDouble(),
      mileageUnit: json['mileage_unit'] as String,
      purchaseDate: json['purchase_date'] as String?,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      photoMediaId: json['photo_media_id'] as String?,
      archived: json['archived'] as bool,
      archivedAt: json['archived_at'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      grants: (json['grants'] as List).map((e) => VehicleGrant.fromJson(e)).toList(),
      documents: (json['documents'] as List).map((e) => FamilyDocument.fromJson(e)).toList(),
      assignedDrivers: (json['assigned_drivers'] as List).map((e) => AssignedDriver.fromJson(e)).toList(),
    );
  }
}

class FamilyVehicle {
  const FamilyVehicle({
    required this.id,
    required this.userId,
    required this.name,
    this.nickname,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.vin,
    this.color,
    required this.fuelType,
    required this.mileage,
    required this.mileageUnit,
    this.purchaseDate,
    this.purchasePrice,
    this.photoMediaId,
    required this.archived,
    this.archivedAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final String fuelType;
  final double mileage;
  final String mileageUnit;
  final String? purchaseDate;
  final double? purchasePrice;
  final String? photoMediaId;
  final bool archived;
  final String? archivedAt;
  final DateTime updatedAt;

  factory FamilyVehicle.fromJson(Map<String, dynamic> json) {
    return FamilyVehicle(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String?,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      licensePlate: json['license_plate'] as String,
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      fuelType: json['fuel_type'] as String,
      mileage: (json['mileage'] as num).toDouble(),
      mileageUnit: json['mileage_unit'] as String,
      purchaseDate: json['purchase_date'] as String?,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      photoMediaId: json['photo_media_id'] as String?,
      archived: json['archived'] as bool,
      archivedAt: json['archived_at'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class UserDetail {
  const UserDetail({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    required this.plan,
    required this.status,
    required this.emailVerified,
    this.activeVehicleId,
    this.vehicleLimit,
    required this.createdAt,
    this.familyId,
    this.familyRole,
    this.drivingLicense,
    required this.ownedVehicles,
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
  final DateTime createdAt;
  final String? familyId;
  final String? familyRole;
  final DrivingLicense? drivingLicense;
  final List<FamilyVehicle> ownedVehicles;

  FamilyRole get familyRoleEnum => familyRole != null ? FamilyRole.parse(familyRole!) : FamilyRole.member;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      emailVerified: json['email_verified'] as bool,
      activeVehicleId: json['active_vehicle_id'] as String?,
      vehicleLimit: json['vehicle_limit'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      familyId: json['family_id'] as String?,
      familyRole: json['family_role'] as String?,
      drivingLicense: json['driving_license'] != null ? DrivingLicense.fromJson(json['driving_license']) : null,
      ownedVehicles: (json['owned_vehicles'] as List).map((e) => FamilyVehicle.fromJson(e)).toList(),
    );
  }
}
