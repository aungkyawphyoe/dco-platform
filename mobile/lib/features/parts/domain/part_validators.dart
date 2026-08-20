abstract final class PartValidators {
  static const maxNameLength = 80;
  static const maxBrandLength = 40;
  static const maxPartNumberLength = 40;
  static const maxNotesLength = 500;

  static String? name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length > maxNameLength) return 'Name must be $maxNameLength characters or fewer';
    return null;
  }

  static String? brand(String value) {
    final trimmed = value.trim();
    if (trimmed.length > maxBrandLength) return 'Brand must be $maxBrandLength characters or fewer';
    return null;
  }

  static String? partNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.length > maxPartNumberLength) {
      return 'Part number must be $maxPartNumberLength characters or fewer';
    }
    return null;
  }

  static String? notes(String value) {
    final trimmed = value.trim();
    if (trimmed.length > maxNotesLength) return 'Notes must be $maxNotesLength characters or fewer';
    return null;
  }
}
