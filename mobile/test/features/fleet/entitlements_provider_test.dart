import 'dart:async';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fleet/domain/entities/entitlements.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFleetRepository extends Mock implements FleetRepository {}

final _userId = StateProvider<String?>((ref) => null);

const _entitlements = Entitlements(
  plan: 'standard',
  vehicleSharing: VehicleSharingEntitlement(
    available: true,
    canShare: true,
    perVehicle: null,
    total: null,
    activeShares: 1,
  ),
  organization: null,
  features: FleetFeatures(vehicleSharing: true, fleet: false),
);

void main() {
  test('signed-out state is data(null), not a startup error', () async {
    final repository = _MockFleetRepository();
    when(
      () => repository.readCachedEntitlements(),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getEntitlements(),
    ).thenAnswer((_) async => _entitlements);
    final container = ProviderContainer(
      overrides: [
        fleetRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWith((ref) => ref.watch(_userId)),
      ],
    );
    addTearDown(container.dispose);

    final signedOut = container.read(entitlementsProvider);
    expect(signedOut.hasError, isFalse);
    expect(signedOut.valueOrNull, isNull);

    container.read(_userId.notifier).state = 'user-1';

    expect(await container.read(entitlementsProvider.future), _entitlements);
    verify(() => repository.getEntitlements()).called(1);
  });
  test(
    'cached account access is available while the network is stalled',
    () async {
      final repository = _MockFleetRepository();
      final response = Completer<Entitlements>();
      when(
        () => repository.readCachedEntitlements(),
      ).thenAnswer((_) async => _entitlements);
      when(
        () => repository.getEntitlements(),
      ).thenAnswer((_) => response.future);
      final container = ProviderContainer(
        overrides: [
          fleetRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWithValue('user-1'),
        ],
      );
      addTearDown(container.dispose);
      final states = <Entitlements?>[];
      final subscription = container.listen(
        entitlementsProvider,
        (_, next) => states.add(next.valueOrNull),
      );
      addTearDown(subscription.close);
      expect(await container.read(entitlementsProvider.future), _entitlements);
      expect(response.isCompleted, isFalse);
      final fresh = Entitlements(
        plan: 'free',
        vehicleSharing: _entitlements.vehicleSharing,
        organization: null,
        features: _entitlements.features,
      );
      response.complete(fresh);
      await container.pump();
      expect(states.last, fresh);
    },
  );
}
