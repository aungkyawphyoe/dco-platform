import 'package:dco_mobile/core/router/deep_links.dart';
import 'package:dco_mobile/features/vehicle_sharing/domain/share_invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareInviteLink.tryParse', () {
    test('parses the QR payload used by the share panel', () {
      final link = ShareInviteLink.tryParse(
        'dco://vehicle/share/join?code=abcd1234',
      );

      expect(link?.code, 'ABCD1234');
      expect(
        link?.toUri().toString(),
        'dco://vehicle/share/join?code=ABCD1234',
      );
    });

    test('accepts a bare code, trimmed and upper-cased', () {
      expect(ShareInviteLink.tryParse('  abcd1234  ')?.code, 'ABCD1234');
    });

    test('ignores unrelated query parameters', () {
      final link = ShareInviteLink.tryParse(
        'dco://vehicle/share/join?code=ABCD1234&vehicle_id=v1&expires=1',
      );

      expect(link?.code, 'ABCD1234');
    });

    test('builds the join route location', () {
      expect(
        ShareInviteLink.tryParse('ABCD1234')?.routeLocation,
        '/vehicle/share/join?code=ABCD1234',
      );
    });

    test('rejects payloads that are not share links or codes', () {
      expect(ShareInviteLink.tryParse(''), isNull);
      expect(ShareInviteLink.tryParse('   '), isNull);
      expect(ShareInviteLink.tryParse('ABCD123'), isNull);
      expect(ShareInviteLink.tryParse('ABCD12345'), isNull);
      expect(ShareInviteLink.tryParse('dco://vehicle/share/join'), isNull);
      expect(
        ShareInviteLink.tryParse('dco://vehicle/share/join?code=SHORT'),
        isNull,
      );
      expect(
        ShareInviteLink.tryParse('dco://vehicle/share/accept?token=abc'),
        isNull,
      );
      expect(
        ShareInviteLink.tryParse('dco://garage/share/join?code=ABCD1234'),
        isNull,
      );
      expect(
        ShareInviteLink.tryParse(
          'https://example.com/share/join?code=ABCD1234',
        ),
        isNull,
      );
    });
  });

  group('deepLinkLocation', () {
    test('maps a scanned share link to the join route', () {
      expect(
        deepLinkLocation(Uri.parse('dco://vehicle/share/join?code=abcd1234')),
        '/vehicle/share/join?code=ABCD1234',
      );
    });

    test('leaves in-app locations untouched', () {
      expect(
        deepLinkLocation(Uri.parse('/vehicle/share/join?code=ABCD1234')),
        isNull,
      );
      expect(deepLinkLocation(Uri.parse('/dashboard')), isNull);
    });

    test('maps an emailed accept link', () {
      expect(
        deepLinkLocation(Uri.parse('dco://vehicle/share/accept?token=abc123')),
        '/vehicle/share/accept?token=abc123',
      );
    });

    test('opens the join screen when the code is missing', () {
      expect(
        deepLinkLocation(Uri.parse('dco://vehicle/share/join')),
        '/vehicle/share/join',
      );
    });

    test('falls back to the garage for unknown app links', () {
      expect(
        deepLinkLocation(Uri.parse('dco://vehicle/unknown')),
        '/dashboard',
      );
      expect(
        deepLinkLocation(Uri.parse('dco://vehicle/share/accept')),
        '/dashboard',
      );
    });

    test('ignores links the app does not handle', () {
      expect(
        deepLinkLocation(
          Uri.parse('https://example.com/share/join?code=ABCD1234'),
        ),
        isNull,
      );
    });
  });
}
