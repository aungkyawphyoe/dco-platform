import 'dart:convert';

import '../database/app_database.dart';
import 'outbox_models.dart';

/// Appends local writes for later push. Does not talk to the network.
class OutboxWriter {
  OutboxWriter(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required OutboxOp op,
    required Map<String, dynamic> payload,
  }) {
    return _db
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
