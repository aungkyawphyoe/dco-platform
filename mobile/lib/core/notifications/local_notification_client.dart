/// Platform-agnostic local OS notifications. Implementations must work offline.
abstract class LocalNotificationClient {
  Stream<String> get taps;

  Future<void> initialize();

  /// Prompts once. Later calls return the current grant without re-prompting.
  Future<bool> requestPermissionIfNeeded();

  Future<bool> get notificationsAllowed;

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<List<int>> pendingIds();

  Future<String?> consumeLaunchPayload();
}

/// Used in tests and when the OS plugin is unavailable.
class NoopLocalNotificationClient implements LocalNotificationClient {
  NoopLocalNotificationClient();

  final List<int> shown = [];
  final List<int> scheduled = [];
  bool permissionGranted = true;
  bool askedPermission = false;

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> get notificationsAllowed async => permissionGranted;

  @override
  Future<bool> requestPermissionIfNeeded() async {
    askedPermission = true;
    return permissionGranted;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    String? payload,
  }) async {
    scheduled.add(id);
  }

  @override
  Future<void> cancel(int id) async {
    shown.remove(id);
    scheduled.remove(id);
  }

  @override
  Future<List<int>> pendingIds() async => List.of(scheduled);

  @override
  Future<String?> consumeLaunchPayload() async => null;
}
