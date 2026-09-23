import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/notes/domain/entities/note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userNotesProvider = StreamProvider<List<Note>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) return Stream.value(const []);
  return ref.watch(notesRepositoryProvider).watchForUser(userId);
});
