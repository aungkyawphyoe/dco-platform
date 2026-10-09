import '../../generated/app_localizations.dart';
import 'feature_gate.dart';

/// Block copy for create entry points (`architecture/feature-gating.md`
/// §8.3) — mirrors the backend `LIMIT_EXCEEDED` message shape from
/// `docs/pricing.md`.
extension GateMessages on FeatureGateSnapshot {
  String vehicleBlockMessage(AppLocalizations s) {
    final limit = claims.vehicleLimit ?? 1;
    final head = s.planLimitVehicle('$limit', planName);
    final next = nextVehiclePlan;
    if (next == null) return head;
    return '$head ${s.planLimitUpgradeTo('${next.limit}', next.name)}';
  }

  String shareBlockMessage(AppLocalizations s) {
    final limit = claims.sharingLimit;
    if (limit == null) return s.planLimitChecking;
    return s.sharePlanLimitReached(limit);
  }
}
