abstract final class NoteValidators {
  static const maxTitleLength = 500;

  static String? title(String value) {
    if (value.length > maxTitleLength) {
      return 'Title must be $maxTitleLength characters or fewer';
    }
    return null;
  }

  static String? draft({required String title, required String body}) {
    final titleError = NoteValidators.title(title);
    if (titleError != null) return titleError;
    if (title.trim().isEmpty && body.trim().isEmpty) {
      return 'Note cannot be empty';
    }
    return null;
  }
}
