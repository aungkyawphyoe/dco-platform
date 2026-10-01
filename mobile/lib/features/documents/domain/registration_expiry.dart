import 'entities/document.dart';

enum RegistrationExpiryStatus { none, valid, dueSoon, expired }

class RegistrationExpiry {
  const RegistrationExpiry({required this.status, this.expiresOn, this.document});

  final RegistrationExpiryStatus status;
  final DateTime? expiresOn;
  final Document? document;

  int daysUntil(DateTime today) {
    if (expiresOn == null) return 0;
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(expiresOn!.year, expiresOn!.month, expiresOn!.day);
    return b.difference(a).inDays;
  }
}

/// Summarises the vehicle's registration document expiry for the
/// vehicle detail Overview tile.
abstract final class RegistrationExpiryFinder {
  /// Days before the registration expiry that it counts as "due soon".
  static const soonDays = 30;

  /// Picks the latest `expires_on` among registration documents, so a fresh
  /// renewal wins over an older expired one.
  static RegistrationExpiry summarize(
    Iterable<Document> documents, {
    DateTime? today,
  }) {
    Document? latestDoc;
    DateTime? latest;
    for (final doc in documents) {
      if (doc.category != DocumentCategory.registration) continue;
      final expiresOn = doc.expiresOn;
      if (expiresOn == null) continue;
      if (latest == null || expiresOn.isAfter(latest)) {
        latest = expiresOn;
        latestDoc = doc;
      }
    }
    if (latest == null) {
      return const RegistrationExpiry(status: RegistrationExpiryStatus.none);
    }
    final now = today ?? DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(latest.year, latest.month, latest.day);
    final days = b.difference(a).inDays;
    final status = days < 0
        ? RegistrationExpiryStatus.expired
        : days <= soonDays
            ? RegistrationExpiryStatus.dueSoon
            : RegistrationExpiryStatus.valid;
    return RegistrationExpiry(
      status: status,
      expiresOn: latest,
      document: latestDoc,
    );
  }
}
