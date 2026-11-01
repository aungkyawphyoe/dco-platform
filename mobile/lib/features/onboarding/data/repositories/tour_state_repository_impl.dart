import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/tour_progress.dart';
import '../../domain/repositories/tour_state_repository.dart';

/// Stores one AppMeta row per account: `onboarding_tour:<userId>`.
///
/// The row is keyed by user id so signing in as another account on the same
/// phone starts with its own progress. The stored version decides whether the
/// current tour still needs to be offered.
class TourStateRepositoryImpl implements TourStateRepository {
  TourStateRepositoryImpl(this._db);

  final AppDatabase _db;

  static String keyFor(String userId) => 'onboarding_tour:$userId';

  @override
  Future<TourProgress> load(String userId) async {
    final row = await (_db.select(
      _db.appMeta,
    )..where((r) => r.key.equals(keyFor(userId)))).getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return const TourProgress.notSeen();

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final version = data['version'] as int?;
      if (version != kTourVersion) return const TourProgress.notSeen();
      final status = TourStatus.values.byName(data['status'] as String);
      if (status == TourStatus.notSeen) return const TourProgress.notSeen();
      return TourProgress(version: version!, status: status);
    } catch (_) {
      // Corrupt or legacy metadata must never block normal use.
      return const TourProgress.notSeen();
    }
  }

  @override
  Future<void> save(String userId, TourProgress progress) async {
    final key = keyFor(userId);
    final value = jsonEncode({
      'version': progress.version,
      'status': progress.status.name,
    });
    final existing = await (_db.select(
      _db.appMeta,
    )..where((r) => r.key.equals(key))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.appMeta)
          .insert(AppMetaCompanion.insert(key: key, value: Value(value)));
      return;
    }
    await (_db.update(_db.appMeta)..where((r) => r.id.equals(existing.id)))
        .write(AppMetaCompanion(value: Value(value)));
  }
}
