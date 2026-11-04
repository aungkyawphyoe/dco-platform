import 'dart:convert';
import 'dart:io';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/organization_sync_api.dart';
import 'package:dco_mobile/core/sync/outbox_models.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/features/documents/data/repositories/document_repository_impl.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late OrganizationOutboxWriter writer;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = OrganizationOutboxWriter(db);
  });
  tearDown(() => db.close());

  test(
    'fleet kilometer thresholds and service mileage round-trip through canonical storage',
    () async {
      final dio = Dio();
      Map<String, dynamic>? submitted;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/sync/push')) {
              submitted = Map<String, dynamic>.from(
                ((options.data as Map)['operations'] as List).single['payload']
                    as Map,
              );
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'results': [
                      {'entity_id': 'service', 'status': 'applied'},
                    ],
                  },
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: options.path.endsWith('/reviews')
                      ? {'items': <Object>[]}
                      : {
                          'cursor': '1',
                          'assigned_vehicle_ids': <String>[],
                          'changes': [
                            {
                              'entity_type': 'plan_item',
                              'entity_id': 'plan',
                              'op': 'upsert',
                              'server_ts': '2026-01-01T00:00:00Z',
                              'payload': {
                                'next_due_mileage': 33000,
                                'interval_distance': 5000,
                                'warning_distance': 500,
                              },
                            },
                          ],
                        },
                ),
              );
            }
          },
        ),
      );
      final api = OrganizationSyncApi(dio, db, 'org', 'driver');
      final page = await api.pull('');
      final stored = page.changes.single.payload['next_due_mileage'] as double;
      expect(MileageUnit.km.toDisplay(stored), closeTo(33000, 0.001));
      await api.push([
        SyncOperationDto(
          entityType: 'service_record',
          entityId: 'service',
          op: 'upsert',
          payload: {'vehicle_id': 'vehicle', 'odometer': stored},
          clientTs: DateTime(2026),
        ),
      ]);
      expect(submitted!['odometer'] as double, closeTo(33000, 0.001));
    },
  );

  test('fleet cache upgrade normalizes old kilometers without converting pending logs twice', () async {
    final directory = await Directory.systemTemp.createTemp('fleet-distance-upgrade');
    final file = File('${directory.path}/fleet.sqlite');
    var legacy = AppDatabase.scoped('dco_org_upgrade', executor: NativeDatabase(file));
    try {
      final applier = ChangeApplier(legacy);
      Future<void> apply(String kind, String id, Map<String,dynamic> payload) => applier.apply(
        SyncChange(entityType:kind,entityId:id,op:SyncChangeOp.upsert,payload:payload,serverTs:DateTime.utc(2026)), userId:'driver');
      await apply('vehicle','vehicle',{'id':'vehicle','user_id':'driver','name':'Motorcycle','mileage':1609.344,'mileage_unit':'km'});
      for (final id in ['remote','pending']) {
        await apply('service_record',id,{'id':id,'vehicle_id':'vehicle','odometer':id=='remote'?804.672:500.0,'total_cost':42.0,'serviced_on':'2026-01-01','items':<Object>[]});
      }
      await OrganizationOutboxWriter(legacy).enqueue(userId:'driver',entityType:'service_record',entityId:'pending',op:OutboxOp.upsert,
        payload:{'vehicle_id':'vehicle','odometer':500.0});
      await legacy.customStatement('PRAGMA user_version=26');
      await legacy.close();
      legacy = AppDatabase.scoped('dco_org_upgrade', executor: NativeDatabase(file));
      expect((await legacy.select(legacy.vehicleRecords).getSingle()).mileage, closeTo(1000,0.001));
      final services = await legacy.select(legacy.serviceRecordRows).get();
      expect(services.firstWhere((row)=>row.id=='remote').odometer, closeTo(500,0.001));
      expect(services.firstWhere((row)=>row.id=='pending').odometer, 500);
      expect(services.every((row)=>row.totalCost==42), isTrue);
    } finally {
      await legacy.close();
      await directory.delete(recursive:true);
    }
  });

  Future<void> enqueue(
    Map<String, dynamic> payload, {
    OutboxOp op = OutboxOp.upsert,
  }) => writer.enqueue(
    userId: 'driver',
    entityType: 'expense',
    entityId: 'expense',
    op: op,
    payload: payload,
  );

  test(
    'offline create then edit then delete retain scope and ordered revisions',
    () async {
      await enqueue({'id': 'expense', 'vehicle_id': 'assigned'});
      await enqueue({'id': 'expense', 'amount': 20});
      await enqueue({'id': 'expense'}, op: OutboxOp.delete);
      final rows = await db.select(db.outboxEntries).get();
      final payloads = rows
          .map((r) => jsonDecode(r.payload) as Map<String, dynamic>)
          .toList();
      expect(payloads.map((p) => p['_expected_revision']), [null, 1, 2]);
      expect(payloads.map((p) => p['vehicle_id']), everyElement('assigned'));
      expect(payloads.map((p) => p['_operation_id']).toSet(), hasLength(3));
    },
  );

  test(
    'service edits update one local cost without an independent expense operation',
    () async {
      for (final cost in [20, 35]) {
        await writer.enqueue(
          userId: 'driver',
          entityType: 'service_record',
          entityId: 'service',
          op: OutboxOp.upsert,
          payload: {
            'id': 'service',
            'vehicle_id': 'assigned',
            'total_cost': cost,
            'serviced_on': '2026-10-18',
          },
        );
      }
      final costs = await db.select(db.expenseRecords).get();
      expect(costs, hasLength(1));
      expect(costs.single.amount, 35);
      final pending = await db.select(db.outboxEntries).get();
      expect(pending, hasLength(2));
      expect(pending.map((r) => r.entityType), everyElement('service_record'));
      await writer.enqueue(
        userId: 'driver',
        entityType: 'service_record',
        entityId: 'service',
        op: OutboxOp.delete,
        payload: {'id': 'service', 'vehicle_id': 'assigned'},
      );
      expect(await db.select(db.expenseRecords).get(), isEmpty);
      expect((await db.select(db.outboxEntries).get()).last.op, 'delete');
    },
  );

  test(
    'known admin correction and another author cannot queue mutations',
    () async {
      await saveOrgMeta(db, recordMetaKey('expense', 'expense'), {
        'vehicle_id': 'assigned',
        'created_by': 'driver',
        'revision': 4,
        'admin_corrected_by': 'admin',
      });
      await expectLater(enqueue({'vehicle_id': 'assigned'}), throwsStateError);
      await saveOrgMeta(db, recordMetaKey('expense', 'expense'), {
        'vehicle_id': 'assigned',
        'created_by': 'previous-driver',
        'revision': 4,
      });
      await expectLater(enqueue({'vehicle_id': 'assigned'}), throwsStateError);
      expect(await db.select(db.outboxEntries).get(), isEmpty);
    },
  );

  test('rejected document edit leaves the local record unchanged', () async {
    final repo = DocumentRepositoryImpl(db: db, outbox: writer);
    final document = await repo.add(
      userId: 'driver',
      vehicleId: 'assigned',
      draft: const DocumentDraft(
        name: 'Original',
        category: DocumentCategory.other,
      ),
    );
    await saveOrgMeta(db, recordMetaKey('document', document.id), {
      'vehicle_id': 'assigned',
      'created_by': 'driver',
      'revision': 2,
      'admin_corrected_by': 'admin',
    });
    await expectLater(
      repo.update(
        userId: 'driver',
        documentId: document.id,
        draft: const DocumentDraft(
          name: 'Changed',
          category: DocumentCategory.other,
        ),
      ),
      throwsStateError,
    );
    expect((await repo.getById(document.id))!.name, 'Original');
    await expectLater(
      repo.delete(userId: 'driver', documentId: document.id),
      throwsStateError,
    );
    expect(await repo.getById(document.id), isNotNull);
  });
  test(
    'revoked manifest removes vehicle history but preserves queued submissions',
    () async {
      final garage = VehicleRepositoryImpl(db: db, outbox: writer);
      final vehicle = await garage.add(
        userId: 'admin',
        draft: const VehicleDraft(
          name: 'Pool car',
          make: 'Toyota',
          model: 'Corolla',
          year: 2022,
          licensePlate: 'POOL',
          fuelType: FuelType.petrol,
          mileage: 100,
        ),
      );
      await enqueue({'id': 'expense', 'vehicle_id': vehicle.id});
      var assigned = [vehicle.id];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path.endsWith('/reviews')
                    ? {'items': <Object>[]}
                    : {
                        'cursor': 'next',
                        'assigned_vehicle_ids': assigned,
                        'changes': <Object>[],
                      },
              ),
            );
          },
        ),
      );
      final api = OrganizationSyncApi(dio, db, 'org', 'driver');
      await api.pull('');
      expect((await garage.watchActive('driver').first)?.id, vehicle.id);
      expect(
        (await garage.watchActive('driver').first)?.accessLevel,
        isNotNull,
      );
      assigned = [];
      await api.pull('next');
      expect(await garage.watchActive('driver').first, isNull);
      expect(await db.select(db.vehicleRecords).get(), isEmpty);
      expect(await db.select(db.vehicleShareRecords).get(), isEmpty);
      expect(await db.select(db.outboxEntries).get(), hasLength(1));
      dio.close();
    },
  );

  test(
    'reviewed offline service removes its provisional cost from live totals',
    () async {
      await writer.enqueue(
        userId: 'driver',
        entityType: 'service_record',
        entityId: 'service',
        op: OutboxOp.upsert,
        payload: {
          'id': 'service',
          'vehicle_id': 'assigned',
          'total_cost': 80,
          'serviced_on': '2026-10-18',
        },
      );
      final queued = (await db.select(db.outboxEntries).get()).single;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'results': [
                    {
                      'entity_id': 'service',
                      'status': 'review',
                      'review_id': 'review',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final result = await OrganizationSyncApi(dio, db, 'org', 'driver').push([
        SyncOperationDto(
          entityType: queued.entityType,
          entityId: queued.entityId,
          op: queued.op,
          payload: jsonDecode(queued.payload) as Map<String, dynamic>,
          clientTs: queued.clientTs,
        ),
      ]);
      expect(result.single.status, SyncPushStatus.review);
      expect(
        (await (db.select(db.appMeta)
                  ..where((row) => row.key.equals('sync_cursor:driver')))
                .getSingle())
            .value,
        '',
      );
      expect(await db.select(db.expenseRecords).get(), isEmpty);
      expect(
        (await db.select(db.appMeta).get()).any(
          (r) => r.key == 'org_review:review',
        ),
        isTrue,
      );
      dio.close();
    },
  );

  test(
    'bootstrap removes absent server records but retains unsent records',
    () async {
      final repo = DocumentRepositoryImpl(db: db, outbox: writer);
      final removed = await repo.add(
        userId: 'driver',
        vehicleId: 'assigned',
        draft: const DocumentDraft(
          name: 'Deleted on server',
          category: DocumentCategory.other,
        ),
      );
      await db.delete(db.outboxEntries).go();
      final pending = await repo.add(
        userId: 'driver',
        vehicleId: 'assigned',
        draft: const DocumentDraft(
          name: 'Not uploaded yet',
          category: DocumentCategory.other,
        ),
      );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path.endsWith('/reviews')
                    ? {'items': <Object>[]}
                    : {
                        'cursor': 'snapshot',
                        'bootstrap': true,
                        'assigned_vehicle_ids': ['assigned'],
                        'changes': <Object>[],
                      },
              ),
            );
          },
        ),
      );
      final page = await OrganizationSyncApi(dio, db, 'org', 'driver').pull('');
      final applier = ChangeApplier(db, authoritative: true);
      for (final change in page.changes) {
        await applier.apply(change, userId: 'driver');
      }
      expect(await repo.getById(removed.id), isNull);
      expect((await repo.getById(pending.id))?.name, 'Not uploaded yet');
      expect(await db.select(db.outboxEntries).get(), hasLength(1));
      dio.close();
    },
  );
}
