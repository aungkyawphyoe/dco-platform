import 'dart:convert';

import 'package:dco_mobile/core/gating/license_store.dart';
import 'package:dco_mobile/core/gating/trusted_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryLicenseStore store;
  late DateTime deviceNow;

  setUp(() {
    store = MemoryLicenseStore();
    deviceNow = DateTime.utc(2026, 6, 1, 12);
  });

  TrustedClock clock() => TrustedClock(store: store, userId: 'u1', now: () => deviceNow);

  test('first read anchors max_seen to the device time', () async {
    final seen = await clock().now();
    expect(seen, deviceNow);
    expect(await store.readMaxSeen('u1'), deviceNow);
  });

  test('device moving forward advances max_seen', () async {
    await clock().now();
    deviceNow = deviceNow.add(const Duration(hours: 1));
    expect(await clock().now(), deviceNow);
    expect(await store.readMaxSeen('u1'), deviceNow);
  });

  test('rollback within tolerance is trusted as normal time', () async {
    await clock().now();
    deviceNow = deviceNow.subtract(const Duration(minutes: 3));
    expect(await clock().now(), deviceNow);
    // max_seen must not regress below the anchor.
    expect(await store.readMaxSeen('u1'), deviceNow.add(const Duration(minutes: 3)));
  });

  test('rollback beyond tolerance freezes time at max_seen', () async {
    final anchor = await clock().now();
    deviceNow = deviceNow.subtract(const Duration(minutes: 10));
    expect(await clock().now(), anchor);
    expect(await store.readMaxSeen('u1'), anchor);
  });

  test('observe advances max_seen only forward', () async {
    await clock().now();
    final later = deviceNow.add(const Duration(minutes: 30));
    await clock().observe(later);
    expect(await store.readMaxSeen('u1'), later);

    final earlier = deviceNow.subtract(const Duration(minutes: 30));
    await clock().observe(earlier);
    expect(await store.readMaxSeen('u1'), later);
  });

  test('observe from empty store anchors the server time', () async {
    final serverTime = DateTime.utc(2026, 5, 1);
    await clock().observe(serverTime);
    expect(await store.readMaxSeen('u1'), serverTime);
  });

  group('jwtIssuedAt', () {
    test('parses the payload iat', () {
      final jwt = 'a.${b64uJson({'iat': 1767225600})}.c';
      expect(
        jwtIssuedAt(jwt),
        DateTime.fromMillisecondsSinceEpoch(1767225600 * 1000, isUtc: true),
      );
    });

    test('returns null for garbage or missing iat', () {
      expect(jwtIssuedAt('not-a-jwt'), isNull);
      expect(jwtIssuedAt('a.${b64uJson({'sub': 'x'})}.c'), isNull);
      expect(jwtIssuedAt('a.!!not-base64!!.c'), isNull);
    });
  });
}

String b64uJson(Map<String, Object?> json) {
  final encoded = base64Url.encode(
    const Utf8Encoder().convert(jsonEncode(json)),
  );
  return encoded.replaceAll('=', '');
}
