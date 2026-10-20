import 'dart:convert';
import 'package:drift/drift.dart';
import 'app_database.dart';

/// A deleted log detaches its documents, including queued offline writes.
/// The file records and bytes remain available in Documents.
Future<void> detachDocumentLinks(
  AppDatabase db,
  String kind,
  String recordId,
) async {
  bool matches(dynamic link) =>
      link is Map && link['kind'] == kind && link['record_id'] == recordId;
  for (final doc in await db.select(db.documentRecords).get()) {
    final links = jsonDecode(doc.linksJson) as List;
    if (!links.any(matches)) continue;
    await (db.update(
      db.documentRecords,
    )..where((r) => r.id.equals(doc.id))).write(
      DocumentRecordsCompanion(
        linksJson: Value(
          jsonEncode(links.where((link) => !matches(link)).toList()),
        ),
      ),
    );
  }
  final pending = await (db.select(
    db.outboxEntries,
  )..where((r) => r.entityType.equals('document'))).get();
  for (final op in pending) {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    final links = payload['links'];
    if (links is! List || !links.any(matches)) continue;
    payload['links'] = links.where((link) => !matches(link)).toList();
    await (db.update(db.outboxEntries)..where((r) => r.id.equals(op.id))).write(
      OutboxEntriesCompanion(payload: Value(jsonEncode(payload))),
    );
  }
}


Future<void> detachLegacyDocumentMedia(AppDatabase db, String mediaId) async {
  await (db.update(db.serviceRecordRows)..where((r) => r.receiptMediaId.equals(mediaId))).write(
    const ServiceRecordRowsCompanion(receiptMediaId: Value(null), receiptLocalPath: Value(null)),
  );
  await (db.update(db.expenseRecords)..where((r) => r.receiptMediaId.equals(mediaId))).write(
    const ExpenseRecordsCompanion(receiptMediaId: Value(null), receiptLocalPath: Value(null)),
  );
  for (final op in await db.select(db.outboxEntries).get()) {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    if (payload['receipt_media_id'] != mediaId) continue;
    payload['receipt_media_id'] = null;
    await (db.update(db.outboxEntries)..where((r) => r.id.equals(op.id))).write(OutboxEntriesCompanion(payload: Value(jsonEncode(payload))));
  }
}
