import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/outbox_models.dart';
import '../../../../core/sync/outbox_writer.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/entities/part.dart';
import '../../domain/part_failure.dart';
import '../../domain/part_validators.dart';
import '../../domain/repositories/parts_repository.dart';
import '../mappers/part_mapper.dart';

// Private fields with public constructor names.
// ignore_for_file: prefer_initializing_formals

class PartsRepositoryImpl implements PartsRepository {
  PartsRepositoryImpl({
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
  Stream<List<Part>> watchForVehicle(String vehicleId) {
    final query = _db.select(_db.partRecords)
      ..where((row) => row.vehicleId.equals(vehicleId))
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map((rows) => rows.map(partFromDrift).toList());
  }

  @override
  Future<Part?> getById(String id) async {
    final row = await (_db.select(_db.partRecords)..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : partFromDrift(row);
  }

  @override
  Future<Part> add({
    required String userId,
    required String vehicleId,
    required PartDraft draft,
  }) async {
    _assertDraft(draft);
    await _assertUniqueName(vehicleId: vehicleId, name: draft.name);

    final now = DateTime.now().toUtc();
    final part = Part(
      id: _uuid.v4(),
      userId: userId,
      vehicleId: vehicleId,
      name: draft.name.trim(),
      brand: _emptyToNull(draft.brand),
      partNumber: _emptyToNull(draft.partNumber),
      notes: _emptyToNull(draft.notes),
      updatedAt: now,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.partRecords).insert(partToCompanion(part));
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.part,
        entityId: part.id,
        op: OutboxOp.upsert,
        payload: part.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return part;
  }

  @override
  Future<Part> update({
    required String userId,
    required String partId,
    required PartDraft draft,
  }) async {
    _assertDraft(draft);
    final existing = await getById(partId);
    if (existing == null || existing.userId != userId) {
      throw const PartNotFoundFailure();
    }
    await _assertUniqueName(vehicleId: existing.vehicleId, name: draft.name, excludingId: partId);

    final updated = Part(
      id: existing.id,
      userId: existing.userId,
      vehicleId: existing.vehicleId,
      name: draft.name.trim(),
      brand: _emptyToNull(draft.brand),
      partNumber: _emptyToNull(draft.partNumber),
      notes: _emptyToNull(draft.notes),
      updatedAt: DateTime.now().toUtc(),
      createdAt: existing.createdAt,
    );

    await _db.transaction(() async {
      await (_db.update(_db.partRecords)..where((row) => row.id.equals(partId))).write(
        partToCompanion(updated),
      );
      await _outbox.enqueue(
        userId: userId,
        entityType: OutboxEntityType.part,
        entityId: updated.id,
        op: OutboxOp.upsert,
        payload: updated.toWriteJson(),
      );
    });
    await _sync.requestSync();
    return updated;
  }

  void _assertDraft(PartDraft draft) {
    final nameError = PartValidators.name(draft.name);
    if (nameError != null) throw PartValidationFailure(nameError);
    final brandError = PartValidators.brand(draft.brand ?? '');
    if (brandError != null) throw PartValidationFailure(brandError);
    final numberError = PartValidators.partNumber(draft.partNumber ?? '');
    if (numberError != null) throw PartValidationFailure(numberError);
    final notesError = PartValidators.notes(draft.notes ?? '');
    if (notesError != null) throw PartValidationFailure(notesError);
  }

  Future<void> _assertUniqueName({
    required String vehicleId,
    required String name,
    String? excludingId,
  }) async {
    final normalized = name.trim().toLowerCase();
    final query = _db.select(_db.partRecords)
      ..where((row) => row.vehicleId.equals(vehicleId));
    final rows = await query.get();
    final clash = rows.any(
      (row) => row.name.trim().toLowerCase() == normalized && row.id != excludingId,
    );
    if (clash) throw const DuplicatePartNameFailure();
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
