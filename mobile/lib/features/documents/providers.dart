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

/// Only file type is cached; signed URLs and file bytes are not needed to filter.
final documentFileTypeProvider = StreamProvider.autoDispose
    .family<DocumentFileType?, String>((ref, mediaId) async* {
      final db = ref.watch(recordDatabaseProvider);
      final userId = ref.watch(currentUserIdProvider);
      final orgId = ref.watch(driverOrganizationIdProvider);
      final dio = ref.watch(dioProvider);
      var active = true;
      ref.onDispose(() => active = false);
      final key = 'document_type:$userId:$mediaId';
      final row = await (db.select(
        db.appMeta,
      )..where((r) => r.key.equals(key))).getSingleOrNull();
      final cached = DocumentFileType.fromContentType(row?.value);
      yield cached;
      if (cached != null || userId == null) return;
      try {
        final String? contentType;
        if (orgId == null) {
          final response = await dio.get<Map<String, dynamic>>(
            '/media/$mediaId',
          );
          contentType = response.data?['content_type'] as String?;
        } else {
          final response = await dio.head<void>(
            '/organizations/$orgId/media/$mediaId/content',
          );
          contentType = response.headers.value('content-type');
        }
        if (!active || DocumentFileType.fromContentType(contentType) == null) {
          return;
        }
        await db
            .into(db.appMeta)
            .insertOnConflictUpdate(
              AppMetaCompanion.insert(key: key, value: Value(contentType)),
            );
        yield DocumentFileType.fromContentType(contentType);
      } catch (_) {
        // Unknown files remain visible under All until metadata is available.
      }
    });
