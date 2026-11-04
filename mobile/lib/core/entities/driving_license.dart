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
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? licenseNumber;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  LicenseStatus get status {
    final expiry = expiryDate;
    if (expiry == null) return LicenseStatus.none;
    final now = DateTime.now();
    final diff = DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (diff < 0) return LicenseStatus.expired;
    if (diff <= 30) return LicenseStatus.expiringSoon;
    return LicenseStatus.valid;
  }

  factory DrivingLicense.fromJson(Map<String, dynamic> json) {
    return DrivingLicense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      licenseNumber: json['license_number'] as String?,
      expiryDate: (json['license_expiry_date'] ?? json['expiry_date']) == null
          ? null
          : DateTime.parse(
              (json['license_expiry_date'] ?? json['expiry_date']) as String,
            ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'license_number': licenseNumber,
    'license_expiry_date': expiryDate?.toIso8601String().split('T').first,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
