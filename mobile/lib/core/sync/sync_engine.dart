import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../media/media_api.dart';
import '../network/api_error.dart';
import 'change_applier.dart';
import 'outbox_models.dart';
import 'outbox_writer.dart';
import 'sync_api.dart';

enum SyncPhase { idle, syncing, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.message,
    this.autoSyncEnabled = true,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? message;
  final bool autoSyncEnabled;

  bool get hasError => phase == SyncPhase.error;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? message,
    bool? autoSyncEnabled,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }

  static const initial = SyncState();
}

/// Offline-first drain: local writes are already queued in the outbox.
/// Pushes queued operations in order, uploads pending media bytes, then
/// pulls the server change log. UI keeps reading Drift throughout.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required SyncApi api,
    required MediaApi mediaApi,
    required String? Function() currentUser,
    OutboxWriter? outbox,
    ChangeApplier? applier,
    Uuid uuid = const Uuid(),
    Duration debounce = const Duration(seconds: 1),
    int batchSize = 25,
    int maxAttempts = 5,
    DateTime Function()? now,
  }) : _db = db,
       _api = api,
       _mediaApi = mediaApi,
       _currentUser = currentUser,
       _outbox = outbox ?? OutboxWriter(db),
       _applier = applier ?? ChangeApplier(db),
       _uuid = uuid,
       _debounce = debounce,
       _batchSize = batchSize,
       _maxAttempts = maxAttempts,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncApi _api;
  final MediaApi _mediaApi;
  final String? Function() _currentUser;
  final OutboxWriter _outbox;
  final ChangeApplier _applier;
  final Uuid _uuid;
  final Duration _debounce;
  final int _batchSize;
  final int _maxAttempts;
  final DateTime Function() _now;

  Timer? _timer;
  bool _running = false;
  bool _queuedAfterRun = false;
  SyncState _state = SyncState.initial;
  final _states = StreamController<SyncState>.broadcast();

  SyncState get state => _state;
  Stream<SyncState> get stream => _states.stream;

  /// Debounced trigger used by repositories after local writes.
  void requestSync() {
    _timer?.cancel();
    _timer = Timer(_debounce, syncNow);
  }

  /// Immediate drain used after login or connectivity regain.
  Future<void> syncNow() async {
    _timer?.cancel();
    if (_running) {
      _queuedAfterRun = true;
      return;
    }
    _running = true;
    _emit(const SyncState(phase: SyncPhase.syncing));
    try {
      final userId = _currentUser();
      if (userId == null || userId.isEmpty) {
        _emit(SyncState(phase: SyncPhase.idle, lastSyncedAt: _state.lastSyncedAt));
        return;
      }
      await _pushAll(userId);
      final linked = await _uploadPendingMedia(userId);
      if (linked > 0) {
        await _pushAll(userId);
      }
      await _pullAll(userId);
      _emit(SyncState(phase: SyncPhase.idle, lastSyncedAt: _now()));
    } on ApiError catch (error) {
      _emit(
        SyncState(
          phase: SyncPhase.error,
          lastSyncedAt: _state.lastSyncedAt,
          message: error.message,
        ),
      );
    } finally {
      _running = false;
      if (_queuedAfterRun) {
        _queuedAfterRun = false;
        requestSync();
      }
    }
  }

  Future<int> _pushAll(String userId) async {
    var pushedBatches = 0;
    while (true) {
      final rows = await (_db.select(_db.outboxEntries)
            ..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.attemptCount.isSmallerThanValue(_maxAttempts),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.id)])
            ..limit(_batchSize))
          .get();
      if (rows.isEmpty) return pushedBatches;

      final operations = rows
          .map(
            (row) => SyncOperationDto(
              entityType: row.entityType,
              entityId: row.entityId,
              op: row.op,
              payload: jsonDecode(row.payload) as Map<String, dynamic>,
              clientTs: row.clientTs,
            ),
          )
          .toList();
      final results = await _api.push(operations);
      final byEntityId = {for (final result in results) result.entityId: result};

      var ackedCount = 0;
      for (final row in rows) {
        final result = byEntityId[row.entityId];
        if (result != null && result.acked) {
          await (_db.delete(_db.outboxEntries)..where((r) => r.id.equals(row.id))).go();
          ackedCount++;
          continue;
        }
        final reason = result?.error?.message ?? result?.status.name ?? 'no_result';
        await (_db.update(_db.outboxEntries)..where((r) => r.id.equals(row.id))).write(
          OutboxEntriesCompanion(
            attemptCount: Value(row.attemptCount + 1),
            lastError: Value(reason),
          ),
        );
      }
      pushedBatches++;
      if (ackedCount < rows.length) return pushedBatches;
    }
  }

  Future<int> _uploadPendingMedia(String userId) async {
    var linked = 0;
    linked += await _flushVehiclePhotos(userId);
    linked += await _flushServiceReceipts(userId);
    linked += await _flushExpenseReceipts(userId);
    linked += await _flushDocuments(userId);
    return linked;
  }

  Future<int> _flushVehiclePhotos(String userId) async {
    final rows = await (_db.select(_db.vehicleRecords)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.photoLocalPath.isNotNull() &
                row.photoMediaId.isNull(),
          ))
        .get();
    var linked = 0;
    for (final row in rows) {
      final media = await _uploadFile(
        file: File(row.photoLocalPath!),
        purpose: MediaPurpose.vehiclePhoto,
      );
      if (media == null) continue;
      await (_db.update(_db.vehicleRecords)..where((r) => r.id.equals(row.id))).write(
        VehicleRecordsCompanion(photoMediaId: Value(media)),
      );
      final refreshed = await (_db.select(
        _db.vehicleRecords,
      )..where((r) => r.id.equals(row.id))).getSingle();
      await _enqueueVehicleUpsert(refreshed, userId);
      linked++;
    }
    return linked;
  }

  Future<int> _flushServiceReceipts(String userId) async {
    final rows = await (_db.select(_db.serviceRecordRows)
          ..where(
            (row) =>
                row.receiptLocalPath.isNotNull() & row.receiptMediaId.isNull(),
          ))
        .get();
    var linked = 0;
    for (final row in rows) {
      final media = await _uploadFile(
        file: File(row.receiptLocalPath!),
        purpose: MediaPurpose.serviceReceipt,
      );
      if (media == null) continue;
      await (_db.update(_db.serviceRecordRows)..where((r) => r.id.equals(row.id))).write(
        ServiceRecordRowsCompanion(receiptMediaId: Value(media)),
      );
      final refreshed = await (_db.select(
        _db.serviceRecordRows,
      )..where((r) => r.id.equals(row.id))).getSingle();
      await _enqueueServiceRecordUpsert(refreshed, userId);
      linked++;
    }
    return linked;
  }

  Future<int> _flushExpenseReceipts(String userId) async {
    final rows = await (_db.select(_db.expenseRecords)
          ..where(
            (row) =>
                row.receiptLocalPath.isNotNull() & row.receiptMediaId.isNull(),
          ))
        .get();
    var linked = 0;
    for (final row in rows) {
      final media = await _uploadFile(
        file: File(row.receiptLocalPath!),
        purpose: MediaPurpose.expenseReceipt,
      );
      if (media == null) continue;
      await (_db.update(_db.expenseRecords)..where((r) => r.id.equals(row.id))).write(
        ExpenseRecordsCompanion(receiptMediaId: Value(media)),
      );
      final refreshed = await (_db.select(
        _db.expenseRecords,
      )..where((r) => r.id.equals(row.id))).getSingle();
      await _enqueueExpenseUpsert(refreshed, userId);
      linked++;
    }
    return linked;
  }

  Future<int> _flushDocuments(String userId) async {
    final rows = await (_db.select(_db.documentRecords)
          ..where(
            (row) =>
                row.localFilePath.isNotNull() & row.mediaId.isNull(),
          ))
        .get();
    var linked = 0;
    for (final row in rows) {
      final media = await _uploadFile(
        file: File(row.localFilePath!),
        purpose: MediaPurpose.document,
      );
      if (media == null) continue;
      await (_db.update(_db.documentRecords)..where((r) => r.id.equals(row.id))).write(
        DocumentRecordsCompanion(mediaId: Value(media)),
      );
      final refreshed = await (_db.select(
        _db.documentRecords,
      )..where((r) => r.id.equals(row.id))).getSingle();
      await _enqueueDocumentUpsert(refreshed, userId);
      linked++;
    }
    return linked;
  }

  Future<String?> _uploadFile({required File file, required MediaPurpose purpose}) async {
    if (!file.existsSync()) return null;
    try {
      final media = await _mediaApi.upload(id: _uuid.v4(), file: file, purpose: purpose);
      return media.id;
    } on ApiError catch (error) {
      // Connectivity problems abort the whole drain; permanent rejects
      // (too large, validation) are skipped until the file changes.
      if (error.code == 'network') rethrow;
      return null;
    }
  }

  Future<void> _enqueueVehicleUpsert(VehicleRecord row, String userId) {
    return _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.vehicle,
      entityId: row.id,
      op: OutboxOp.upsert,
      payload: _vehicleWriteJson(row),
    );
  }

  Future<void> _enqueueServiceRecordUpsert(ServiceRecordRow row, String userId) async {
    final lines = await (_db.select(
      _db.serviceLineRecords,
    )..where((item) => item.serviceRecordId.equals(row.id))).get();
    final parts = await (_db.select(
      _db.servicePartRecords,
    )..where((part) => part.serviceRecordId.equals(row.id))).get();
    return _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.serviceRecord,
      entityId: row.id,
      op: OutboxOp.upsert,
      payload: _serviceRecordWriteJson(row, lines, parts),
    );
  }

  Future<void> _enqueueExpenseUpsert(ExpenseRecord row, String userId) async {
    final parts = await (_db.select(
      _db.expensePartRecords,
    )..where((part) => part.expenseId.equals(row.id))).get();
    return _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.expense,
      entityId: row.id,
      op: OutboxOp.upsert,
      payload: _expenseWriteJson(row, parts),
    );
  }

  Future<void> _enqueueDocumentUpsert(DocumentRecord row, String userId) {
    return _outbox.enqueue(
      userId: userId,
      entityType: OutboxEntityType.document,
      entityId: row.id,
      op: OutboxOp.upsert,
      payload: _documentWriteJson(row),
    );
  }

  Future<void> _pullAll(String userId) async {
    var cursor = await _readCursor(userId);
    const maxPages = 100;
    for (var page = 0; page < maxPages; page++) {
      final pulled = await _api.pull(cursor);
      if (pulled.changes.isNotEmpty) {
        await _db.transaction(() async {
          for (final change in pulled.changes) {
            await _applier.apply(change, userId: userId);
          }
        });
      }
      await _writeCursor(userId, pulled.cursor);
      if (pulled.changes.isEmpty || pulled.cursor == cursor) return;
      cursor = pulled.cursor;
    }
  }

  Future<String> _readCursor(String userId) async {
    final key = 'sync_cursor:$userId';
    final row = await (_db.select(_db.appMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? '';
  }

  Future<void> _writeCursor(String userId, String cursor) {
    return _writeMeta('sync_cursor:$userId', cursor);
  }

  Future<void> _writeMeta(String key, String? value) async {
    final existing = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.appMeta)..where((m) => m.id.equals(existing.id))).write(
        AppMetaCompanion(value: Value(value)),
      );
    } else {
      await _db
          .into(_db.appMeta)
          .insert(AppMetaCompanion.insert(key: key, value: Value(value)));
    }
  }

  Map<String, dynamic> _vehicleWriteJson(VehicleRecord row) => {
    'id': row.id,
    'name': row.name,
    'nickname': row.nickname,
    'make': row.make,
    'model': row.model,
    'year': row.year,
    'license_plate': row.licensePlate,
    'vin': row.vin,
    'color': row.color,
    'fuel_type': row.fuelType,
    'mileage': row.mileage,
    'mileage_unit': row.mileageUnit,
    'purchase_date': row.purchaseDate?.toIso8601String().split('T').first,
    'purchase_price': row.purchasePrice,
    'photo_media_id': row.photoMediaId,
  };

  Map<String, dynamic> _serviceRecordWriteJson(
    ServiceRecordRow row,
    List<ServiceLineRecord> lines,
    List<ServicePartRecord> parts,
  ) => {
    'id': row.id,
    'serviced_on': row.servicedOn.toIso8601String().split('T').first,
    'odometer': row.odometer,
    'total_cost': row.totalCost,
    'workshop_name': row.workshopName,
    'notes': row.notes,
    'title': row.title,
    'receipt_media_id': row.receiptMediaId,
    'items': lines
        .map(
          (line) => {
            'id': line.id,
            'plan_item_id': line.planItemId,
            'name': line.name,
            'line_cost': line.lineCost,
          },
        )
        .toList(),
    'parts': parts
        .map(
          (part) => {'id': part.id, 'part_id': part.partId, 'name': part.name},
        )
        .toList(),
  };

  Map<String, dynamic> _expenseWriteJson(
    ExpenseRecord row,
    List<ExpensePartRecord> parts,
  ) => {
    'id': row.id,
    'vehicle_id': row.vehicleId,
    'category': row.category,
    'amount': row.amount,
    'incurred_on': row.incurredOn.toIso8601String().split('T').first,
    'notes': row.notes,
    'receipt_media_id': row.receiptMediaId,
    'parts': parts
        .map(
          (part) => {'id': part.id, 'part_id': part.partId, 'name': part.name},
        )
        .toList(),
  };

  Map<String, dynamic> _documentWriteJson(DocumentRecord row) => {
    'id': row.id,
    'name': row.name,
    'category': row.category,
    'notes': row.notes,
    'media_id': row.mediaId,
  };

  void _emit(SyncState newState) {
    _state = newState;
    _states.add(newState);
  }

  void dispose() {
    _timer?.cancel();
    _states.close();
  }
}
