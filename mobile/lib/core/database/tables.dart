import 'package:drift/drift.dart';

class VehicleRecords extends Table {
  @override
  String get tableName => 'vehicles';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get nickname => text().nullable()();
  TextColumn get make => text()();
  TextColumn get model => text()();
  IntColumn get year => integer()();
  TextColumn get licensePlate => text()();
  TextColumn get vin => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get fuelType => text()();
  RealColumn get mileage => real()();
  TextColumn get mileageUnit => text().withDefault(const Constant('mi'))();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoMediaId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class UserProfiles extends Table {
  TextColumn get userId => text()();
  TextColumn get activeVehicleId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get op => text()();
  TextColumn get payload => text()();
  DateTimeColumn get clientTs => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
