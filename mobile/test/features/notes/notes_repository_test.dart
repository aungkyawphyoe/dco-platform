import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:dco_mobile/features/notes/domain/entities/note.dart';
import 'package:dco_mobile/features/notes/domain/note_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotesRepositoryImpl notes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = NotesRepositoryImpl(db: db);
  });

  tearDown(() => db.close());

  test('add writes a local note and does not queue outbox', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Oil change due', body: 'Next week'),
    );

    final list = await notes.watchForUser('user-1').first;
    expect(list, hasLength(1));
    expect(list.single.id, note.id);
    expect(list.single.title, 'Oil change due');
    expect(list.single.userId, 'user-1');

    final queued = await db.select(db.outboxEntries).get();
    expect(queued, isEmpty);
  });

  test('notes are scoped by user', () async {
    await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Mine', body: ''),
    );
    await notes.add(
      userId: 'user-2',
      draft: const NoteDraft(title: 'Theirs', body: ''),
    );

    final mine = await notes.watchForUser('user-1').first;
    final theirs = await notes.watchForUser('user-2').first;
    expect(mine, hasLength(1));
    expect(mine.single.title, 'Mine');
    expect(theirs, hasLength(1));
    expect(theirs.single.title, 'Theirs');
  });

  test('sorted by updatedAt descending', () async {
    final first = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Older', body: ''),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Newer', body: ''),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await notes.update(
      userId: 'user-1',
      noteId: first.id,
      draft: const NoteDraft(title: 'Older touched', body: ''),
    );

    final list = await notes.watchForUser('user-1').first;
    expect(list.first.id, first.id);
    expect(list.last.id, second.id);
  });

  test('empty draft is rejected', () async {
    expect(
      () => notes.add(
        userId: 'user-1',
        draft: const NoteDraft(title: '  ', body: ''),
      ),
      throwsA(isA<NoteValidationFailure>()),
    );
  });

  test('title over 500 characters is rejected', () async {
    expect(
      () => notes.add(
        userId: 'user-1',
        draft: NoteDraft(title: 'a' * 501, body: ''),
      ),
      throwsA(isA<NoteValidationFailure>()),
    );
  });

  test('update changes fields and keeps identity', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Draft', body: 'v1'),
    );
    final stored = await notes.getById(note.id);
    final updated = await notes.update(
      userId: 'user-1',
      noteId: note.id,
      draft: const NoteDraft(title: 'Final', body: 'v2'),
    );

    expect(updated.id, note.id);
    expect(updated.createdAt, stored!.createdAt);
    expect(updated.title, 'Final');
    expect(updated.body, 'v2');

    final reloaded = await notes.getById(note.id);
    expect(reloaded!.title, 'Final');
    expect(reloaded.body, 'v2');
    expect(reloaded.createdAt, stored.createdAt);
  });

  test('update by another user is rejected', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Mine', body: ''),
    );
    expect(
      () => notes.update(
        userId: 'user-2',
        noteId: note.id,
        draft: const NoteDraft(title: 'Hacked', body: ''),
      ),
      throwsA(isA<NoteNotFoundFailure>()),
    );
  });

  test('delete removes the row; restore re-inserts it', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Temp', body: 'body'),
    );
    await notes.delete(userId: 'user-1', noteId: note.id);
    expect(await notes.getById(note.id), isNull);

    await notes.restore(note);
    final restored = await notes.getById(note.id);
    expect(restored, isNotNull);
    expect(restored!.title, 'Temp');
    expect(restored.body, 'body');
  });

  test('delete by another user is rejected', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: 'Mine', body: ''),
    );
    expect(
      () => notes.delete(userId: 'user-2', noteId: note.id),
      throwsA(isA<NoteNotFoundFailure>()),
    );
  });

  test('untitled note saves empty title', () async {
    final note = await notes.add(
      userId: 'user-1',
      draft: const NoteDraft(title: '', body: 'just body'),
    );
    expect(note.isUntitled, isTrue);
    expect(note.title, '');
  });
}
