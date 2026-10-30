import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../sync/change_applier.dart';
import '../sync/sync_api.dart';
import 'currency_store.dart';

/// Explicit recovery of a rejected monetary create. Ordinary retry never calls
/// this operation. The caller supplies newly entered amounts after online review.
class CurrencyConflictRepository {
  CurrencyConflictRepository(this.db, this.userId, this.refreshScope);
  final AppDatabase db;
  final String userId;
  final Future<Map<String, dynamic>> Function(String? vehicleId) refreshScope;

  Future<void> resolve({
    required int outboxId,
    required String currency,
    required double amount,
    List<double?>? lineCosts,
    int? reviewedThroughId,
  }) async {
    final original =
        await (db.select(db.outboxEntries)
              ..where((r) => r.id.equals(outboxId) & r.userId.equals(userId)))
            .getSingle();
    if (!original.parked ||
        !const [
          'currency_mismatch',
          'currency_required',
        ].contains(original.errorCode)) {
      throw StateError(
        'This operation is not a recoverable currency mismatch.',
      );
    }
    final before = jsonDecode(original.payload) as Map<String, dynamic>;
    final vehicleId = before['vehicle_id'] as String?;
    final state = await refreshScope(
      original.entityType == 'vehicle' ? null : vehicleId,
    );
    if (state['currency'] != currency ||
        state['enabled'] != true ||
        state['review_required'] == true) {
      throw StateError(
        'Currency changed. Review the current currency and re-enter the amount.',
      );
    }
    void validate(double value) {
      if (!operationalCurrencies.contains(currency) ||
          !value.isFinite ||
          value < 0 ||
          value > 9999999999.99 ||
          (currency == 'MMK'
              ? value != value.roundToDouble()
              : double.parse(value.toStringAsFixed(2)) != value)) {
        throw StateError('Invalid amount precision for $currency.');
      }
    }

    validate(amount);
    await db.transaction(() async {
      final current =
          await (db.select(db.outboxEntries)
                ..where((r) => r.id.equals(outboxId) & r.userId.equals(userId)))
              .getSingle();
      if (current.payload != original.payload ||
          current.errorCode != original.errorCode ||
          !current.parked) {
        throw StateError('Draft changed. Review it again.');
      }
      final siblings =
          await (db.select(db.outboxEntries)
                ..where(
                  (r) =>
                      r.userId.equals(userId) &
                      r.entityType.equals(original.entityType) &
                      r.entityId.equals(original.entityId),
                )
                ..orderBy([(r) => OrderingTerm.asc(r.id)]))
              .get();
      // Do not implicitly discard a queued edit or delete that was not reviewed.
      if (siblings.length != 1 && reviewedThroughId != siblings.last.id) {
        throw StateError(
          'Review the latest queued draft before currency recovery.',
        );
      }
      if (siblings.last.op != 'upsert') {
        throw StateError(
          'The draft has been deleted locally. Review that deletion instead.',
        );
      }
      final payload = {
        ...jsonDecode(siblings.last.payload) as Map<String, dynamic>,
      };
      if (before.containsKey('_expected_revision')) {
        payload['_expected_revision'] = before['_expected_revision'];
      }
      final amountKey = switch (original.entityType) {
        'expense' => 'amount',
        'fuel_log' => 'cost',
        'service_record' => 'total_cost',
        'vehicle' => 'purchase_price',
        _ => throw StateError('Unsupported monetary operation'),
      };
      payload[amountKey] = amount;
      payload[original.entityType == 'vehicle'
              ? 'purchase_currency'
              : 'currency'] =
          currency;
      if (original.entityType == 'service_record') {
        final items = (payload['items'] as List).cast<Map<String, dynamic>>();
        if (lineCosts == null || lineCosts.length != items.length) {
          throw StateError('Re-enter each service line cost.');
        }
        payload['items'] = [
          for (var i = 0; i < items.length; i++)
            {...items[i], 'line_cost': lineCosts[i]},
        ];
        for (final cost in lineCosts.whereType<double>()) {
          validate(cost);
        }
      }
      if (payload.containsKey('_operation_id')) {
        payload['_operation_id'] = const Uuid().v4();
      }
      final now = DateTime.now().toUtc();
      await (db.update(
        db.outboxEntries,
      )..where((r) => r.id.equals(outboxId))).write(
        OutboxEntriesCompanion(
          payload: Value(jsonEncode(payload)),
          clientTs: Value(now),
          attemptCount: const Value(0),
          parked: const Value(false),
          errorCode: const Value(null),
          errorDetails: const Value(null),
          lastError: const Value(null),
        ),
      );
      await (db.delete(db.outboxEntries)..where(
            (r) => r.id.isIn(
              siblings.where((r) => r.id != outboxId).map((r) => r.id).toList(),
            ),
          ))
          .go();
      await ChangeApplier(db, authoritative: true).apply(
        SyncChange(
          entityType: original.entityType,
          entityId: original.entityId,
          op: SyncChangeOp.upsert,
          payload: payload,
          serverTs: now,
        ),
        userId: userId,
      );
      // Update linked optimistic expenses as part of the same reviewed event.
      final pending = await (db.select(
        db.outboxEntries,
      )..where((r) => r.userId.equals(userId))).get();
      for (final entry in pending) {
        final child = jsonDecode(entry.payload) as Map<String, dynamic>;
        if (child['_currency_parent_id'] != original.entityId) continue;
        child['amount'] = amount;
        child['currency'] = currency;
        await (db.update(db.outboxEntries)..where((r) => r.id.equals(entry.id)))
            .write(OutboxEntriesCompanion(payload: Value(jsonEncode(child))));
        await (db.update(
          db.expenseRecords,
        )..where((r) => r.id.equals(entry.entityId))).write(
          ExpenseRecordsCompanion(
            amount: Value(amount),
            currency: Value(currency),
          ),
        );
      }
      // Org-derived local expense uses source id until the server assigns its id.
      final mapped =
          await (db.select(db.appMeta)..where(
                (r) => r.key.equals(
                  'org_expense_source:${original.entityType}:${original.entityId}',
                ),
              ))
              .getSingleOrNull();
      final expenseId = mapped?.value == null
          ? original.entityId
          : jsonDecode(mapped!.value!) as String;
      if (original.entityType == 'service_record' ||
          original.entityType == 'fuel_log') {
        await (db.update(
          db.expenseRecords,
        )..where((r) => r.id.equals(expenseId))).write(
          ExpenseRecordsCompanion(
            amount: Value(amount),
            currency: Value(currency),
          ),
        );
      }
      await CurrencyStore(db).save(
        userId,
        state,
        vehicleId: original.entityType == 'vehicle' ? null : vehicleId,
      );
    });
  }
}
