import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/pricing/data/pricing_repository.dart';
import 'package:dco_mobile/features/pricing/domain/pricing.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio();
  });
  tearDown(() async {
    dio.close();
    await db.close();
  });
  final pricing = {
    'plans': [
      {
        'id': 'lite',
        'name': 'Lite',
        'audience': 'personal',
        'prices': {
          'monthly': {'mmk': 3000},
          'annual': {'mmk': 30000},
        },
        'limits': {'vehicles': 3, 'sharing': 3, 'storage_bytes': 157286400},
      },
      {'id': 'fleet', 'audience': 'fleet'},
    ],
  };
  test(
    'plans are read from account-scoped Drift and remain available offline',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path == '/pricing'
                    ? pricing
                    : {'plan': 'free', 'gift': null},
              ),
            );
          },
        ),
      );
      final repo = LocalPricingRepository(db, dio, 'one');
      expect(await repo.watchPlans().first, isNull);
      await repo.refresh();
      await repo.refresh();
      expect((await repo.watchPlans().first)!.single.id, 'lite');
      expect(
        await LocalPricingRepository(db, dio, 'two').watchPlans().first,
        isNull,
      );
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(DioException(requestOptions: o)),
        ),
      );
      await expectLater(repo.refresh(), throwsA(isA<DioException>()));
      expect((await repo.watchPlans().first)!.single.monthly, 3000);
    },
  );
  test(
    'lost responses reuse a durable request id without storing plaintext codes',
    () async {
      final requestIds = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/me/gift-redemptions') {
              requestIds.add(o.data['request_id'] as String);
              expect(o.data['code'], 'LAUNCH2026');
            }
            h.reject(DioException(requestOptions: o));
          },
        ),
      );
      await expectLater(
        LocalPricingRepository(db, dio, 'one').redeem(' launch2026 '),
        throwsA(isA<RedemptionFailure>()),
      );
      await expectLater(
        LocalPricingRepository(db, dio, 'one').redeem('LAUNCH2026'),
        throwsA(isA<RedemptionFailure>()),
      );
      expect(requestIds[0], requestIds[1]);
      final rows = await db.select(db.appMeta).get();
      expect(
        rows.map((r) => '${r.key}${r.value}').join(),
        isNot(contains('LAUNCH2026')),
      );
    },
  );
}
