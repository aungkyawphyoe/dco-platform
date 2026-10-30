import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../network/auth_interceptor.dart';
import 'outbox_models.dart';
import 'outbox_writer.dart';
import 'sync_api.dart';

String recordMetaKey(String kind, String id) => 'org_record:$kind:$id';

Future<void> saveOrgMeta(AppDatabase db, String key, Object? value) async {
  await db
      .into(db.appMeta)
      .insert(
        AppMetaCompanion.insert(key: key, value: Value(jsonEncode(value))),
        onConflict: DoUpdate(
          (_) => AppMetaCompanion(value: Value(jsonEncode(value))),
          target: [db.appMeta.key],
        ),
      );
}

class OrganizationOutboxWriter extends OutboxWriter {
  OrganizationOutboxWriter(this.db) : super(db);
  final AppDatabase db;

  @override
  bool get derivesExpenses => true;

  @override
  Future<void> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required OutboxOp op,
    required Map<String, dynamic> payload,
  }) async {
    // Repositories optimistically derive mileage and due dates. Only the service
    // or fuel log is sent; the server owns these derived vehicle/plan changes.
    if (entityType == OutboxEntityType.vehicle ||
        entityType == OutboxEntityType.planItem) {
      return;
    }
    if (entityType == OutboxEntityType.fuelType ||
        entityType == OutboxEntityType.notification) {
      return super.enqueue(
        userId: userId,
        entityType: entityType,
        entityId: entityId,
        op: op,
        payload: payload,
      );
    }
    final meta =
        await (db.select(db.appMeta)
              ..where((m) => m.key.equals(recordMetaKey(entityType, entityId))))
            .getSingleOrNull();
    final metadata = meta?.value == null
        ? <String, dynamic>{}
        : jsonDecode(meta!.value!) as Map<String, dynamic>;
    if (metadata['source_id'] != null) {
      throw StateError(
        'Change the linked service or fuel log to correct this expense.',
      );
    }
    if (metadata['admin_corrected_by'] != null) {
      throw StateError('Updated by Fleet Admin. This record is read-only.');
    }
    if (metadata['created_by'] != null && metadata['created_by'] != userId) {
      throw StateError('Only the author can change this record.');
    }
    final queued =
        await (db.select(db.outboxEntries)..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.entityType.equals(entityType) &
                  r.entityId.equals(entityId),
            ))
            .get();
    final revision = metadata['revision'] as int?;
    final expected = revision == null && queued.isEmpty
        ? null
        : (revision ?? 0) + queued.length;
    // Keep vehicle identity on every operation, including deletes after the
    // local record has gone and edits queued before the first create is acked.
    final vehicleId =
        payload['vehicle_id'] ??
        metadata['vehicle_id'] ??
        (queued.isEmpty
            ? null
            : (jsonDecode(queued.last.payload)
                  as Map<String, dynamic>)['vehicle_id']);
    if (vehicleId == null) {
      throw StateError('Missing vehicle for queued record');
    }
    await super.enqueue(
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      op: op,
      payload: {
        ...payload,
        'vehicle_id': vehicleId,
        '_operation_id': const Uuid().v4(),
        '_expected_revision': expected,
      },
    );
    if (entityType == OutboxEntityType.serviceRecord ||
        entityType == OutboxEntityType.fuelLog) {
      if (op == OutboxOp.delete) {
        final mapped =
            await (db.select(db.appMeta)..where(
                  (r) =>
                      r.key.equals('org_expense_source:$entityType:$entityId'),
                ))
                .getSingleOrNull();
        final expenseId = mapped?.value == null
            ? entityId
            : jsonDecode(mapped!.value!) as String;
        await (db.delete(
          db.expensePartRecords,
        )..where((r) => r.expenseId.equals(expenseId))).go();
        await (db.delete(
          db.expenseRecords,
        )..where((r) => r.id.equals(expenseId))).go();
        return;
      }
      final service = entityType == OutboxEntityType.serviceRecord;
      final amount = payload[service ? 'total_cost' : 'cost'] as num?;
      final date = payload[service ? 'serviced_on' : 'logged_on'] as String?;
      if (amount != null && date != null) {
        final mapped =
            await (db.select(db.appMeta)..where(
                  (r) =>
                      r.key.equals('org_expense_source:$entityType:$entityId'),
                ))
                .getSingleOrNull();
        final expenseId = mapped?.value == null
            ? entityId
            : jsonDecode(mapped!.value!) as String;
        final now = DateTime.now().toUtc();
        await db
            .into(db.expenseRecords)
            .insertOnConflictUpdate(
              ExpenseRecordsCompanion.insert(
                id: expenseId,
                vehicleId: vehicleId as String,
                category: service ? 'maintenance' : 'fuel',
                amount: amount.toDouble(),
                currency: Value(payload['currency'] as String? ?? 'MMK'),
                incurredOn: DateTime.parse(date),
                createdBy: Value(userId),
                updatedAt: now,
                createdAt: now,
              ),
            );
        await saveOrgMeta(db, recordMetaKey('expense', expenseId), {
          'vehicle_id': vehicleId,
          'source_id': entityId,
          'source_kind': entityType,
          'created_by': userId,
        });
      }
    }
  }
}

class OrganizationSyncApi implements SyncApi {
  OrganizationSyncApi(this.dio, this.db, this.organizationId, this.userId);
  final Dio dio;
  final AppDatabase db;
  final String organizationId;
  final String userId;
  String get base => '/organizations/$organizationId';

  Future<String> _vehicleId(SyncOperationDto operation) async {
    if (operation.payload['vehicle_id'] is String) {
      return operation.payload['vehicle_id'] as String;
    }
    final meta =
        await (db.select(db.appMeta)..where(
              (m) => m.key.equals(
                recordMetaKey(operation.entityType, operation.entityId),
              ),
            ))
            .getSingleOrNull();
    if (meta?.value != null) {
      return (jsonDecode(meta!.value!) as Map<String, dynamic>)['vehicle_id']
          as String;
    }
    throw StateError('Missing vehicle for queued record');
  }

  @override
  Future<List<SyncPushResult>> push(List<SyncOperationDto> operations) async {
    final results = <SyncPushResult>[];
    try {
      // Serialize to keep consecutive revisions for one record in order.
      for (final operation in operations) {
        if (operation.entityType == OutboxEntityType.fuelType ||
            operation.entityType == OutboxEntityType.notification) {
          results.addAll(await DioSyncApi(dio).push([operation]));
          continue;
        }
        final data = {...operation.payload}
          ..removeWhere((key, _) => key.startsWith('_'));
        final submitted = {
          'operation_id': operation.payload['_operation_id'],
          'entity_type': operation.entityType,
          'entity_id': operation.entityId,
          'vehicle_id': await _vehicleId(operation),
          'op': operation.op,
          'expected_revision': operation.payload['_expected_revision'],
          'payload': data,
        };
        final response = await dio.post<Map<String, dynamic>>(
          '$base/sync/push',
          data: {
            'operations': [submitted],
          },
        );
        final raw =
            (response.data!['results'] as List).single as Map<String, dynamic>;
        final result = SyncPushResult.fromJson(raw);
        results.add(result);
        if (result.status == SyncPushStatus.review) {
          await db.transaction(() async {
            await saveOrgMeta(db, 'org_review:${raw['review_id']}', {
              'id': raw['review_id'],
              'status': 'pending',
              'operation': submitted,
            });
            // Unapproved submissions must not contribute to live history/totals.
            // A full pull restores the server version of a conflicting edit.
            await _removeUnapproved(operation);
            // Persist the reset until SyncEngine successfully applies a snapshot
            // and advances the cursor. A crash during pull must retry restoration.
            await db
                .into(db.appMeta)
                .insert(
                  AppMetaCompanion.insert(
                    key: 'sync_cursor:$userId',
                    value: const Value(''),
                  ),
                  onConflict: DoUpdate(
                    (_) => const AppMetaCompanion(value: Value('')),
                    target: [db.appMeta.key],
                  ),
                );
          });
        } else if (result.acked) {
          final key = recordMetaKey(operation.entityType, operation.entityId);
          final existing = await (db.select(
            db.appMeta,
          )..where((m) => m.key.equals(key))).getSingleOrNull();
          final metadata = existing?.value == null
              ? <String, dynamic>{}
              : jsonDecode(existing!.value!) as Map<String, dynamic>;
          await saveOrgMeta(db, key, {
            ...metadata,
            'vehicle_id': submitted['vehicle_id'],
            'created_by': metadata['created_by'] ?? userId,
            'revision':
                ((operation.payload['_expected_revision'] as int?) ?? 0) + 1,
          });
        }
        if (!result.acked) break;
      }
      return results;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> _removeUnapproved(SyncOperationDto operation) => db.transaction(
    () async {
      final id = operation.entityId;
      switch (operation.entityType) {
        case OutboxEntityType.serviceRecord:
          await (db.delete(
            db.serviceLineRecords,
          )..where((r) => r.serviceRecordId.equals(id))).go();
          await (db.delete(
            db.servicePartRecords,
          )..where((r) => r.serviceRecordId.equals(id))).go();
          await (db.delete(
            db.serviceRecordRows,
          )..where((r) => r.id.equals(id))).go();
        case OutboxEntityType.fuelLog:
          await (db.delete(
            db.fuelLogRecords,
          )..where((r) => r.id.equals(id))).go();
        case OutboxEntityType.document:
          await (db.delete(
            db.documentRecords,
          )..where((r) => r.id.equals(id))).go();
        case OutboxEntityType.part:
          await (db.delete(db.partRecords)..where((r) => r.id.equals(id))).go();
      }
      if ([
        OutboxEntityType.expense,
        OutboxEntityType.serviceRecord,
        OutboxEntityType.fuelLog,
      ].contains(operation.entityType)) {
        final mapped =
            await (db.select(db.appMeta)..where(
                  (r) => r.key.equals(
                    'org_expense_source:${operation.entityType}:$id',
                  ),
                ))
                .getSingleOrNull();
        final expenseId = mapped?.value == null
            ? id
            : jsonDecode(mapped!.value!) as String;
        await (db.delete(
          db.expensePartRecords,
        )..where((r) => r.expenseId.equals(expenseId))).go();
        await (db.delete(
          db.expenseRecords,
        )..where((r) => r.id.equals(expenseId))).go();
      }
    },
  );

  @override
  Future<SyncPullPage> pull(String cursor) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$base/sync/changes',
        queryParameters: {'cursor': cursor},
      );
      final data = response.data!;
      final vehicleIds = (data['assigned_vehicle_ids'] as List).cast<String>();
      final changes = (data['changes'] as List)
          .cast<Map<String, dynamic>>()
          .map(SyncChange.fromJson)
          .toList();
      await db.transaction(() async {
        if (data['bootstrap'] == true) {
          await _appendSnapshotDeletions(changes, vehicleIds);
        }
        final cached = await db.select(db.vehicleRecords).get();
        for (final vehicle in cached.where((v) => !vehicleIds.contains(v.id))) {
          // Preserve the outbox/review payloads, but remove revoked vehicle data.
          final files = <String?>[
            vehicle.photoLocalPath,
            ...((await (db.select(
              db.documentRecords,
            )..where((r) => r.vehicleId.equals(vehicle.id))).get()).map(
              (r) => r.localFilePath,
            )),
            ...((await (db.select(
              db.expenseRecords,
            )..where((r) => r.vehicleId.equals(vehicle.id))).get()).map(
              (r) => r.receiptLocalPath,
            )),
            ...((await (db.select(
              db.serviceRecordRows,
            )..where((r) => r.vehicleId.equals(vehicle.id))).get()).map(
              (r) => r.receiptLocalPath,
            )),
          ];
          for (final path in files.whereType<String>()) {
            try {
              final file = File(path);
              if (await file.exists()) await file.delete();
            } on FileSystemException {
              /* Best-effort cleanup. */
            }
          }
          final services = await (db.select(
            db.serviceRecordRows,
          )..where((r) => r.vehicleId.equals(vehicle.id))).get();
          for (final service in services) {
            await (db.delete(
              db.serviceLineRecords,
            )..where((r) => r.serviceRecordId.equals(service.id))).go();
            await (db.delete(
              db.servicePartRecords,
            )..where((r) => r.serviceRecordId.equals(service.id))).go();
          }
          final expenses = await (db.select(
            db.expenseRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).get();
          for (final expense in expenses) {
            await (db.delete(
              db.expensePartRecords,
            )..where((r) => r.expenseId.equals(expense.id))).go();
          }
          await (db.delete(
            db.serviceRecordRows,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.expenseRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.fuelLogRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.documentRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.partRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.planItemRecords,
          )..where((r) => r.vehicleId.equals(vehicle.id))).go();
          await (db.delete(
            db.vehicleRecords,
          )..where((r) => r.id.equals(vehicle.id))).go();
        }
        await db.delete(db.vehicleShareRecords).go();
        for (final id in vehicleIds) {
          await db
              .into(db.vehicleShareRecords)
              .insert(
                VehicleShareRecordsCompanion.insert(
                  id: 'org:$id',
                  vehicleId: id,
                  userId: userId,
                  accessLevel: 'add_edit_own',
                  status: const Value('active'),
                  createdAt: DateTime.now().toUtc(),
                ),
              );
        }
        final profile = await (db.select(
          db.userProfiles,
        )..where((p) => p.userId.equals(userId))).getSingleOrNull();
        if (!vehicleIds.contains(profile?.activeVehicleId)) {
          await db
              .into(db.userProfiles)
              .insertOnConflictUpdate(
                UserProfilesCompanion.insert(
                  userId: userId,
                  activeVehicleId: Value(vehicleIds.firstOrNull),
                ),
              );
        }
        for (final change in changes) {
          if (change.entityType == 'expense' &&
              change.payload['source_id'] != null) {
            await saveOrgMeta(
              db,
              'org_expense_source:${change.payload['source_kind']}:${change.payload['source_id']}',
              change.entityId,
            );
          }
          if (change.payload.containsKey('revision')) {
            await saveOrgMeta(
              db,
              recordMetaKey(change.entityType, change.entityId),
              {
                'vehicle_id': change.payload['vehicle_id'],
                'revision': change.payload['revision'],
                'source_id': change.payload['source_id'],
                'source_kind': change.payload['source_kind'],
                'admin_corrected_by': change.payload['admin_corrected_by'],
                'created_by':
                    change.payload['created_by'] ?? change.payload['user_id'],
              },
            );
          }
        }
      });
      final reviews = await dio.get<Map<String, dynamic>>('$base/reviews');
      for (final review
          in (reviews.data!['items'] as List).cast<Map<String, dynamic>>()) {
        await saveOrgMeta(db, 'org_review:${review['id']}', review);
      }
      return SyncPullPage(cursor: data['cursor'] as String, changes: changes);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Bootstrap replaces server history, including deletions missed while the
  /// assignment scope changed. Keep records still represented by local work.
  Future<void> _appendSnapshotDeletions(
    List<SyncChange> changes,
    List<String> vehicleIds,
  ) async {
    final retained = {
      for (final change in changes) '${change.entityType}:${change.entityId}',
    };
    final pending = await db.select(db.outboxEntries).get();
    for (final operation in pending) {
      retained.add('${operation.entityType}:${operation.entityId}');
      if (operation.entityType == OutboxEntityType.serviceRecord ||
          operation.entityType == OutboxEntityType.fuelLog) {
        final mapped =
            await (db.select(db.appMeta)..where(
                  (r) => r.key.equals(
                    'org_expense_source:${operation.entityType}:${operation.entityId}',
                  ),
                ))
                .getSingleOrNull();
        final expenseId = mapped?.value == null
            ? operation.entityId
            : jsonDecode(mapped!.value!) as String;
        retained.add('${OutboxEntityType.expense}:$expenseId');
      }
    }
    final tables = {
      OutboxEntityType.planItem: db.planItemRecords.actualTableName,
      OutboxEntityType.serviceRecord: db.serviceRecordRows.actualTableName,
      OutboxEntityType.expense: db.expenseRecords.actualTableName,
      OutboxEntityType.fuelLog: db.fuelLogRecords.actualTableName,
      OutboxEntityType.document: db.documentRecords.actualTableName,
      OutboxEntityType.part: db.partRecords.actualTableName,
    };
    for (final entry in tables.entries) {
      // Table names come exclusively from the local schema above.
      final rows = await db
          .customSelect('SELECT id, vehicle_id FROM ${entry.value}')
          .get();
      for (final row in rows) {
        final id = row.read<String>('id');
        final vehicleId = row.read<String>('vehicle_id');
        if (!vehicleIds.contains(vehicleId) ||
            retained.contains('${entry.key}:$id')) {
          continue;
        }
        changes.add(
          SyncChange(
            entityType: entry.key,
            entityId: id,
            op: SyncChangeOp.delete,
            payload: {'id': id, 'vehicle_id': vehicleId},
            serverTs: DateTime.now().toUtc(),
          ),
        );
      }
    }
  }
}
