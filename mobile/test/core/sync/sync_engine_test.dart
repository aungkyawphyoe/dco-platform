import 'dart:io';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/media/media_api.dart';
import 'package:dco_mobile/core/network/api_error.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/core/sync/sync_engine.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class FakeSyncApi implements SyncApi {
  FakeSyncApi();

  final recordedOps = <SyncOperationDto>[];
  List<SyncPushResult> Function(List<SyncOperationDto> ops)? pushHandler;
  SyncPullPage Function(String cursor)? pullHandler;

  @override
  Future<List<SyncPushResult>> push(List<SyncOperationDto> operations) async {
    recordedOps.addAll(operations);
    if (pushHandler != null) return pushHandler!(operations);
    return operations
        .map(
          (op) => SyncPushResult(entityId: op.entityId, status: SyncPushStatus.applied),
        )
        .toList();
  }

  @override
  Future<SyncPullPage> pull(String cursor) {
    if (pullHandler != null) return Future.value(pullHandler!(cursor));
    return Future.value(const SyncPullPage(cursor: '', changes: []));
  }
}

class FakeMediaApi implements MediaApi {
  final uploads = <({String id, File file, MediaPurpose purpose})>[];
  String uploadedId = 'media-1';

  @override
  Future<MediaObject> upload({
    required String id,
    required File file,
    required MediaPurpose purpose,
  }) async {
    uploads.add((id: id, file: file, purpose: purpose));
    return MediaObject(id: uploadedId, contentType: 'image/jpeg', byteSize: 10);
  }

  @override
  Future<MediaObject> get(String mediaId) async {
    return MediaObject(id: mediaId, contentType: 'image/jpeg', byteSize: 10);
  }
}

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late FakeMediaApi mediaApi;
  late OutboxWriter outbox;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    mediaApi = FakeMediaApi();
    outbox = OutboxWriter(db);
    engine = SyncEngine(
      db: db,
      api: api,
      mediaApi: mediaApi,
      currentUser: () => 'u1',
      outbox: outbox,
      uuid: const Uuid(),
      debounce: Duration.zero,
    );
  });

  tearDown(() {
    engine.dispose();
    db.close();
  });

  Future<void> enqueue(
    String userId, {
    required String entityType,
    required String entityId,
    String op = 'upsert',
  }) {
    return outbox.enqueue(
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      op: OutboxOp.upsert,
      payload: {'id': entityId},
    );
  }

  test('drains outbox in order and clears acked rows', () async {
    await enqueue('u1', entityType: OutboxEntityType.vehicle, entityId: 'v1');
    await enqueue('u1', entityType: OutboxEntityType.expense, entityId: 'e1');

    await engine.syncNow();

    expect(api.recordedOps.map((op) => op.entityId), ['v1', 'e1']);
    final remaining = await db.select(db.outboxEntries).get();
    expect(remaining, isEmpty);
    expect(engine.state.phase, SyncPhase.idle);
    expect(engine.state.lastSyncedAt, isNotNull);
  });

  test('rejected op is kept with attempt count and error', () async {
    await enqueue('u1', entityType: OutboxEntityType.vehicle, entityId: 'v1');
    await enqueue('u1', entityType: OutboxEntityType.expense, entityId: 'e1');
    api.pushHandler = (ops) => ops
        .map(
          (op) => op.entityId == 'v1'
              ? const SyncPushResult(
                  entityId: 'v1',
                  status: SyncPushStatus.rejected,
                  error: ApiError(code: 'validation', message: 'bad payload'),
                )
              : SyncPushResult(entityId: op.entityId, status: SyncPushStatus.applied),
        )
        .toList();

    await engine.syncNow();

    final rows = await db.select(db.outboxEntries).get();
    final rejected = rows.where((row) => row.entityId == 'v1').single;
    expect(rejected.attemptCount, 1);
    expect(rejected.lastError, 'bad payload');
    expect(rows.where((row) => row.entityId == 'e1'), isEmpty);
  });

  test('dead-lettered ops stop being pushed', () async {
    await (db.into(db.outboxEntries).insert(
          OutboxEntriesCompanion.insert(
            userId: 'u1',
            entityType: OutboxEntityType.vehicle,
            entityId: 'v-dead',
            op: 'upsert',
            payload: '{}',
            clientTs: DateTime.now().toUtc(),
            attemptCount: const Value(5),
          ),
        ));

    await engine.syncNow();

    expect(api.recordedOps, isEmpty);
    final row = await db.select(db.outboxEntries).getSingle();
    expect(row.entityId, 'v-dead');
  });

  test('network failure keeps the queue and reports error state', () async {
    await enqueue('u1', entityType: OutboxEntityType.vehicle, entityId: 'v1');
    api.pushHandler = (ops) => throw const ApiError(code: 'network', message: 'offline');

    await engine.syncNow();

    expect(engine.state.hasError, true);
    final rows = await db.select(db.outboxEntries).get();
    expect(rows, hasLength(1));
  });

  test("only the signed-in user's rows are drained", () async {
    await enqueue('u2', entityType: OutboxEntityType.vehicle, entityId: 'other');

    await engine.syncNow();

    expect(api.recordedOps, isEmpty);
    final rows = await db.select(db.outboxEntries).get();
    expect(rows, hasLength(1));
  });

  test('pull applies changes and persists the cursor', () async {
    api.pullHandler = (cursor) => SyncPullPage(
      cursor: 'cursor-2',
      changes: [
        SyncChange(
          entityType: OutboxEntityType.vehicle,
          entityId: 'v1',
          op: SyncChangeOp.upsert,
          payload: {
            'id': 'v1',
            'user_id': 'u1',
            'name': 'From server',
            'make': 'Toyota',
            'model': 'Camry',
            'year': 2022,
            'license_plate': 'XYZ999',
            'fuel_type': 'petrol',
            'mileage': 5000.0,
            'updated_at': '2026-01-02T10:00:00.000Z',
          },
          serverTs: DateTime.parse('2026-01-02T10:00:00.000Z'),
        ),
      ],
    );

    await engine.syncNow();

    final vehicle = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(vehicle.name, 'From server');
    final cursorRow = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('sync_cursor:u1')))
        .getSingle();
    expect(cursorRow.value, 'cursor-2');
  });

  test('pull pages are followed until empty', () async {
    var calls = 0;
    api.pullHandler = (cursor) {
      calls++;
      if (calls == 1) {
        return SyncPullPage(cursor: 'c1', changes: const []);
      }
      return const SyncPullPage(cursor: 'c1', changes: []);
    };

    await engine.syncNow();

    expect(calls, 1);
  });

  test('pending media bytes upload then link via follow-up upsert', () async {
    final dir = await Directory.systemTemp.createTemp('dco_media_test');
    final file = File('${dir.path}/photo.jpg')..writeAsBytesSync(List.filled(16, 1));
    addTearDown(() => dir.delete(recursive: true));

    await db.into(db.vehicleRecords).insert(
      VehicleRecordsCompanion.insert(
        id: 'v1',
        userId: 'u1',
        name: 'Daily',
        make: 'Toyota',
        model: 'Camry',
        year: 2022,
        licensePlate: 'ABC123',
        fuelType: 'petrol',
        mileage: 1000,
        photoLocalPath: Value(file.path),
        updatedAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
      ),
    );

    await engine.syncNow();

    expect(mediaApi.uploads.single.purpose, MediaPurpose.vehiclePhoto);
    final vehicle = await (db.select(db.vehicleRecords)
          ..where((r) => r.id.equals('v1')))
        .getSingle();
    expect(vehicle.photoMediaId, 'media-1');

    final linkOp = api.recordedOps.where((op) => op.entityId == 'v1').single;
    expect(linkOp.payload['photo_media_id'], 'media-1');

    final remaining = await db.select(db.outboxEntries).get();
    expect(remaining, isEmpty);
  });

  test('signed-out engine does nothing', () async {
    final signedOut = SyncEngine(
      db: db,
      api: api,
      mediaApi: mediaApi,
      currentUser: () => null,
      debounce: Duration.zero,
    );
    await enqueue('u1', entityType: OutboxEntityType.vehicle, entityId: 'v1');

    await signedOut.syncNow();

    expect(api.recordedOps, isEmpty);
    expect(signedOut.state.phase, SyncPhase.idle);
    signedOut.dispose();
  });
}
