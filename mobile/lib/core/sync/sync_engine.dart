/// Placeholder for push-then-pull. Outbox rows are already queued on write.
/// Network drain lands when the API exists.
class SyncEngine {
  const SyncEngine();

  Future<void> requestSync() async {}
}
