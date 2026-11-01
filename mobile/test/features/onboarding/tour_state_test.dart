import 'dart:convert';

import 'package:dco_mobile/core/database/app_database.dart';
import 'package:dco_mobile/core/onboarding/tour_targets.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/onboarding/data/repositories/tour_state_repository_impl.dart';
import 'package:dco_mobile/features/onboarding/domain/entities/tour_progress.dart';
import 'package:dco_mobile/features/onboarding/presentation/tour_controller.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('progress is account scoped and survives a reload', () async {
    final repo = TourStateRepositoryImpl(db);
    expect(await repo.load('u1'), const TourProgress.notSeen());

    await repo.save(
      'u1',
      const TourProgress(version: kTourVersion, status: TourStatus.completed),
    );

    expect(
      await repo.load('u1'),
      const TourProgress(version: kTourVersion, status: TourStatus.completed),
    );
    expect(
      await repo.load('u2'),
      const TourProgress.notSeen(),
      reason: 'another account on the same phone must not share tour state',
    );
  });

  test('a stored older tour version is offered again', () async {
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: TourStateRepositoryImpl.keyFor('u1'),
            value: Value(
              jsonEncode({'version': kTourVersion - 1, 'status': 'completed'}),
            ),
          ),
        );

    expect(
      await TourStateRepositoryImpl(db).load('u1'),
      const TourProgress.notSeen(),
    );
  });

  test('corrupt tour metadata is treated as not seen', () async {
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: TourStateRepositoryImpl.keyFor('u1'),
            value: const Value('not json'),
          ),
        );

    expect(
      await TourStateRepositoryImpl(db).load('u1'),
      const TourProgress.notSeen(),
    );
  });

  test(
    'offer, next, back, skip and completion transition predictably',
    () async {
      await container.read(tourProgressProvider.future);
      final tour = container.read(tourControllerProvider.notifier);

      tour.offer(tourStepsFor());
      expect(container.read(tourControllerProvider).phase, TourPhase.offered);

      tour.begin();
      var state = container.read(tourControllerProvider);
      expect(state.phase, TourPhase.running);
      expect(state.index, 0);
      expect(state.currentTarget, TourTarget.vehicle);

      await tour.next();
      await tour.next();
      expect(container.read(tourControllerProvider).index, 2);

      await tour.back();
      expect(container.read(tourControllerProvider).index, 1);

      await tour.skip();
      expect(container.read(tourControllerProvider).phase, TourPhase.idle);
      expect(
        container.read(tourProgressProvider).value?.status,
        TourStatus.dismissed,
      );
    },
  );

  test('back on the first step exits the tour', () async {
    await container.read(tourProgressProvider.future);
    final tour = container.read(tourControllerProvider.notifier);
    tour.start(tourStepsFor());

    await tour.back();

    expect(container.read(tourControllerProvider).phase, TourPhase.idle);
    expect(
      container.read(tourProgressProvider).value?.status,
      TourStatus.dismissed,
    );
  });

  test('reaching the final step records completion', () async {
    await container.read(tourProgressProvider.future);
    final tour = container.read(tourControllerProvider.notifier);
    tour.start(tourStepsFor());

    for (var i = 0; i < tourStepsFor().length; i++) {
      await tour.next();
    }

    expect(container.read(tourControllerProvider).phase, TourPhase.idle);
    expect(
      container.read(tourProgressProvider).value?.status,
      TourStatus.completed,
    );
  });

  test('declining the offer records dismissal once', () async {
    await container.read(tourProgressProvider.future);
    final tour = container.read(tourControllerProvider.notifier);
    tour.offer(tourStepsFor());

    await tour.notNow();

    expect(container.read(tourControllerProvider).phase, TourPhase.idle);
    expect(
      container.read(tourProgressProvider).value?.status,
      TourStatus.dismissed,
    );
    final rows = await db.select(db.appMeta).get();
    expect(
      rows.where((r) => r.key == TourStateRepositoryImpl.keyFor('u1')),
      hasLength(1),
    );
  });
}
