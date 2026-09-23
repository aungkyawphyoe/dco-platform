import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/note.dart';
import '../../domain/note_failure.dart';
import '../../domain/note_validators.dart';
import '../../domain/repositories/notes_repository.dart';
import '../mappers/note_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

/// Local-only notes repository — no outbox, no sync (see production-scope.md).
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl({required AppDatabase db, Uuid uuid = const Uuid()})
      : _db = db,
        _uuid = uuid;

  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Stream<List<Note>> watchForUser(String userId) {
    final query = _db.select(_db.noteRecords)
      ..where((row) => row.userId.equals(userId))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map((rows) => rows.map(noteFromDrift).toList());
  }

  @override
  Future<Note?> getById(String id) async {
    final row =
        await (_db.select(_db.noteRecords)..where((r) => r.id.equals(id)))
            .getSingleOrNull();
    return row == null ? null : noteFromDrift(row);
  }

  @override
  Future<Note> add({
    required String userId,
    required NoteDraft draft,
  }) async {
    _assertDraft(draft);

    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      userId: userId,
      title: draft.title.trim(),
      body: draft.body,
      updatedAt: now,
      createdAt: now,
    );

    await _db.into(_db.noteRecords).insert(noteToCompanion(note));
    return note;
  }

  @override
  Future<Note> update({
    required String userId,
    required String noteId,
    required NoteDraft draft,
  }) async {
    _assertDraft(draft);
    final existing = await getById(noteId);
    if (existing == null || existing.userId != userId) {
      throw const NoteNotFoundFailure();
    }

    final updated = Note(
      id: existing.id,
      userId: existing.userId,
      title: draft.title.trim(),
      body: draft.body,
      updatedAt: DateTime.now().toUtc(),
      createdAt: existing.createdAt,
    );

    await (_db.update(_db.noteRecords)..where((row) => row.id.equals(noteId)))
        .write(noteToCompanion(updated));
    return updated;
  }

  @override
  Future<void> delete({
    required String userId,
    required String noteId,
  }) async {
    final existing = await getById(noteId);
    if (existing == null || existing.userId != userId) {
      throw const NoteNotFoundFailure();
    }
    await (_db.delete(_db.noteRecords)..where((row) => row.id.equals(noteId)))
        .go();
  }

  @override
  Future<void> restore(Note note) async {
    final existing = await getById(note.id);
    if (existing != null) return;
    await _db.into(_db.noteRecords).insert(
          noteToCompanion(note),
          mode: InsertMode.insertOrReplace,
        );
  }

  void _assertDraft(NoteDraft draft) {
    final error = NoteValidators.draft(
      title: draft.title,
      body: draft.body,
    );
    if (error != null) throw NoteValidationFailure(error);
  }
}
