import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/note.dart';

Note noteFromDrift(NoteRecord row) {
  return Note(
    id: row.id,
    userId: row.userId,
    title: row.title,
    body: row.body,
    updatedAt: row.updatedAt,
    createdAt: row.createdAt,
  );
}

NoteRecordsCompanion noteToCompanion(Note note) {
  return NoteRecordsCompanion.insert(
    id: note.id,
    userId: note.userId,
    title: Value(note.title),
    body: Value(note.body),
    updatedAt: note.updatedAt,
    createdAt: note.createdAt,
  );
}
