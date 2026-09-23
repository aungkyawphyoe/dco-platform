import 'package:dco_mobile/features/notes/domain/note_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteValidators.title', () {
    test('allows empty title (untitled note)', () {
      expect(NoteValidators.title(''), isNull);
      expect(NoteValidators.title('   '), isNull);
    });

    test('allows title up to 500 characters', () {
      expect(NoteValidators.title('a' * 500), isNull);
    });

    test('rejects title over 500 characters', () {
      expect(NoteValidators.title('a' * 501), isNotNull);
    });
  });

  group('NoteValidators.draft', () {
    test('rejects when both title and body are blank', () {
      expect(NoteValidators.draft(title: '', body: ''), isNotNull);
      expect(NoteValidators.draft(title: '   ', body: '  \n '), isNotNull);
    });

    test('allows body-only note', () {
      expect(NoteValidators.draft(title: '', body: 'hello'), isNull);
    });

    test('allows title-only note', () {
      expect(NoteValidators.draft(title: 'shopping', body: ''), isNull);
    });

    test('rejects title over max length even with body', () {
      expect(
        NoteValidators.draft(title: 'a' * 501, body: 'x'),
        isNotNull,
      );
    });
  });
}
