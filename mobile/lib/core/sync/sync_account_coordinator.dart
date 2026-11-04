import 'sync_engine.dart';

/// Account changes coordinate engines without depending on a session-scoped
/// provider. Newly constructed engines remain paused until the change ends.
class SyncAccountCoordinator {
  final _engines = <SyncEngine>{};
  bool _paused = false;

  void register(SyncEngine engine) {
    _engines.add(engine);
    if (_paused) engine.pauseForAccountChange();
  }

  void unregister(SyncEngine engine) => _engines.remove(engine);

  Future<void> pause() async {
    _paused = true;
    await Future.wait(_engines.toList().map((e) => e.pauseForAccountChange()));
  }

  Future<void> flush() async {
    for (final engine in _engines.toList()) {
      await engine.flushForAccountChange();
    }
  }

  void resume({bool sync = true}) {
    _paused = false;
    for (final engine in _engines.toList()) {
      engine.resumeAfterAccountChange(sync: sync);
    }
  }
}
