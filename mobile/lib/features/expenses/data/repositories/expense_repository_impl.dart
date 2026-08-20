import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/entities/expense.dart';
import '../../domain/expense_failure.dart';
import '../../domain/expense_validators.dart';
import '../../domain/repositories/expense_repository.dart';
import '../mappers/expense_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({
    required AppDatabase db,
    required OutboxWriter outbox,
    SyncEngine syncEngine = const SyncEngine(),
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _outbox = outbox,
       _sync = syncEngine,
       _uuid = uuid;

  final AppDatabase _db;
  final OutboxWriter _outbox;
  final SyncEngine _sync;
  final Uuid _uuid;

  @override
  Stream<List<Expense>> watchForVehicle(String vehicleId) {
    final query = _db.select(_db.expenseRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.incurredOn),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.watch().asyncMap(_attachParts);
  }

  @override
  Stream<ExpenseSummary> watchSummary(String vehicleId, {DateTime? now}) {
    return watchForVehicle(vehicleId).map(
      (items) => ExpenseSummary.fromExpenses(items, now: now ?? DateTime.now()),
    );
  }

  @override
  Future<Expense?> getById(String id) async {
    final row = await (_db.select(_db.expenseRecords)..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final parts = await (_db.select(_db.expensePartRecords)..where((r) => r.expenseId.equals(id))).get();
    return expenseFromDrift(row, parts);
  }

  @override
  Future<Expense> add({
    required String userId,
    required String vehicleId,
    required ExpenseDraft draft,
  }) async {
    _assertDraft(draft);
    final now = DateTime.now().toUtc();
    final expense = _fromDraft(
      id: _uuid.v4(),
      vehicleId: vehicleId,
      draft: draft,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.expenseRecords).insert(expenseToCompanion(expense));
      await _insertParts(expense);
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.expense,
        entityId: expense.id,
        op: OutboxOp.upsert,
        payload: expense.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return expense;
  }

  @override
  Future<Expense> update({
    required String userId,
    required String expenseId,
    required ExpenseDraft draft,
  }) async {
    _assertDraft(draft);
    final existing = await getById(expenseId);
    if (existing == null) throw const ExpenseNotFoundFailure();

    final updated = _fromDraft(
      id: existing.id,
      vehicleId: existing.vehicleId,
      draft: draft,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    await _db.transaction(() async {
      await (_db.update(_db.expenseRecords)..where((row) => row.id.equals(expenseId))).write(
        expenseToCompanion(updated),
      );
      await (_db.delete(_db.expensePartRecords)..where((row) => row.expenseId.equals(expenseId))).go();
      await _insertParts(updated);
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.expense,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    if (existing.receiptLocalPath != null && existing.receiptLocalPath != updated.receiptLocalPath) {
      await _deleteLocalFile(existing.receiptLocalPath);
    }
    await _sync.requestSync();
    return updated;
  }

  @override
  Future<void> delete({
    required String userId,
    required String expenseId,
  }) async {
    final existing = await getById(expenseId);
    if (existing == null) throw const ExpenseNotFoundFailure();

    await _db.transaction(() async {
      await (_db.delete(_db.expensePartRecords)..where((row) => row.expenseId.equals(expenseId))).go();
      await (_db.delete(_db.expenseRecords)..where((row) => row.id.equals(expenseId))).go();
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.expense,
        entityId: expenseId,
        op: OutboxOp.delete,
        payload: {'id': expenseId},
      );
    });
    await _deleteLocalFile(existing.receiptLocalPath);
    await _sync.requestSync();
  }

  Expense _fromDraft({
    required String id,
    required String vehicleId,
    required ExpenseDraft draft,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final seen = <String>{};
    final parts = <ExpenseAssignedPart>[];
    for (final part in draft.parts) {
      if (!seen.add(part.partId)) {
        throw const ExpenseValidationFailure('The same part cannot be assigned twice');
      }
      parts.add(
        ExpenseAssignedPart(
          id: _uuid.v4(),
          partId: part.partId,
          name: part.name.trim(),
        ),
      );
    }

    return Expense(
      id: id,
      vehicleId: vehicleId,
      category: draft.category,
      amount: ExpenseValidators.money(draft.amount),
      incurredOn: DateTime(draft.incurredOn.year, draft.incurredOn.month, draft.incurredOn.day),
      notes: _emptyToNull(draft.notes),
      receiptLocalPath: _emptyToNull(draft.receiptLocalPath),
      receiptMediaId: _emptyToNull(draft.receiptMediaId),
      parts: parts,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  Future<void> _insertParts(Expense expense) async {
    for (final part in expense.parts) {
      await _db
          .into(_db.expensePartRecords)
          .insert(
            ExpensePartRecordsCompanion.insert(
              id: part.id,
              expenseId: expense.id,
              partId: part.partId,
              name: part.name,
            ),
          );
    }
  }

  Future<List<Expense>> _attachParts(List<ExpenseRecord> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList();
    final parts = await (_db.select(
      _db.expensePartRecords,
    )..where((row) => row.expenseId.isIn(ids))).get();
    final partsByExpense = <String, List<ExpensePartRecord>>{};
    for (final part in parts) {
      partsByExpense.putIfAbsent(part.expenseId, () => []).add(part);
    }
    return rows.map((row) => expenseFromDrift(row, partsByExpense[row.id] ?? const [])).toList();
  }

  void _assertDraft(ExpenseDraft draft) {
    final categoryError = ExpenseValidators.category(draft.category);
    if (categoryError != null) throw ExpenseValidationFailure(categoryError);
    if (draft.amount <= 0 || draft.amount > ExpenseValidators.maxAmount) {
      throw const ExpenseValidationFailure('Enter an amount greater than 0');
    }
    final dateError = ExpenseValidators.date(draft.incurredOn, now: DateTime.now());
    if (dateError != null) throw ExpenseValidationFailure(dateError);
    final notesError = ExpenseValidators.notes(draft.notes);
    if (notesError != null) throw ExpenseValidationFailure(notesError);
  }

  Future<void> _deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Local cleanup is best-effort; the row is already gone.
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
