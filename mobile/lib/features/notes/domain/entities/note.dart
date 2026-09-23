class Note {
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get isUntitled => title.trim().isEmpty;

  String get displayTitle => isUntitled ? '' : title.trim();
}

class NoteDraft {
  const NoteDraft({required this.title, required this.body});

  final String title;
  final String body;
}
