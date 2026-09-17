import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/entities/document.dart';
import '../../domain/document_failure.dart';
import '../../domain/repositories/document_repository.dart';
import '../mappers/document_mapper.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
    SyncEngine? syncEngine,
    Uuid uuid = const Uuid(),
  })  : _db = db,
        _outbox = outbox,
        _sync = syncEngine,
        _uuid = uuid;

  final AppDatabase _db;
  final OutboxWriter _outbox;
  final SyncEngine? _sync;
  final Uuid _uuid;

  @override
  Stream<List<Document>> watchForVehicle(String vehicleId) {
    final query = _db.select(_db.documentRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(documentFromDrift).toList());
  }

  @override
  Future<Document?> getById(String id) async {
    final row = await (_db.select(_db.documentRecords)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return documentFromDrift(row);
  }

  @override
  Future<Document> add({
    required String userId,
    required String vehicleId,
    required DocumentDraft draft,
  }) async {
    _assertDraft(draft);
    final now = DateTime.now().toUtc();
    final doc = Document(
      id: _uuid.v4(),
      vehicleId: vehicleId,
      name: draft.name.trim(),
      category: draft.category,
      notes: _emptyToNull(draft.notes),
      localFilePath: draft.localFilePath,
      updatedAt: now,
      createdAt: now,
    );

    await _db.into(_db.documentRecords).insert(documentToCompanion(doc));
    await _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.document,
      entityId: doc.id,
      op: OutboxOp.upsert,
      payload: doc.toWriteJson(),
    );
    _sync?.requestSync();
    return doc;
  }

  @override
  Future<Document> update({
    required String userId,
    required String documentId,
    required DocumentDraft draft,
  }) async {
    _assertDraft(draft);
    final existing = await getById(documentId);
    if (existing == null) throw const DocumentNotFoundFailure();

    final updated = existing.copyWith(
      name: draft.name.trim(),
      category: draft.category,
      notes: _emptyToNull(draft.notes),
      localFilePath: draft.localFilePath,
      updatedAt: DateTime.now().toUtc(),
    );

    await (_db.update(_db.documentRecords)
          ..where((row) => row.id.equals(documentId)))
        .write(documentToCompanion(updated));
    await _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.document,
      entityId: documentId,
      op: OutboxOp.upsert,
      payload: updated.toWriteJson(),
    );

    if (existing.localFilePath != null && existing.localFilePath != updated.localFilePath) {
      await _deleteLocalFile(existing.localFilePath);
    }

    _sync?.requestSync();
    return updated;
  }

  @override
  Future<void> delete({
    required String userId,
    required String documentId,
  }) async {
    final existing = await getById(documentId);
    if (existing == null) throw const DocumentNotFoundFailure();

    await (_db.delete(_db.documentRecords)
          ..where((row) => row.id.equals(documentId)))
        .go();
    await _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.document,
      entityId: documentId,
      op: OutboxOp.delete,
      payload: {'id': documentId},
    );

    await _deleteLocalFile(existing.localFilePath);
    _sync?.requestSync();
  }

  void _assertDraft(DocumentDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw const DocumentValidationFailure('Name is required');
    }
    if (draft.name.trim().length > 120) {
      throw const DocumentValidationFailure('Name must be 120 characters or less');
    }
  }

  Future<void> _deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Local cleanup is best-effort.
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
