import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// A license JWT signed by a fresh Ed25519 keypair plus the matching
/// keyring entry (`x` = base64url raw public key) — lets tests exercise
/// the real verification path without committed keys.
class MintedLicense {
  const MintedLicense({required this.jwt, required this.x});

  final String jwt;
  final String x;
}

String b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Future<MintedLicense> mintLicense({
  String kid = 'test-key',
  String alg = 'EdDSA',
  String planId = 'free',
  int? vehicleLimit = 1,
  int? sharingLimit = 1,
  DateTime? issuedAt,
  DateTime? expiresAt,
  Map<String, Object?> extraPayload = const {},
}) async {
  final keyPair = await Ed25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final now = DateTime.now().toUtc();
  final header = {'alg': alg, 'kid': kid};
  final payload = <String, Object?>{
    'plan_id': planId,
    'vehicle_limit': vehicleLimit,
    'sharing_limit': sharingLimit,
    'storage_bytes': 50 * 1024 * 1024,
    'ai_tier': 'base',
    'features': <String, bool>{},
    'period_end': null,
    'iat': (issuedAt ?? now).millisecondsSinceEpoch ~/ 1000,
    'exp':
        (expiresAt ?? now.add(const Duration(days: 30))).millisecondsSinceEpoch ~/
        1000,
    ...extraPayload,
  };
  final signingInput =
      '${b64u(utf8.encode(jsonEncode(header)))}.${b64u(utf8.encode(jsonEncode(payload)))}';
  final signature = await Ed25519().sign(utf8.encode(signingInput), keyPair: keyPair);
  return MintedLicense(
    jwt: '$signingInput.${b64u(signature.bytes)}',
    x: b64u(publicKey.bytes),
  );
}
