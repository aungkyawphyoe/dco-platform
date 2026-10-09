import 'dart:convert';

import 'license_store.dart';

/// Injectable wall clock so tests can fake time.
typedef NowFn = DateTime Function();

/// Trusted time for license evaluation (`architecture/feature-gating.md`
/// §6). Persists `max_seen` in secure storage next to the license: a
/// rolled-back device clock freezes effective time at the last trusted
/// value instead of resurrecting an expired license.
class TrustedClock {
  TrustedClock({
    required this.store,
    required this.userId,
    NowFn? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  /// Absorbs NTP corrections and timezone jitter (§6.1).
  static const rollbackTolerance = Duration(minutes: 5);

  final LicenseStore store;
  final String userId;
  final NowFn _now;

  /// Effective now: frozen at `max_seen` when the device clock rolled
  /// back beyond tolerance, otherwise trusted and advanced (§6.1).
  Future<DateTime> now() async {
    final device = _now();
    final seen = await store.readMaxSeen(userId);
    if (seen == null) {
      await store.writeMaxSeen(userId, device);
      return device;
    }
    if (device.isBefore(seen.subtract(rollbackTolerance))) return seen;
    if (device.isAfter(seen)) await store.writeMaxSeen(userId, device);
    return device;
  }

  /// Advance `max_seen` from a server-attested time (license `iat` or
  /// access-JWT `iat` on refresh) — keeps the anchor honest even if the
  /// device clock was wrong (§6.3).
  Future<void> observe(DateTime serverTime) async {
    final seen = await store.readMaxSeen(userId);
    if (seen == null || serverTime.isAfter(seen)) {
      await store.writeMaxSeen(userId, serverTime);
    }
  }
}

/// Best-effort `iat` of an unverified JWT — used only to advance the
/// trusted clock with times the server attested to (tokens themselves
/// live in secure storage, out of reach of local DB editors).
DateTime? jwtIssuedAt(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return null;
    final iat = (payload['iat'] as num?)?.toInt();
    if (iat == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
