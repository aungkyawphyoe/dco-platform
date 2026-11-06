import 'dart:io';

/// Owns only newly generated files until the local record is saved.
class DraftAttachmentFiles {
  final _paths = <String>{};
  bool _disposed = false;
  bool _saving = false;

  Future<void> add(String path) async {
    _paths.add(path);
    if (_disposed && !_saving) await discard(path);
  }

  Future<void> discard(String? path) async {
    if (path == null || !_paths.remove(path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already removed, or unavailable during app shutdown.
    }
  }

  void retain(String? path) => _paths.remove(path);
  void beginSave() => _saving = true;
  Future<void> endSave() async {
    _saving = false;
    if (_disposed) await dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    if (!_saving) {
      for (final path in _paths.toList()) {
        await discard(path);
      }
    }
  }
}
