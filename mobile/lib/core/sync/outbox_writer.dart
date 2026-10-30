import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'outbox_models.dart';

/// Appends local writes for later push. Does not talk to the network.
class OutboxWriter {
  OutboxWriter(this._db);

  final AppDatabase _db;

  bool get derivesExpenses => false;

  Future<void> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required OutboxOp op,
    required Map<String, dynamic> payload,
  }) async {
    final conflict =
        await (_db.select(_db.outboxEntries)..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.entityType.equals(entityType) &
                  r.entityId.equals(entityId) &
                  r.parked.equals(true) &
                  r.errorCode.like('currency_%'),
            ))
            .get();
    if (conflict.isNotEmpty) {
      throw StateError(
        'Resolve the currency conflict before editing this record.',
      );
    }
    await _db
        .into(_db.outboxEntries)
        .insert(
          OutboxEntriesCompanion.insert(
            userId: userId,
            entityType: entityType,
            entityId: entityId,
            op: op.storage,
            payload: jsonEncode(payload),
            clientTs: DateTime.now().toUtc(),
          ),
        );
  }
}
