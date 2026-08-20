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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'dco_owner'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
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
    },
  );
}

class AppMeta extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text().nullable()();
}
