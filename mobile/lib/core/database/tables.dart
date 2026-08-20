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
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get lengthUnit => text().withDefault(const Constant('mi'))();

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

class PlanItemRecords extends Table {
  @override
  String get tableName => 'plan_items';

  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get name => text()();
  IntColumn get intervalDays => integer().nullable()();
  RealColumn get intervalDistance => real().nullable()();
  RealColumn get nextDueMileage => real().nullable()();
  DateTimeColumn get nextDueOn => dateTime().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  TextColumn get catalogKey => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ServiceRecordRows extends Table {
  @override
  String get tableName => 'service_records';

  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get title => text()();
  DateTimeColumn get servicedOn => dateTime()();
  RealColumn get odometer => real()();
  RealColumn get totalCost => real()();
  TextColumn get workshopName => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptLocalPath => text().nullable()();
  TextColumn get receiptMediaId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ServiceLineRecords extends Table {
  @override
  String get tableName => 'service_record_items';

  TextColumn get id => text()();
  TextColumn get serviceRecordId => text()();
  TextColumn get planItemId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get lineCost => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PartRecords extends Table {
  @override
  String get tableName => 'parts';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get vehicleId => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get partNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ServicePartRecords extends Table {
  @override
  String get tableName => 'service_record_parts';

  TextColumn get id => text()();
  TextColumn get serviceRecordId => text()();
  TextColumn get partId => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FuelTypeRecords extends Table {
  @override
  String get tableName => 'fuel_types';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get unit => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FuelLogRecords extends Table {
  @override
  String get tableName => 'fuel_logs';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get vehicleId => text()();
  TextColumn get kind => text()();
  TextColumn get fuelTypeId => text()();
  TextColumn get fuelTypeName => text()();
  TextColumn get unit => text()();
  DateTimeColumn get loggedOn => dateTime()();
  RealColumn get amount => real()();
  RealColumn get cost => real()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ExpenseRecords extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  DateTimeColumn get incurredOn => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptLocalPath => text().nullable()();
  TextColumn get receiptMediaId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ExpensePartRecords extends Table {
  @override
  String get tableName => 'expense_parts';

  TextColumn get id => text()();
  TextColumn get expenseId => text()();
  TextColumn get partId => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
