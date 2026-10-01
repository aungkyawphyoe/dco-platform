import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/domain/registration_expiry.dart';
import 'package:flutter_test/flutter_test.dart';

Document _doc({
  String id = 'd1',
  DocumentCategory category = DocumentCategory.registration,
  DateTime? expiresOn,
}) {
  final now = DateTime(2026, 1, 1);
  return Document(
    id: id,
    vehicleId: 'v1',
    name: 'Registration',
    category: category,
    expiresOn: expiresOn,
    updatedAt: now,
    createdAt: now,
  );
}

void main() {
  group('RegistrationExpiryFinder', () {
    final today = DateTime(2026, 3, 1);

    test('no registration documents is none', () {
      final result = RegistrationExpiryFinder.summarize(const [], today: today);
      expect(result.status, RegistrationExpiryStatus.none);
      expect(result.expiresOn, isNull);
    });

    test('registration without expiry is none', () {
      final result = RegistrationExpiryFinder.summarize(
        [_doc()],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.none);
    });

    test('other categories are ignored', () {
      final result = RegistrationExpiryFinder.summarize(
        [_doc(category: DocumentCategory.insurance, expiresOn: DateTime(2026, 4, 1))],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.none);
    });

    test('far-future expiry is valid', () {
      final result = RegistrationExpiryFinder.summarize(
        [_doc(expiresOn: DateTime(2026, 12, 1))],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.valid);
    });

    test('expiry within 30 days is dueSoon', () {
      final result = RegistrationExpiryFinder.summarize(
        [_doc(expiresOn: DateTime(2026, 3, 20))],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.dueSoon);
      expect(result.daysUntil(today), 19);
    });

    test('past expiry is expired', () {
      final result = RegistrationExpiryFinder.summarize(
        [_doc(expiresOn: DateTime(2026, 2, 1))],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.expired);
    });

    test('latest expiry wins over an older expired one', () {
      final result = RegistrationExpiryFinder.summarize(
        [
          _doc(id: 'old', expiresOn: DateTime(2025, 1, 1)),
          _doc(id: 'new', expiresOn: DateTime(2027, 1, 1)),
        ],
        today: today,
      );
      expect(result.status, RegistrationExpiryStatus.valid);
      expect(result.expiresOn, DateTime(2027, 1, 1));
    });
  });
}
