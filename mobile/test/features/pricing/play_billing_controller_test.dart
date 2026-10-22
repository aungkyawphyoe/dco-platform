import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dco_mobile/features/pricing/billing/play_billing_controller.dart';
import 'package:dco_mobile/features/pricing/domain/play_billing.dart';

const offer = BillingOffer(plan: 'lite', period: 'monthly', price: r'$0.99');

class Store implements BillingStore {
  final updates = StreamController<List<BillingEvent>>.broadcast(sync: true);
  final completed = <String>[];
  int buys = 0, restores = 0;
  String? account;
  bool launches = true;
  @override
  Stream<List<BillingEvent>> get events => updates.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<List<BillingOffer>> offers() async => [offer];
  @override
  Future<bool> buy(BillingOffer offer, String accountId) async {
    buys++;
    account = accountId;
    return launches;
  }

  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<void> complete(BillingEvent event) async {
    completed.add(event.token);
  }

  void emit(BillingEventStatus status) => updates.add([
    BillingEvent(token: 'token', status: status, productId: 'autox_lite'),
  ]);
}

class Backend implements BillingBackend {
  bool eligible = true, fail = false, enabled = true;
  int verifies = 0;
  Completer<BillingVerification>? pending;
  BillingVerification result = const BillingVerification(
    entitled: true,
    acknowledged: true,
  );
  @override
  Future<BillingEligibility> eligibility() async => BillingEligibility(
    enabled: enabled,
    canPurchase: eligible && enabled,
    accountId: 'hashed-account',
    packageName: 'com.dco.dco_mobile',
  );
  @override
  Future<BillingVerification> verify(String token) async {
    verifies++;
    if (fail) throw const BillingFailure('purchase_account_mismatch');
    return pending == null ? result : pending!.future;
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
void main() {
  late Store store;
  late Backend backend;
  late PlayBillingController controller;
  late bool current, unlocked;
  late int refreshes;
  setUp(() async {
    store = Store();
    backend = Backend();
    current = true;
    unlocked = true;
    refreshes = 0;
    controller = PlayBillingController(
      store: store,
      backend: backend,
      isCurrentAccount: () => current,
      refreshEntitlements: () async {
        refreshes++;
        return unlocked;
      },
    );
    await settle();
  });
  tearDown(() async {
    controller.dispose();
    await store.updates.close();
  });
  test('sales disabled still restores existing purchases', () async {
    backend.enabled = false;
    await controller.reload();
    expect(store.restores, 2);
    expect(controller.state.canPurchase, false);
    expect(controller.state.offers, isEmpty);
  });
  test(
    'loads native price and restores on startup; rechecks eligibility before checkout',
    () async {
      expect(controller.state.offer('lite', false)?.price, r'$0.99');
      expect(store.restores, 1);
      backend.eligible = false;
      await controller.buy(offer);
      expect(store.buys, 0);
      backend.eligible = true;
      await controller.reload();
      await controller.buy(offer);
      expect(store.account, 'hashed-account');
      expect(store.buys, 1);
    },
  );
  test(
    'pending and canceled purchases never verify, acknowledge, or unlock',
    () async {
      store.emit(BillingEventStatus.pending);
      await settle();
      expect(controller.state.message, 'pending');
      store.emit(BillingEventStatus.canceled);
      await settle();
      expect(controller.state.busy, false);
      expect(backend.verifies, 0);
      expect(store.completed, isEmpty);
      expect(refreshes, 0);
    },
  );
  test(
    'waits for verification before completion and entitlement refresh',
    () async {
      backend.pending = Completer<BillingVerification>();
      store.emit(BillingEventStatus.purchased);
      await settle();
      expect(controller.state.busy, true);
      expect(store.completed, isEmpty);
      expect(refreshes, 0);
      backend.pending!.complete(
        const BillingVerification(entitled: true, acknowledged: true),
      );
      await settle();
      expect(store.completed, ['token']);
      expect(refreshes, 1);
      expect(controller.state.message, 'success');
    },
  );
  test(
    'rejected purchase is never completed and can retry via restored event',
    () async {
      backend.fail = true;
      store.emit(BillingEventStatus.purchased);
      await settle();
      expect(store.completed, isEmpty);
      expect(refreshes, 0);
      expect(controller.state.message, 'purchase_account_mismatch');
      backend.fail = false;
      store.emit(BillingEventStatus.restored);
      await settle();
      expect(store.completed, ['token']);
      expect(controller.state.message, 'success');
    },
  );
  test(
    'does not show success when the signed license has not activated',
    () async {
      unlocked = false;
      store.emit(BillingEventStatus.purchased);
      await settle();
      expect(controller.state.message, 'license_pending');
    },
  );
  test(
    'switching accounts during verification never refreshes or completes in new account',
    () async {
      backend.pending = Completer<BillingVerification>();
      store.emit(BillingEventStatus.purchased);
      await settle();
      current = false;
      backend.pending!.complete(
        const BillingVerification(entitled: true, acknowledged: true),
      );
      await settle();
      expect(store.completed, isEmpty);
      expect(refreshes, 0);
    },
  );
  test('inactive/unacknowledged purchases do not complete', () async {
    backend.result = const BillingVerification(
      entitled: false,
      acknowledged: false,
    );
    store.emit(BillingEventStatus.restored);
    await settle();
    expect(store.completed, isEmpty);
    expect(controller.state.message, 'inactive');
  });
  test('empty restore and canceled launch leave controls usable', () async {
    await controller.restore();
    expect(controller.state.busy, false);
    store.launches = false;
    await controller.buy(offer);
    expect(controller.state.busy, false);
    expect(controller.state.message, 'canceled');
  });
}
