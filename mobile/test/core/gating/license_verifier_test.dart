import 'dart:convert';

import 'package:dco_mobile/core/gating/license_models.dart';
import 'package:dco_mobile/core/gating/license_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_license.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 1, 12);

  LicenseVerifier withKeyring(List<LicenseKeyringEntry> entries) =>
      LicenseVerifier(keyring: entries, trustedNow: () async => fixedNow);

  LicenseKeyringEntry entryFor(MintedLicense license, {String kid = 'test-key'}) =>
      LicenseKeyringEntry(kid: kid, alg: 'EdDSA', x: license.x);

  test('valid signature and clock window returns claims', () async {
    final minted = await mintLicense(
      planId: 'lite',
      vehicleLimit: 3,
      sharingLimit: 3,
      issuedAt: fixedNow.subtract(const Duration(hours: 1)),
      expiresAt: fixedNow.add(const Duration(days: 30)),
    );
    final v = withKeyring([entryFor(minted)]);

    final claims = await v.verify(minted.jwt);
    expect(claims, isNotNull);
    expect(claims!.planId, 'lite');
    expect(claims.vehicleLimit, 3);
    expect(claims.sharingLimit, 3);
  });

  test('unknown but well-formed plan_id is trusted (decision 6)', () async {
    final minted = await mintLicense(
      planId: 'quantum',
      vehicleLimit: null,
      sharingLimit: null,
      issuedAt: fixedNow.subtract(const Duration(hours: 1)),
    );
    final claims = await withKeyring([entryFor(minted)]).verify(minted.jwt);
    expect(claims, isNotNull);
    expect(claims!.planId, 'quantum');
    expect(claims.vehicleLimit, isNull); // unlimited
  });

  test('tampered signature is rejected', () async {
    final minted = await mintLicense();
    final parts = minted.jwt.split('.');
    final sig = parts[2];
    final flipped = (sig[0] == 'A' ? 'B' : 'A') + sig.substring(1);
    final tampered = '${parts[0]}.${parts[1]}.$flipped';
    expect(await withKeyring([entryFor(minted)]).verify(tampered), isNull);
  });

  test('tampered payload without re-signing is rejected', () async {
    final minted = await mintLicense(planId: 'free', vehicleLimit: 1);
    final parts = minted.jwt.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    payload['plan_id'] = 'fleet';
    payload['vehicle_limit'] = null;
    final forged =
        '${parts[0]}.${b64u(utf8.encode(jsonEncode(payload)))}.${parts[2]}';
    expect(await withKeyring([entryFor(minted)]).verify(forged), isNull);
  });

  test('unknown kid is rejected', () async {
    final minted = await mintLicense(kid: 'rotated-away');
    expect(await withKeyring([entryFor(minted)]).verify(minted.jwt), isNull);
    expect(
      await withKeyring([entryFor(minted, kid: 'current-key')]).verify(
        minted.jwt,
      ),
      isNull,
    );
  });

  test('non-EdDSA alg header is rejected even with a matching kid', () async {
    final minted = await mintLicense(alg: 'HS256');
    expect(await withKeyring([entryFor(minted)]).verify(minted.jwt), isNull);
  });

  test('empty keyring never trusts anything', () async {
    final minted = await mintLicense();
    expect(await withKeyring(const []).verify(minted.jwt), isNull);
  });

  test('expired license is rejected', () async {
    final minted = await mintLicense(
      issuedAt: fixedNow.subtract(const Duration(days: 10)),
      expiresAt: fixedNow.subtract(const Duration(days: 1)),
    );
    expect(await withKeyring([entryFor(minted)]).verify(minted.jwt), isNull);
  });

  test('iat in the future beyond tolerance is rejected (rollback)', () async {
    final minted = await mintLicense(
      issuedAt: fixedNow.add(const Duration(hours: 1)),
      expiresAt: fixedNow.add(const Duration(days: 30)),
    );
    expect(await withKeyring([entryFor(minted)]).verify(minted.jwt), isNull);
  });

  test('iat within future tolerance passes (NTP jitter)', () async {
    final minted = await mintLicense(
      issuedAt: fixedNow.add(const Duration(minutes: 2)),
      expiresAt: fixedNow.add(const Duration(days: 30)),
    );
    expect(await withKeyring([entryFor(minted)]).verify(minted.jwt), isNotNull);
  });

  test('malformed tokens are rejected without throwing', () async {
    final v = withKeyring(const []);
    expect(await v.verify(''), isNull);
    expect(await v.verify('a.b'), isNull);
    expect(await v.verify('!!.!!.!!'), isNull);
  });
}
