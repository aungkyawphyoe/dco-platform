import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../domain/pricing.dart';

class LocalPricingRepository implements PricingRepository {
  LocalPricingRepository(this._db, this._dio, this._userId);
  final AppDatabase _db;
  final Dio _dio;
  final String _userId;
  String _key(String name) => 'pricing:$_userId:$name';
  Future<void> _save(String name, Object value) => _db
      .into(_db.appMeta)
      .insert(
        AppMetaCompanion(
          key: drift.Value(_key(name)),
          value: drift.Value(jsonEncode(value)),
        ),
        mode: drift.InsertMode.insertOrReplace,
      )
      .then((_) {});
  Stream<Map<String, dynamic>?> _watch(String name) =>
      (_db.select(
        _db.appMeta,
      )..where((t) => t.key.equals(_key(name)))).watchSingleOrNull().map(
        (row) => row?.value == null
            ? null
            : jsonDecode(row!.value!) as Map<String, dynamic>,
      );

  @override
  Stream<List<PricingPlan>?> watchPlans() => _watch('plans').map(
    (json) => json == null
        ? null
        : (json['plans'] as List)
              .cast<Map<String, dynamic>>()
              .where((p) => p['audience'] == 'personal')
              .map(PricingPlan.fromJson)
              .toList(),
  );
  @override
  Stream<SubscriptionStatus?> watchSubscription() => _watch(
    'subscription',
  ).map((json) => json == null ? null : SubscriptionStatus.fromJson(json));
  @override
  Future<void> refresh() async {
    // Each successful response is persisted independently; cached plans survive
    // account endpoint outages and the UI only observes Drift.
    await Future.wait([
      _dio
          .get<Map<String, dynamic>>('/pricing')
          .then((r) => _save('plans', r.data!)),
      _dio
          .get<Map<String, dynamic>>('/me/subscription')
          .then((r) => _save('subscription', r.data!)),
    ]);
  }

  @override
  Future<GiftAccess> redeem(String code) async {
    final normalized = code.trim().toUpperCase();
    final hash = await Sha256().hash(utf8.encode(normalized));
    final key = 'request:${base64UrlEncode(hash.bytes)}';
    final row = await (_db.select(
      _db.appMeta,
    )..where((t) => t.key.equals(_key(key)))).getSingleOrNull();
    final requestId = row?.value == null
        ? const Uuid().v4()
        : jsonDecode(row!.value!) as String;
    // Persist before sending so a lost response/process restart can replay safely.
    await _save(key, requestId);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/me/gift-redemptions',
        data: {'code': normalized, 'request_id': requestId},
      );
      final giftJson = response.data!['gift'] as Map<String, dynamic>;
      final gift = GiftAccess.fromJson(giftJson);
      // A replay can refer to a grant that has since expired or been superseded
      // by an admin assignment. Refresh authoritative status separately.
      await refresh().catchError((_) {});
      return gift;
    } on DioException catch (e) {
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      throw RedemptionFailure(
        error is Map
            ? error['code'] as String? ?? 'unavailable'
            : 'unavailable',
      );
    }
  }
}
