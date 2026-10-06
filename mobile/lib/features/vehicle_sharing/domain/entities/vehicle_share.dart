import 'dart:convert';

/// Access level granted on a single shared vehicle.
///
/// Mirrors the `share_access` enum on the API (`view` | `add_edit_own`).
enum ShareAccessLevel {
  view('view'),
  addEditOwn('add_edit_own');

  const ShareAccessLevel(this.storage);

  final String storage;

  static ShareAccessLevel parse(String value) {
    return ShareAccessLevel.values.firstWhere(
      (level) => level.storage == value,
      orElse: () => ShareAccessLevel.view,
    );
  }
}

/// Lifecycle of a share row: invited → active, or revoked by the owner.
enum ShareStatus {
  pending('pending'),
  active('active'),
  revoked('revoked');

  const ShareStatus(this.storage);

  final String storage;

  static ShareStatus parse(String value) {
    return ShareStatus.values.firstWhere(
      (status) => status.storage == value,
      orElse: () => ShareStatus.pending,
    );
  }
}

/// How a share was handed out — email invitation vs. code/QR.
enum ShareMethod {
  email('email'),
  codeQr('code_qr');

  const ShareMethod(this.storage);

  final String storage;
}

/// One row of `GET /v1/vehicles/:id/shares` — a user holding access.
class VehicleShare {
  const VehicleShare({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.grantedBy,
    required this.accessLevel,
    required this.status,
    required this.createdAt,
    this.invitedEmail,
    this.shareCode,
    this.acceptedAt,
    this.displayName,
    this.email,
  });

  final String id;
  final String vehicleId;
  final String userId;
  final String? grantedBy;
  final ShareAccessLevel accessLevel;
  final ShareStatus status;
  final DateTime createdAt;
  final String? invitedEmail;
  final String? shareCode;
  final DateTime? acceptedAt;
  final String? displayName;
  final String? email;

  String get label => displayName ?? email ?? invitedEmail ?? userId;

  bool get isActive => status == ShareStatus.active;

  factory VehicleShare.fromJson(Map<String, dynamic> json) {
    return VehicleShare(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      grantedBy: json['granted_by'] as String?,
      accessLevel: ShareAccessLevel.parse(
        json['access_level'] as String? ?? 'view',
      ),
      status: ShareStatus.parse(json['status'] as String? ?? 'pending'),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      invitedEmail: json['invited_email'] as String?,
      shareCode: json['share_code'] as String?,
      acceptedAt: _parseDate(json['accepted_at']),
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'user_id': userId,
    'granted_by': grantedBy,
    'access_level': accessLevel.storage,
    'status': status.storage,
    'invited_email': invitedEmail,
    'share_code': shareCode,
    'accepted_at': acceptedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'display_name': displayName,
    'email': email,
  };
}

/// One row of `GET /v1/vehicles/:id/shares` → `pending_invites`.
class ShareInvitation {
  const ShareInvitation({
    required this.id,
    required this.vehicleId,
    required this.accessLevel,
    required this.expiresAt,
    required this.createdAt,
    this.invitedEmail,
    this.shareCode,
    this.acceptedAt,
  });

  final String id;
  final String vehicleId;
  final String? invitedEmail;
  final ShareAccessLevel accessLevel;
  final String? shareCode;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory ShareInvitation.fromJson(Map<String, dynamic> json) {
    return ShareInvitation(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String? ?? '',
      invitedEmail: json['invited_email'] as String?,
      accessLevel: ShareAccessLevel.parse(
        json['access_level'] as String? ?? 'view',
      ),
      shareCode: json['share_code'] as String?,
      expiresAt: _parseDate(json['expires_at']) ?? DateTime.now(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      acceptedAt: _parseDate(json['accepted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'invited_email': invitedEmail,
    'access_level': accessLevel.storage,
    'share_code': shareCode,
    'expires_at': expiresAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'accepted_at': acceptedAt?.toIso8601String(),
  };
}

/// Plan caps returned alongside the share list.
class ShareLimits {
  const ShareLimits({
    required this.perVehicle,
    required this.total,
    this.activeOnVehicle = 0,
  });

  final int perVehicle;
  final int total;
  final int activeOnVehicle;

  bool get atVehicleLimit => activeOnVehicle >= perVehicle;

  factory ShareLimits.fromJson(Map<String, dynamic> json) {
    return ShareLimits(
      perVehicle: json['per_vehicle'] as int? ?? 1,
      total: json['total'] as int? ?? 3,
      activeOnVehicle: json['active_on_vehicle'] as int? ?? 0,
    );
  }
}

/// Payload of `POST /v1/vehicles/:id/shares` — the freshly created
/// invitation plus, for the code/QR path, the share code and QR payload.
class CreatedShare {
  const CreatedShare({
    required this.invitation,
    this.inviteToken,
    this.inviteUrl,
    this.shareCode,
    this.qrCodeData,
    this.joinUrl,
  });

  final ShareInvitation invitation;
  final String? inviteToken;
  final String? inviteUrl;
  final String? shareCode;
  final String? qrCodeData;
  final String? joinUrl;

  factory CreatedShare.fromJson(Map<String, dynamic> json) {
    return CreatedShare(
      invitation: ShareInvitation.fromJson(json),
      inviteToken: json['invite_token'] as String?,
      inviteUrl: json['invite_url'] as String?,
      shareCode: json['share_code'] as String?,
      qrCodeData: json['qr_code_data'] == null
          ? null
          : json['qr_code_data'] is String
          ? json['qr_code_data'] as String
          : _encode(json['qr_code_data']),
      joinUrl: json['join_url'] as String?,
    );
  }
}

/// Full owner-side view of one vehicle's sharing state.
class VehicleSharesDetail {
  const VehicleSharesDetail({
    required this.vehicleId,
    required this.vehicleName,
    required this.licensePlate,
    required this.shares,
    required this.pendingInvites,
    required this.limits,
    this.shareCode,
    this.qrCodeData,
  });

  final String vehicleId;
  final String vehicleName;
  final String licensePlate;
  final List<VehicleShare> shares;
  final List<ShareInvitation> pendingInvites;
  final ShareLimits limits;
  final String? shareCode;
  final String? qrCodeData;

  List<VehicleShare> get activeShares =>
      shares.where((share) => share.isActive).toList();

  /// The outstanding code/QR invitation for this vehicle, if one exists.
  ShareInvitation? get codeInvitation {
    for (final invite in pendingInvites) {
      if (invite.shareCode != null && invite.shareCode!.isNotEmpty) {
        return invite;
      }
    }
    return null;
  }

  String? get effectiveShareCode {
    final code = shareCode;
    if (code != null && code.isNotEmpty) return code;
    return codeInvitation?.shareCode;
  }

  /// Payload a scanner reads back — mirrors the deep-link route.
  String? get joinUrl {
    final code = effectiveShareCode;
    return code == null ? null : 'dco://vehicle/share/join?code=$code';
  }

  factory VehicleSharesDetail.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map<String, dynamic>?) ?? const {};
    return VehicleSharesDetail(
      vehicleId: vehicle['id'] as String? ?? json['vehicle_id'] as String? ?? '',
      vehicleName:
          (vehicle['nickname'] as String?) ??
          (vehicle['name'] as String?) ??
          '',
      licensePlate: vehicle['license_plate'] as String? ?? '',
      shares: ((json['shares'] as List?) ?? const [])
          .map((e) => VehicleShare.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingInvites: ((json['pending_invites'] as List?) ?? const [])
          .map((e) => ShareInvitation.fromJson(e as Map<String, dynamic>))
          .toList(),
      limits: ShareLimits.fromJson(
        (json['limits'] as Map<String, dynamic>?) ?? const {},
      ),
      shareCode: json['share_code'] as String?,
      qrCodeData: json['qr_code_data'] == null
          ? null
          : json['qr_code_data'] is String
          ? json['qr_code_data'] as String
          : _encode(json['qr_code_data']),
    );
  }
}

/// A vehicle shared *with* the current user (`GET /v1/vehicles/shared`).
class SharedVehicle {
  const SharedVehicle({
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
    required this.archived,
    required this.updatedAt,
    this.createdAt,
    required this.accessLevel,
    required this.ownerId,
    this.ownerDisplayName,
    this.ownerEmail,
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
  final bool archived;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final ShareAccessLevel accessLevel;
  final String ownerId;
  final String? ownerDisplayName;
  final String? ownerEmail;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return name;
  }

  /// Falls back to empty when the owner's name has not been synced yet —
  /// callers substitute the localized "Owner" label.
  String get ownerLabel => ownerDisplayName ?? ownerEmail ?? '';

  factory SharedVehicle.fromJson(Map<String, dynamic> json) {
    final owner = (json['owner'] as Map<String, dynamic>?) ?? const {};
    return SharedVehicle(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? owner['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nickname: json['nickname'] as String?,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      licensePlate: json['license_plate'] as String? ?? '',
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      fuelType: json['fuel_type'] as String? ?? 'petrol',
      mileage: (json['mileage'] as num?)?.toDouble() ?? 0,
      mileageUnit: json['mileage_unit'] as String? ?? 'mi',
      archived: json['archived'] as bool? ?? false,
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      createdAt: _parseDate(json['created_at']),
      accessLevel: ShareAccessLevel.parse(
        json['access_level'] as String? ?? 'view',
      ),
      ownerId: owner['id'] as String? ?? json['user_id'] as String? ?? '',
      ownerDisplayName: owner['display_name'] as String?,
      ownerEmail: owner['email'] as String?,
    );
  }
}

/// Preview shown before someone commits to joining with a code.
class SharePreview {
  const SharePreview({
    required this.vehicleNickname,
    required this.licensePlate,
    required this.accessLevel,
    required this.expiresAt,
    this.ownerDisplayName,
  });

  final String vehicleNickname;
  final String licensePlate;
  final String? ownerDisplayName;
  final ShareAccessLevel accessLevel;
  final DateTime expiresAt;

  factory SharePreview.fromJson(Map<String, dynamic> json) {
    return SharePreview(
      vehicleNickname: json['vehicle_nickname'] as String? ?? '',
      licensePlate: json['license_plate'] as String? ?? '',
      ownerDisplayName: json['owner_display_name'] as String?,
      accessLevel: ShareAccessLevel.parse(
        json['access_level'] as String? ?? 'view',
      ),
      expiresAt: _parseDate(json['expires_at']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _encode(dynamic value) {
  if (value is String) return value;
  return jsonEncode(value);
}
