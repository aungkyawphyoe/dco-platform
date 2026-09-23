sealed class NoteFailure implements Exception {
  const NoteFailure(this.message);
  final String message;
}

class NoteValidationFailure extends NoteFailure {
  const NoteValidationFailure(super.message);
}

class NoteNotFoundFailure extends NoteFailure {
  const NoteNotFoundFailure([super.message = 'Note not found']);
}
