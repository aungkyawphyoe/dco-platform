import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/maintenance/data/repositories/maintenance_catalog_repository_impl.dart';
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
  MaintenanceCatalogRepositoryImpl repo(String user) =>
      MaintenanceCatalogRepositoryImpl(db: db, dio: dio, userId: user);
  Map<String, Object> item(String key) => {'catalog_key': key, 'name': key};

  test('suggestions ignore legacy interval and fuel defaults', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'items': [
                  {
                    ...item('oil'),
                    'interval_days': 365,
                    'interval_distance': 15000,
                    'fuel_type': 'petrol',
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final repository = repo('owner');
    await repository.fetchAndCache('vehicle');
    final suggestion =
        (await repository.watchForVehicle('vehicle').first)!.single;
    expect(suggestion.name, 'oil');
    expect(suggestion.catalogKey, 'oil');
  });

  test(
    'catalogs are isolated by account and vehicle, including successful empty responses',
    () async {
      var items = [item('oil')];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, data: {'items': items}),
            );
          },
        ),
      );
      final a = repo('a'), b = repo('b');
      expect(await b.watchForVehicle('new').first, isNull);
      await a.fetchAndCache('car');
      items = [];
      await a.fetchAndCache('other');
      expect(await a.watchForVehicle('other').first, isEmpty);
      expect((await a.watchForVehicle('car').first)!.single.catalogKey, 'oil');
      expect(await b.watchForVehicle('car').first, isNull);
      items = [item('tires')];
      await b.fetchAndCache('new');
      expect(
        (await b.watchForVehicle('new').first)!.single.catalogKey,
        'tires',
      );
      expect((await a.watchForVehicle('car').first)!.single.catalogKey, 'oil');
    },
  );

  test(
    'new vehicle 404 is visible and a subsequent retry fills the cache',
    () async {
      var exists = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (!exists) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(requestOptions: options, statusCode: 404),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'items': [item('oil')],
                  },
                ),
              );
            }
          },
        ),
      );
      final r = repo('b');
      await expectLater(r.fetchAndCache('new'), throwsA(isA<DioException>()));
      expect(await r.watchForVehicle('new').first, isNull);
      exists = true;
      await r.fetchAndCache('new');
      expect((await r.watchForVehicle('new').first)!.single.catalogKey, 'oil');
      exists = false;
      await expectLater(r.fetchAndCache('new'), throwsA(isA<DioException>()));
      expect((await r.watchForVehicle('new').first)!.single.catalogKey, 'oil');
    },
  );

  test(
    'late responses cannot replace a newer response or another account cache',
    () async {
      final pending = <(RequestOptions, RequestInterceptorHandler)>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            pending.add((options, handler));
          },
        ),
      );
      final a = repo('a'), b = repo('b');
      final old = a.fetchAndCache('car');
      while (pending.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final newer = a.fetchAndCache('car');
      while (pending.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final other = b.fetchAndCache('car');
      while (pending.length < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      void resolve(int index, String key) => pending[index].$2.resolve(
        Response(
          requestOptions: pending[index].$1,
          data: {
            'items': [item(key)],
          },
        ),
      );
      resolve(1, 'new');
      await newer;
      resolve(2, 'other-account');
      await other;
      resolve(0, 'stale');
      await old;
      expect((await a.watchForVehicle('car').first)!.single.catalogKey, 'new');
      expect(
        (await b.watchForVehicle('car').first)!.single.catalogKey,
        'other-account',
      );
    },
  );
}
