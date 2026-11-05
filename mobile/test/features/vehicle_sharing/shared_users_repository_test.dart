import 'dart:convert';
import 'dart:typed_data';
import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/features/vehicle_sharing/data/repositories/shared_users_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class SharingApi implements HttpClientAdapter {
  bool offline = false;
  int? limit = 3;
  final requested = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requested.add(options.path);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    Object body;
    if (options.path == '/vehicles') {
      expect(options.queryParameters['include_archived'], true);
      body = {
        'items': [
          {'id': 'one'},
          {'id': 'two'},
        ],
      };
    } else if (options.path == '/me/entitlements') {
      body = {
        'vehicle_sharing': {
          'active_shares': 2,
          'limits': {'total': limit},
        },
      };
    } else {
      final id = options.path.split('/')[2];
      body = {
        'vehicle': {'id': id, 'name': id, 'license_plate': id},
        'shares': [
          {
            'id': '$id-active',
            'user_id': 'same-person',
            'status': 'active',
            'display_name': 'Alex',
          },
          {
            'id': '$id-pending',
            'user_id': 'pending-person',
            'status': 'pending',
          },
          {
            'id': '$id-revoked',
            'user_id': 'revoked-person',
            'status': 'revoked',
          },
        ],
        'pending_invites': [
          {'id': 'invite-$id', 'invited_email': 'pending@example.com'},
        ],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late SharingApi api;
  late SharedUsersRepositoryImpl repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = SharingApi();
    repo = SharedUsersRepositoryImpl(
      db,
      Dio()..httpClientAdapter = api,
      'owner',
    );
  });
  tearDown(() async => db.close());

  test(
    'groups active shares by person, preserves invitations and vehicle quota',
    () async {
      await repo.refresh();
      final value = (await repo.watch().first)!;
      expect(value.people.keys, ['same-person']);
      expect(value.people.values.single.length, 2);
      expect(value.vehicles.expand((v) => v.pendingInvites).length, 2);
      expect(value.used, 2);
      expect(value.remaining, 1);
    },
  );

  test(
    'failed refresh preserves cache and another account cannot read it',
    () async {
      await repo.refresh();
      final saved = (await repo.watch().first)!.updatedAt;
      api.offline = true;
      await expectLater(repo.refresh(), throwsA(isA<DioException>()));
      expect((await repo.watch().first)!.updatedAt, saved);
      final other = SharedUsersRepositoryImpl(db, Dio(), 'other');
      expect(await other.watch().first, isNull);
    },
  );

  test(
    'unlimited quota and downgrade below usage never show negative slots',
    () async {
      api.limit = null;
      await repo.refresh();
      expect((await repo.watch().first)!.remaining, isNull);
      api.limit = 1;
      await repo.refresh();
      expect((await repo.watch().first)!.remaining, 0);
    },
  );
}
