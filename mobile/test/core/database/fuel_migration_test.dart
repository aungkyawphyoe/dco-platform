import 'dart:convert';
import 'dart:io';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v29 fuel migration preserves IDs, history, and pending payloads',
    () async {
      final directory = await Directory.systemTemp.createTemp('fuel-migration');
      final file = File('${directory.path}/app.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      try {
        for (final name in ['Petrol', 'Electricity']) {
          await db
              .into(db.fuelTypeRecords)
              .insert(
                FuelTypeRecordsCompanion.insert(
                  id: name,
                  userId: 'user',
                  name: name,
                  kind: name == 'Petrol' ? 'liquid' : 'electric',
                  unit: name == 'Petrol' ? 'L' : 'kWh',
                  updatedAt: DateTime(2026),
                  createdAt: DateTime(2026),
                ),
              );
          await db
              .into(db.fuelLogRecords)
              .insert(
                FuelLogRecordsCompanion.insert(
                  id: 'log-$name',
                  userId: 'user',
                  vehicleId: 'vehicle',
                  kind: name == 'Petrol' ? 'refuel' : 'charge',
                  fuelTypeId: name,
                  fuelTypeName: name,
                  unit: 'L',
                  loggedOn: DateTime(2026),
                  amount: 10,
                  cost: 7500,
                  updatedAt: DateTime(2026),
                  createdAt: DateTime(2026),
                ),
              );
          await db
              .into(db.outboxEntries)
              .insert(
                OutboxEntriesCompanion.insert(
                  userId: 'user',
                  entityType: 'fuel_log',
                  entityId: 'log-$name',
                  op: 'upsert',
                  payload: jsonEncode({
                    'fuel_type_id': name,
                    'fuel_type_name': name,
                    'cost': 7500,
                  }),
                  clientTs: DateTime(2026),
                ),
              );
        }
        await db.customStatement(
          'ALTER TABLE fuel_logs DROP COLUMN battery_level',
        );
        await db.customStatement(
          'ALTER TABLE fuel_logs DROP COLUMN battery_level_before',
        );
        await db.customStatement('PRAGMA user_version=29');
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        final types = await db.select(db.fuelTypeRecords).get();
        expect(types.map((t) => t.id), containsAll(['Petrol', 'Electricity']));
        expect(
          types.map((t) => t.name),
          containsAll(['95 Octane gasoline (petrol)', 'Electric (Fast)']),
        );
        final logs = await db.select(db.fuelLogRecords).get();
        expect(
          logs.every(
            (log) =>
                log.cost == 7500 &&
                log.batteryLevel == null &&
                log.batteryLevelBefore == null &&
                log.odometer == null,
          ),
          isTrue,
        );
        expect(
          logs.map((log) => log.fuelTypeName),
          containsAll(types.map((t) => t.name)),
        );
        final pending = await db.select(db.outboxEntries).get();
        expect(
          pending.map((row) => jsonDecode(row.payload)['fuel_type_name']),
          containsAll(types.map((t) => t.name)),
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
