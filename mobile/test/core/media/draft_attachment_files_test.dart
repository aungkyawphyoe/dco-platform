import 'dart:io';
import 'package:dco_mobile/core/media/draft_attachment_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('draft-files');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<File> file(String name) =>
      File('${directory.path}/$name').writeAsString('bytes');

  test(
    'discard deletes only owned drafts, never existing saved files',
    () async {
      final drafts = DraftAttachmentFiles();
      final saved = await file('saved');
      final draft = await file('draft');
      await drafts.add(draft.path);
      await drafts.discard(saved.path);
      await drafts.discard(draft.path);
      expect(await saved.exists(), isTrue);
      expect(await draft.exists(), isFalse);
    },
  );
  test('dispose deletes abandoned drafts and late picker results', () async {
    final drafts = DraftAttachmentFiles();
    final first = await file('first');
    await drafts.add(first.path);
    await drafts.dispose();
    final late = await file('late');
    await drafts.add(late.path);
    expect(await first.exists(), isFalse);
    expect(await late.exists(), isFalse);
  });
  for (final saved in [true, false]) {
    test('dispose during save waits for persistence result: $saved', () async {
      final drafts = DraftAttachmentFiles();
      final draft = await file('draft');
      await drafts.add(draft.path);
      drafts.beginSave();
      await drafts.dispose();
      expect(await draft.exists(), isTrue);
      if (saved) drafts.retain(draft.path);
      await drafts.endSave();
      expect(await draft.exists(), saved);
    });
  }
}
