import 'entities/service_record.dart';

/// Finds the most recent service record that concerns the tyres.
///
/// There is no structured tire field on [ServiceRecord], so the match is a
/// keyword scan over the record title, service line names and part names.
abstract final class TireServiceFinder {
  static const keywords = [
    'tire',
    'tyre',
    'wheel',
    'rotation',
    'alignment',
    'balanc',
  ];

  static ServiceRecord? latest(Iterable<ServiceRecord> records) {
    ServiceRecord? best;
    for (final record in records) {
      if (!_isTireRecord(record)) continue;
      if (best == null || record.servicedOn.isAfter(best.servicedOn)) {
        best = record;
      }
    }
    return best;
  }

  static bool _isTireRecord(ServiceRecord record) =>
      _matches(record.title) ||
      record.items.any((line) => _matches(line.name)) ||
      record.parts.any((part) => _matches(part.name));

  static bool _matches(String text) {
    final haystack = text.toLowerCase();
    return keywords.any(haystack.contains);
  }
}
