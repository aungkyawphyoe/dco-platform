import 'package:flutter/foundation.dart';

import 'license_models.dart';

/// Synchronous gating snapshot — license claims (in memory) folded with
/// live Drift counts (`architecture/feature-gating.md` §8.1). Screens
/// read it synchronously; `featureGateProvider` returns `null` while
/// hydrating, which means **deny by default**.
@immutable
class FeatureGateSnapshot {
  const FeatureGateSnapshot({
    required this.claims,
    required this.vehicleCount,
    required this.activeShareCount,
  });

  final EntitlementClaims claims;

  /// Active (non-archived) owned vehicles — mirrors `_countGarage`.
  final int vehicleCount;

  /// Owner's shares with server status `active` — mirrors the server's
  /// `checkShareLimits` counts (pending/revoked shares do not consume a
  /// slot server-side, so they must not here either).
  final int activeShareCount;

  /// Decision 16: active-only counts; archiving frees a slot.
  bool get canCreateVehicle =>
      claims.vehicleLimit == null || vehicleCount < claims.vehicleLimit!;

  bool get canCreateShare =>
      claims.sharingLimit == null || activeShareCount < claims.sharingLimit!;

  bool feature(String key) => claims.feature(key);

  int? get vehicleLimit => claims.vehicleLimit;

  int? get sharingLimit => claims.sharingLimit;

  String get planId => claims.planId;

  String get planName => _planNames[planId] ?? planId;

  /// Next tier with a higher vehicle cap, for upsell copy — Dart mirror
  /// of backend `vehicleLimitMessage` (`backend/src/lib/limits.ts`).
  ({String name, int limit})? get nextVehiclePlan {
    final limit = claims.vehicleLimit;
    if (limit == null) return null;
    const nextByPlan = <String, (String, int)>{
      'free': ('Lite', 3),
      'lite': ('Standard', 10),
    };
    final next = nextByPlan[planId];
    if (next == null) return null;
    return (name: next.$1, limit: next.$2);
  }

  static const _planNames = <String, String>{
    'free': 'Free',
    'lite': 'Lite',
    'standard': 'Standard',
    'fleet': 'Fleet',
  };
}
