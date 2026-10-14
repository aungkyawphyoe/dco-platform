/// App navigation mode, derived from live entitlements. `org_driver`
/// accounts are forced into Driver mode; everyone else stays in the personal
/// garage — fleet management lives on the Fleet Portal. (A legacy stored
/// `fleet` value degrades to `personal`.)
enum FleetMode {
  personal('personal'),
  driver('driver');

  const FleetMode(this.storage);

  final String storage;

  static FleetMode fromStorage(String? raw) =>
      FleetMode.values.firstWhere((m) => m.storage == raw, orElse: () => FleetMode.personal);
}
