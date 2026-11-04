import 'dart:convert';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(documentRepositoryProvider).watchForVehicle(vehicleId);
});

/// Same data as [vehicleDocumentsProvider], keyed by an explicit vehicle id
/// so the vehicle detail screen can render for a non-active vehicle.
final documentsForVehicleProvider =
    StreamProvider.family<List<Document>, String>((ref, vehicleId) {
      if (vehicleId.isEmpty) return Stream.value(const []);
      return ref.watch(documentRepositoryProvider).watchForVehicle(vehicleId);
    });

final documentUploadErrorProvider = StreamProvider.family<String?, String>((
  ref,
  path,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.appMeta)
        ..where((r) => r.key.equals('media_error:$path')))
      .watchSingleOrNull()
      .map((row) => row?.value);
});

/// Cache usage in the account-scoped database so Documents remains useful offline.
final documentStorageProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final org = ref.watch(driverOrganizationIdProvider);
  final key = 'document_storage:${org ?? 'personal'}';
  final dio = ref.watch(dioProvider);
  Future<void>(() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        org == null ? '/users/me/storage' : '/organizations/$org/storage',
      );
      await db
          .into(db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(
              key: key,
              value: Value(jsonEncode(response.data)),
            ),
          );
    } catch (_) {
      /* Keep the last known usage while offline. */
    }
  });
  return (db.select(
    db.appMeta,
  )..where((r) => r.key.equals(key))).watchSingleOrNull().map(
    (row) => row?.value == null
        ? null
        : jsonDecode(row!.value!) as Map<String, dynamic>,
  );
});
