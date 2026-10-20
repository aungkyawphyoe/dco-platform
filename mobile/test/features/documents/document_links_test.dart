import 'dart:convert';
import 'dart:io';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/database/document_links.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/documents/data/repositories/document_repository_impl.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DocumentRepositoryImpl repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DocumentRepositoryImpl(db: db, outbox: OutboxWriter(db));
  });
  tearDown(() => db.close());

  test(
    'one offline file can link to multiple logs and unlink without deleting bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp('document-links');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/invoice.pdf')
        ..writeAsStringSync('%PDF-1.7');
      const first = DocumentLink(kind: 'service_record', recordId: 'service1');
      const second = DocumentLink(kind: 'fuel_log', recordId: 'fuel1');
      final doc = await repo.add(
        userId: 'owner',
        vehicleId: 'vehicle1',
        draft: DocumentDraft(
          name: 'Invoice',
          category: DocumentCategory.invoice,
          localFilePath: file.path,
          links: [first, second],
        ),
      );
      expect((await repo.getById(doc.id))!.links, hasLength(2));
      await repo.update(
        userId: 'owner',
        documentId: doc.id,
        draft: DocumentDraft(
          name: doc.name,
          category: doc.category,
          localFilePath: file.path,
          links: [second],
        ),
      );
      expect((await repo.getById(doc.id))!.links.single.recordId, 'fuel1');
      expect(await db.select(db.documentRecords).get(), hasLength(1));
      expect(file.existsSync(), isTrue);
      final queued = await db.select(db.outboxEntries).get();
      expect(jsonDecode(queued.last.payload)['links'], [
        {'kind': 'fuel_log', 'record_id': 'fuel1'},
      ]);
    },
  );

  test(
    'deleting a log detaches cached and queued references but preserves the document',
    () async {
      final doc = await repo.add(
        userId: 'owner',
        vehicleId: 'vehicle1',
        draft: const DocumentDraft(
          name: 'Invoice',
          category: DocumentCategory.invoice,
          links: [
            DocumentLink(kind: 'service_record', recordId: 'deleted'),
            DocumentLink(kind: 'fuel_log', recordId: 'retained'),
          ],
        ),
      );
      await db.transaction(
        () => detachDocumentLinks(db, 'service_record', 'deleted'),
      );
      expect((await repo.getById(doc.id))!.links.single.recordId, 'retained');
      for (final queued in await db.select(db.outboxEntries).get()) {
        expect(jsonDecode(queued.payload)['links'], [
          {'kind': 'fuel_log', 'record_id': 'retained'},
        ]);
      }
    },
  );

  test(
    'an aborted form transaction leaves no document or upload queued',
    () async {
      await expectLater(
        db.transaction(() async {
          await repo.add(
            userId: 'owner',
            vehicleId: 'vehicle1',
            draft: const DocumentDraft(
              name: 'Invoice',
              category: DocumentCategory.invoice,
            ),
          );
          throw StateError('Log save failed');
        }),
        throwsStateError,
      );
      expect(await db.select(db.documentRecords).get(), isEmpty);
      expect(await db.select(db.outboxEntries).get(), isEmpty);
    },
  );
}
