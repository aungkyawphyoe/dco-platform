/// App navigation mode. Persisted per user; validated against live
/// entitlements on every read (server-side checks remain authoritative).
enum FleetMode {
  personal('personal'),
  fleet('fleet'),
  driver('driver');

  const FleetMode(this.storage);

  final String storage;

  static FleetMode fromStorage(String? raw) =>
      FleetMode.values.firstWhere((m) => m.storage == raw, orElse: () => FleetMode.personal);
}
