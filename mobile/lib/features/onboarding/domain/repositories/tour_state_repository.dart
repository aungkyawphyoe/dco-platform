import '../entities/tour_progress.dart';

/// Local, account-scoped persistence for tour progress.
///
/// Tour state never leaves the device and is not part of sync.
abstract interface class TourStateRepository {
  Future<TourProgress> load(String userId);

  Future<void> save(String userId, TourProgress progress);
}
