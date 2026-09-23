import '../entities/note.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchForUser(String userId);

  Future<Note?> getById(String id);

  Future<Note> add({required String userId, required NoteDraft draft});

  Future<Note> update({
    required String userId,
    required String noteId,
    required NoteDraft draft,
  });

  Future<void> delete({required String userId, required String noteId});

  Future<void> restore(Note note);
}
