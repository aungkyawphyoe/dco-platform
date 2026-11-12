import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/change_applier.dart';
import 'package:dco_mobile/core/sync/sync_api.dart';
import 'package:dco_mobile/features/handover/data/repositories/handover_repository_impl.dart';
import 'package:dco_mobile/features/maintenance/data/mappers/maintenance_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ChangeApplier applier;
  late HandoverRepositoryImpl handovers;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = ChangeApplier(db);
    handovers = HandoverRepositoryImpl(db);
  });

  tearDown(() => db.close());

  SyncChange change(
    String type,
    String id,
    Map<String, dynamic> payload,
    String serverTs,
  ) {
    return SyncChange(
      entityType: type,
      entityId: id,
      op: SyncChangeOp.upsert,
      payload: payload,
      serverTs: DateTime.parse(serverTs),
    );
  }

  const vehicleId = 'v-handover';
  const buyerId = 'u-buyer';

  Map<String, dynamic> vehiclePayload() => {
    'id': vehicleId,
    'user_id': buyerId,
    'name': 'Handed over car',
    'make': 'Honda',
    'model': 'Civic',
    'year': 2023,
    'license_plate': 'HND001',
    'vin': null,
    'color': null,
    'fuel_type': 'petrol',
    'mileage': 43000.0,
    'mileage_unit': 'mi',
    'purchase_date': null,
    'purchase_price': null,
    'photo_media_id': null,
    'archived': false,
    'archived_at': null,
    'updated_at': '2026-11-10T10:00:00.000Z',
  };

  Map<String, dynamic> planPayload({required bool initialServiceRequired}) => {
    'id': 'p-initial',
    'vehicle_id': vehicleId,
    'name': 'Oil change',
    'interval_days': 365,
    'time_count': 1,
    'time_unit': 'years',
    'interval_distance': 10000,
    'initial_service_required': initialServiceRequired,
    'enabled': true,
    'updated_at': '2026-11-10T10:00:00.000Z',
  };

  Map<String, dynamic> warrantyPayload({String name = 'One year'}) => {
    'id': 'w-1',
    'vehicle_id': vehicleId,
    'sale_date': '2026-11-10',
    'sale_mileage_km': 43000,
    'status': 'active',
    'terms': {
      'template_id': 't-1',
      'name': name,
      'duration_years': 1,
      'mileage_limit_km': 20000,
      'coverage_categories': ['engine', 'transmission'],
      'exclusions': 'Wear items',
      'approved_workshops': [
        {'id': 'partner-1', 'name': 'Approved Garage'},
      ],
      'captured_at': '2026-11-10T10:00:00.000Z',
    },
  };

  Map<String, dynamic> receiptPayload() => {
    'id': 'h-1',
    'handover_id': 'h-1',
    'status': 'completed',
    'vehicle_id': vehicleId,
    'buyer_user_id': buyerId,
    'transferred_vehicle_id': 'tv-1',
    'sale_date': '2026-11-10',
    'current_mileage_km': 43000,
    'plan_item_ids': ['p-initial'],
    'warranty_instance_id': 'w-1',
    'completed_at': '2026-11-10T10:05:00.000Z',
  };

  test(
    'first handover pull stores vehicle, plan, warranty and receipt',
    () async {
      final changes = [
        change(
          'vehicle',
          vehicleId,
          vehiclePayload(),
          '2026-11-10T10:00:00.000Z',
        ),
        change(
          'plan_item',
          'p-initial',
          planPayload(initialServiceRequired: true),
          '2026-11-10T10:00:00.000Z',
        ),
        change(
          'warranty',
          'w-1',
          warrantyPayload(),
          '2026-11-10T10:00:00.000Z',
        ),
        change(
          'handover_receipt',
          'h-1',
          receiptPayload(),
          '2026-11-10T10:05:00.000Z',
        ),
      ];
      for (final entry in changes) {
        await applier.apply(entry, userId: buyerId);
      }

      final vehicle = await (db.select(
        db.vehicleRecords,
      )..where((row) => row.id.equals(vehicleId))).getSingle();
      expect(vehicle.userId, buyerId);
      expect(vehicle.transferLimitExempt, false);

      final planRow = await (db.select(
        db.planItemRecords,
      )..where((row) => row.id.equals('p-initial'))).getSingle();
      final plan = planItemFromDrift(planRow);
      expect(plan.initialServiceRequired, true);
      expect(plan.nextDueOn, isNull);
      expect(plan.nextDueMileage, isNull);

      final warranty = await handovers.getWarranty(vehicleId);
      expect(warranty, isNotNull);
      expect(warranty!.name, 'One year');
      expect(warranty.durationYears, 1);
      expect(warranty.mileageLimitKm, 20000);
      expect(warranty.coverageCategories, ['engine', 'transmission']);
      expect(warranty.exclusions, 'Wear items');
      expect(warranty.approvedWorkshops.single.name, 'Approved Garage');

      final receipt = await handovers.getReceipt(vehicleId);
      expect(receipt, isNotNull);
      expect(receipt!.id, 'h-1');
      expect(receipt.buyerUserId, buyerId);
      expect(receipt.planItemIds, ['p-initial']);
      expect(receipt.warrantyInstanceId, 'w-1');
      expect(receipt.currentMileageKm, 43000);
    },
  );

  test(
    'incremental pull clears initial service and updates warranty terms',
    () async {
      await applier.apply(
        change(
          'plan_item',
          'p-initial',
          planPayload(initialServiceRequired: true),
          '2026-11-10T10:00:00.000Z',
        ),
        userId: buyerId,
      );
      await applier.apply(
        change(
          'warranty',
          'w-1',
          warrantyPayload(),
          '2026-11-10T10:00:00.000Z',
        ),
        userId: buyerId,
      );

      await applier.apply(
        change(
          'plan_item',
          'p-initial',
          planPayload(initialServiceRequired: false),
          '2026-11-12T09:00:00.000Z',
        ),
        userId: buyerId,
      );
      await applier.apply(
        change(
          'warranty',
          'w-1',
          warrantyPayload(name: 'Extended'),
          '2026-11-12T09:00:00.000Z',
        ),
        userId: buyerId,
      );

      final planRow = await (db.select(
        db.planItemRecords,
      )..where((row) => row.id.equals('p-initial'))).getSingle();
      expect(planItemFromDrift(planRow).initialServiceRequired, false);
      expect((await handovers.getWarranty(vehicleId))!.name, 'Extended');
    },
  );

  test('stale handover changes do not overwrite newer local rows', () async {
    await applier.apply(
      change(
        'warranty',
        'w-1',
        warrantyPayload(name: 'Extended'),
        '2026-11-12T09:00:00.000Z',
      ),
      userId: buyerId,
    );
    await applier.apply(
      change('warranty', 'w-1', warrantyPayload(), '2026-11-10T10:00:00.000Z'),
      userId: buyerId,
    );
    expect((await handovers.getWarranty(vehicleId))!.name, 'Extended');
  });
}
