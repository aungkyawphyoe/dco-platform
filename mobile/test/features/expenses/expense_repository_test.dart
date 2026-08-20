import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/sync/outbox_writer.dart';
import 'package:dco_mobile/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/domain/expense_failure.dart';
import 'package:dco_mobile/features/garage/data/repositories/vehicle_repository_impl.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/features/parts/data/repositories/parts_repository_impl.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleDraft _vehicleDraft() {
  return const VehicleDraft(
    name: 'Daily',
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    licensePlate: 'ABC123',
    fuelType: FuelType.petrol,
    mileage: 10000,
  );
}

ExpenseDraft _draft({
  ExpenseCategory category = ExpenseCategory.parking,
  double amount = 12.5,
  DateTime? incurredOn,
  String? notes,
  List<ExpenseAssignedPartDraft> parts = const [],
}) {
  return ExpenseDraft(
    category: category,
    amount: amount,
    incurredOn: incurredOn ?? DateTime(2026, 8, 20),
    notes: notes,
    parts: parts,
  );
}

void main() {
  late AppDatabase db;
  late VehicleRepositoryImpl vehicles;
  late PartsRepositoryImpl parts;
  late ExpenseRepositoryImpl expenses;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db);
    vehicles = VehicleRepositoryImpl(db: db, outbox: outbox);
    parts = PartsRepositoryImpl(db: db, outbox: outbox);
    expenses = ExpenseRepositoryImpl(db: db, outbox: outbox);
  });

  tearDown(() => db.close());

  test('add writes an expense and queues outbox', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final expense = await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(notes: 'Airport parking'),
    );

    expect(expense.category, ExpenseCategory.parking);
    expect(expense.amount, 12.5);
    expect(expense.notes, 'Airport parking');
    expect(expense.incurredOn, DateTime(2026, 8, 20));

    final queued = await db.select(db.outboxEntries).get();
    expect(queued.any((row) => row.entityType == 'expense' && row.entityId == expense.id && row.op == 'upsert'), isTrue);
  });

  test('this month vs total uses the device-local calendar month', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(amount: 40, incurredOn: DateTime(2026, 7, 31), category: ExpenseCategory.fuel),
    );
    await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(amount: 10, incurredOn: DateTime(2026, 8, 1), category: ExpenseCategory.tolls),
    );

    final summary = await expenses.watchSummary(vehicle.id, now: DateTime(2026, 8, 20)).first;
    expect(summary.thisMonth, 10);
    expect(summary.total, 50);
    expect(summary.byCategory.map((slice) => slice.category), containsAll([ExpenseCategory.fuel, ExpenseCategory.tolls]));
    expect(summary.byCategory.firstWhere((slice) => slice.category == ExpenseCategory.fuel).percent, 80);
    expect(summary.byCategory.firstWhere((slice) => slice.category == ExpenseCategory.tolls).percent, 20);
  });

  test('list is newest first and can be filtered by category', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(amount: 5, incurredOn: DateTime(2026, 8, 1), category: ExpenseCategory.fuel),
    );
    await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(amount: 9, incurredOn: DateTime(2026, 8, 10), category: ExpenseCategory.parking),
    );

    final items = await expenses.watchForVehicle(vehicle.id).first;
    expect(items.map((item) => item.amount).toList(), [9, 5]);
    expect(items.where((item) => item.category == ExpenseCategory.fuel), hasLength(1));
  });

  test('assigned part name is snapshotted', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final part = await parts.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: const PartDraft(name: 'Cabin filter'),
    );
    final expense = await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(
        category: ExpenseCategory.parts,
        parts: [ExpenseAssignedPartDraft(partId: part.id, name: part.name)],
      ),
    );

    await parts.update(
      userId: 'user-1',
      partId: part.id,
      draft: const PartDraft(name: 'Cabin filter XL'),
    );

    final stored = await expenses.getById(expense.id);
    expect(stored!.parts, hasLength(1));
    expect(stored.parts.single.partId, part.id);
    expect(stored.parts.single.name, 'Cabin filter');
  });

  test('update changes amount and date and keeps identity', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final expense = await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(amount: 20, incurredOn: DateTime(2026, 8, 1)),
    );

    final updated = await expenses.update(
      userId: 'user-1',
      expenseId: expense.id,
      draft: _draft(amount: 24.5, incurredOn: DateTime(2026, 8, 2), category: ExpenseCategory.insurance),
    );

    expect(updated.id, expense.id);
    expect(updated.amount, 24.5);
    expect(updated.incurredOn, DateTime(2026, 8, 2));
    expect(updated.category, ExpenseCategory.insurance);
  });

  test('delete removes the row and queues a remote delete', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    final expense = await expenses.add(
      userId: 'user-1',
      vehicleId: vehicle.id,
      draft: _draft(),
    );

    await expenses.delete(userId: 'user-1', expenseId: expense.id);

    expect(await expenses.getById(expense.id), isNull);
    final remaining = await expenses.watchForVehicle(vehicle.id).first;
    expect(remaining, isEmpty);

    final queued = await db.select(db.outboxEntries).get();
    expect(
      queued.any((row) => row.entityType == 'expense' && row.entityId == expense.id && row.op == 'delete'),
      isTrue,
    );
  });

  test('future date more than one day ahead is rejected', () async {
    final vehicle = await vehicles.add(userId: 'user-1', draft: _vehicleDraft());
    expect(
      () => expenses.add(
        userId: 'user-1',
        vehicleId: vehicle.id,
        draft: _draft(incurredOn: DateTime.now().add(const Duration(days: 2))),
      ),
      throwsA(isA<ExpenseValidationFailure>()),
    );
  });
}
