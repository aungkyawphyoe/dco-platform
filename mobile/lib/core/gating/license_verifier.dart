import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'license_models.dart';

/// Verifies the offline license per `architecture/feature-gating.md` §5.2:
/// EdDSA signature against the bundled `kid` keyring **before** claims
/// are trusted, then clock checks against trusted time. Any failure (bad
/// signature, unknown `kid`/`alg`, malformed token, expired, future
/// `iat`) returns `null` — the caller evaluates as Free. Never throws,
/// never blocks app start (decisions 10, 11).
class LicenseVerifier {
  LicenseVerifier({required this.keyring, required this.trustedNow});

  static const futureTolerance = Duration(minutes: 5);

  final List<LicenseKeyringEntry> keyring;
  final Future<DateTime> Function() trustedNow;

  Future<EntitlementClaims?> verify(String jwt) async {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;

    Map<String, dynamic> header;
    Map<String, dynamic> payload;
    try {
      header = jsonDecode(_decodeText(parts[0])) as Map<String, dynamic>;
      payload = jsonDecode(_decodeText(parts[1])) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    if (header['alg'] != 'EdDSA') return null;
    final kid = header['kid'];
    if (kid is! String) return null;
    LicenseKeyringEntry? entry;
    for (final candidate in keyring) {
      if (candidate.kid == kid && candidate.alg == 'EdDSA') {
        entry = candidate;
        break;
      }
    }
    if (entry == null) return null;

    try {
      final valid = await Ed25519().verify(
        utf8.encode('${parts[0]}.${parts[1]}'),
        signature: Signature(
          _decodeBytes(parts[2]),
          publicKey: SimplePublicKey(
            _decodeBytes(entry.x),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!valid) return null;
    } catch (_) {
      return null;
    }

    final now = await trustedNow();
    final issuedAt = _epoch(payload['iat']);
    final expiresAt = _epoch(payload['exp']);
    if (issuedAt == null || expiresAt == null) return null;
    if (now.isAfter(expiresAt)) return null;
    if (issuedAt.isAfter(now.add(futureTolerance))) return null;

    try {
      return EntitlementClaims.fromPayload(payload);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _epoch(Object? value) {
    final seconds = (value as num?)?.toInt();
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static String _decodeText(String part) =>
      utf8.decode(base64Url.decode(base64Url.normalize(part)));

  static List<int> _decodeBytes(String part) =>
      base64Url.decode(base64Url.normalize(part));
}
