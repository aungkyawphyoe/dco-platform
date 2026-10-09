import 'package:flutter/foundation.dart';

/// Self-contained entitlement claims parsed from the verified offline
/// license JWT (`architecture/feature-gating.md` §5). Every limit ships
/// inside the token, so an unknown-but-valid `plan_id` is trusted and
/// price changes need no app release (decisions 6, 10).
@immutable
class EntitlementClaims {
  const EntitlementClaims({
    required this.planId,
    required this.vehicleLimit,
    required this.sharingLimit,
    required this.storageBytes,
    required this.aiTier,
    required this.features,
    required this.periodEnd,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// Free fallback whenever the license is missing, invalid, or expired —
  /// degrade to Free, never a lockout (decision 11).
  static final EntitlementClaims free = EntitlementClaims(
    planId: 'free',
    vehicleLimit: 1,
    sharingLimit: 1,
    storageBytes: 50 * 1024 * 1024,
    aiTier: 'base',
    features: const {},
    periodEnd: null,
    issuedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    expiresAt: DateTime.utc(2100),
  );

  factory EntitlementClaims.fromPayload(Map<String, dynamic> payload) {
    final rawFeatures = payload['features'];
    final features = <String, bool>{};
    if (rawFeatures is Map) {
      rawFeatures.forEach((key, value) => features['$key'] = value == true);
    }
    final periodEnd = payload['period_end'];
    return EntitlementClaims(
      planId: payload['plan_id'] as String? ?? 'free',
      vehicleLimit: (payload['vehicle_limit'] as num?)?.toInt(),
      sharingLimit: (payload['sharing_limit'] as num?)?.toInt(),
      storageBytes: (payload['storage_bytes'] as num?)?.toInt() ?? 0,
      aiTier: payload['ai_tier'] as String? ?? 'base',
      features: features,
      periodEnd: periodEnd is String
          ? DateTime.tryParse(periodEnd)?.toUtc()
          : null,
      issuedAt: _epoch(payload['iat']),
      expiresAt: _epoch(payload['exp']),
    );
  }

  static DateTime _epoch(Object? value) {
    final seconds = (value as num?)?.toInt() ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// `free` | `lite` | `standard` | `fleet`.
  final String planId;

  /// `null` = unlimited; used for all local create checks.
  final int? vehicleLimit;
  final int? sharingLimit;
  final int storageBytes;
  final String aiTier;
  final Map<String, bool> features;

  /// Billing period end — display only; null until billing lands
  /// (pre-billing issuance, §5.1).
  final DateTime? periodEnd;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool feature(String key) => features[key] ?? false;
}

/// One `kid` → Ed25519 public key mapping from the bundled keyring
/// (`assets/license_keys.json`).
@immutable
class LicenseKeyringEntry {
  const LicenseKeyringEntry({
    required this.kid,
    required this.alg,
    required this.x,
  });

  factory LicenseKeyringEntry.fromJson(Map<String, dynamic> json) {
    return LicenseKeyringEntry(
      kid: json['kid'] as String,
      alg: json['alg'] as String? ?? 'EdDSA',
      x: json['x'] as String,
    );
  }

  final String kid;
  final String alg;

  /// Base64url raw 32-byte Ed25519 public key.
  final String x;
}
