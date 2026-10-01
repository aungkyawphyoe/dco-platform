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
