import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppMeta,
    VehicleRecords,
    UserProfiles,
    OutboxEntries,
    PlanItemRecords,
    ServiceRecordRows,
    ServiceLineRecords,
    PartRecords,
    ServicePartRecords,
    FuelTypeRecords,
    FuelLogRecords,
    ExpenseRecords,
    ExpensePartRecords,
    NotificationRecords,
    VehicleShareRecords,
    VehicleShareInvitationRecords,
    DrivingLicenseRecords,
    DocumentRecords,
    MaintenanceCatalogRecords,
    NoteRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// The app intentionally keeps more than one database open at once: the
  /// personal `dco_owner` database plus one org-scoped database per driver
  /// account (`dco_org_<user>_<org>`, see `organizationDatabaseProvider`).
  /// Each instance passes its own executor — either an injected test
  /// executor or [driftDatabase] with a distinct name — so no two instances
  /// ever share a QueryExecutor. Drift's warning is keyed on the class, not
  /// the executor, so it would fire on every driver login; opt out here.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'dco_owner')) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  AppDatabase.scoped(String name) : super(driftDatabase(name: name)) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 25;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 25) {
        // Tables created by older upgrade branches already include new columns.
        if (from >= 2) {
          await migrator.addColumn(
            vehicleRecords,
            vehicleRecords.purchaseCurrency,
          );
          await migrator.addColumn(outboxEntries, outboxEntries.errorCode);
          await migrator.addColumn(outboxEntries, outboxEntries.errorDetails);
        }
        if (from >= 3) {
          await migrator.addColumn(
            serviceRecordRows,
            serviceRecordRows.currency,
          );
        }
        if (from >= 6) {
          await migrator.addColumn(fuelLogRecords, fuelLogRecords.currency);
        }
        if (from >= 7) {
          await migrator.addColumn(expenseRecords, expenseRecords.currency);
        }
        if (from >= 2) {
          // Legacy queued amounts were entered in MMK. Never change their digits.
          final queued = await customSelect(
            'SELECT id, entity_type, payload FROM outbox_entries',
          ).get();
          for (final row in queued) {
            final payload =
                jsonDecode(row.read<String>('payload')) as Map<String, dynamic>;
            final kind = row.read<String>('entity_type');
            final key = kind == 'vehicle' ? 'purchase_currency' : 'currency';
            if (['expense', 'fuel_log', 'service_record'].contains(kind) ||
                (kind == 'vehicle' && payload['purchase_price'] != null)) {
              payload.putIfAbsent(key, () => 'MMK');
              await customStatement(
                'UPDATE outbox_entries SET payload = ? WHERE id = ?',
                [jsonEncode(payload), row.read<int>('id')],
              );
            }
          }
        }
      }
      if (from >= 12 && from < 24) {
        await migrator.addColumn(documentRecords, documentRecords.linksJson);
      }
      if (from < 2) {
        await migrator.createTable(vehicleRecords);
        await migrator.createTable(userProfiles);
        await migrator.createTable(outboxEntries);
      }
      if (from < 3) {
        await migrator.createTable(planItemRecords);
        await migrator.createTable(serviceRecordRows);
        await migrator.createTable(serviceLineRecords);
      }
      if (from < 4) {
        await migrator.addColumn(userProfiles, userProfiles.language);
        await migrator.addColumn(userProfiles, userProfiles.currency);
        await migrator.addColumn(userProfiles, userProfiles.lengthUnit);
      }
      if (from < 5) {
        await migrator.createTable(partRecords);
        await migrator.createTable(servicePartRecords);
      }
      if (from < 6) {
        await migrator.createTable(fuelTypeRecords);
        await migrator.createTable(fuelLogRecords);
      }
      if (from < 7) {
        await migrator.createTable(expenseRecords);
        await migrator.createTable(expensePartRecords);
      }
      if (from < 8) {
        await migrator.createTable(notificationRecords);
      }
      if (from < 9) {
        await migrator.addColumn(
          notificationRecords,
          notificationRecords.cycleKey,
        );
      }
      if (from < 10) {
        await migrator.createTable(drivingLicenseRecords);
      }
      if (from < 11) {
        await migrator.addColumn(vehicleRecords, vehicleRecords.source);
        await migrator.addColumn(vehicleRecords, vehicleRecords.permission);
      }
      if (from < 12) {
        await migrator.createTable(documentRecords);
      }
      if (from < 13) {
        await migrator.createTable(maintenanceCatalogRecords);
      }
      if (from < 14) {
        await migrator.createTable(noteRecords);
      }
      if (from < 15) {
        await migrator.addColumn(userProfiles, userProfiles.soonDays);
        await migrator.addColumn(userProfiles, userProfiles.soonDistanceKm);
      }
      if (from < 16) {
        await migrator.addColumn(fuelLogRecords, fuelLogRecords.odometer);
      }
      if (from < 17) {
        await migrator.addColumn(userProfiles, userProfiles.themeMode);
      }
      if (from < 18) {
        await migrator.addColumn(documentRecords, documentRecords.expiresOn);
      }
      if (from < 19) {
        // Vehicle sharing replaces family sharing: drop the family tables and
        // create the per-vehicle share tables. Existing shares are re-created
        // server-side and arrive through sync.
        await migrator.deleteTable('families');
        await migrator.deleteTable('family_memberships');
        await migrator.deleteTable('vehicle_grants');
        await migrator.deleteTable('family_vehicles');
        await migrator.createTable(vehicleShareRecords);
        await migrator.createTable(vehicleShareInvitationRecords);
      }
      if (from < 20) {
        // Audit trail: add created_by to maintenance, expenses, parts, plan items
        await migrator.addColumn(planItemRecords, planItemRecords.createdBy);
        await migrator.addColumn(
          serviceRecordRows,
          serviceRecordRows.createdBy,
        );
        await migrator.addColumn(partRecords, partRecords.createdBy);
        await migrator.addColumn(expenseRecords, expenseRecords.createdBy);
      }
      if (from < 21) {
        // Sharing: track who created each document so sharees only edit their own.
        await migrator.addColumn(documentRecords, documentRecords.createdBy);
      }
      if (from >= 6 && from < 23) {
        await migrator.addColumn(fuelLogRecords, fuelLogRecords.fillStatus);
      }
      if (from < 22) {
        // Gating: outbox rows parked by a LIMIT_EXCEEDED rejection (§9).
        await migrator.addColumn(outboxEntries, outboxEntries.parked);
      }
    },
  );
}

class AppMeta extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text().nullable()();
}
