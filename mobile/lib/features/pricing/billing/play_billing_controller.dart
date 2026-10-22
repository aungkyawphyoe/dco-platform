import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/play_billing.dart';

class PlayBillingState {
  const PlayBillingState({
    this.supported = false,
    this.loading = false,
    this.busy = false,
    this.canPurchase = false,
    this.offers = const [],
    this.message,
  });
  final bool supported, loading, busy, canPurchase;
  final List<BillingOffer> offers;
  final String? message;
  BillingOffer? offer(String plan, bool annual) => offers
      .where(
        (o) => o.plan == plan && o.period == (annual ? 'annual' : 'monthly'),
      )
      .firstOrNull;
}

/// App-scoped listener: checkout survives route changes and restores on launch/resume.
/// Only a verified, signed server license changes the local gate.
class PlayBillingController extends StateNotifier<PlayBillingState> {
  PlayBillingController({
    required BillingStore? store,
    bool? supported,
    String? initialMessage,
    required this.backend,
    required this.refreshEntitlements,
    required this.isCurrentAccount,
  }) : _store = store,
       super(
         PlayBillingState(
           supported: supported ?? store != null,
           loading: store != null,
           message: initialMessage,
         ),
       ) {
    if (store != null) {
      _listener = store.events.listen((events) {
        _queue = _queue.then((_) => _handle(events)).catchError((Object _) {
          _update(message: 'verification_pending', busy: false);
        });
      }, onError: (Object _) => _update(message: 'unavailable', busy: false));
      unawaited(reload());
    }
  }
  final BillingStore? _store;
  final BillingBackend? backend;
  final Future<bool> Function() refreshEntitlements;
  final bool Function() isCurrentAccount;
  StreamSubscription<List<BillingEvent>>? _listener;
  Future<void> _queue = Future.value();
  bool _reloading = false;
  bool get _active => mounted && isCurrentAccount();
  void _update({
    bool? loading,
    bool? busy,
    bool? canPurchase,
    List<BillingOffer>? offers,
    String? message,
  }) {
    if (!_active) return;
    state = PlayBillingState(
      supported: state.supported,
      loading: loading ?? state.loading,
      busy: busy ?? state.busy,
      canPurchase: canPurchase ?? state.canPurchase,
      offers: offers ?? state.offers,
      message: message,
    );
  }

  Future<void> reload() async {
    if (_store == null || !_active || _reloading) return;
    _reloading = true;
    _update(loading: true);
    try {
      final eligibility = await backend!.eligibility();
      if (!_active) return;
      if (!await _store.available()) {
        _update(
          loading: false,
          canPurchase: false,
          offers: [],
          message: 'unavailable',
        );
        return;
      }
      if (!eligibility.enabled) {
        _update(
          loading: false,
          canPurchase: false,
          offers: [],
          message: 'unavailable',
        );
        // A sales kill switch must not stop restoring already-paid purchases.
        await _store.restore();
        return;
      }
      final offers = await _store.offers();
      if (!_active) return;
      _update(
        loading: false,
        offers: offers,
        canPurchase: eligibility.canPurchase,
      );
      await _store.restore();
    } catch (_) {
      _update(loading: false, canPurchase: false, message: 'unavailable');
    } finally {
      _reloading = false;
    }
  }

  Future<void> buy(BillingOffer offer) async {
    if (!_active || _store == null || state.busy || !state.canPurchase) return;
    _update(busy: true);
    try {
      // Check account eligibility again immediately before opening checkout.
      final eligibility = await backend!.eligibility();
      if (!_active) return;
      if (!eligibility.enabled || !eligibility.canPurchase) {
        _update(busy: false, canPurchase: false, message: 'ineligible');
        return;
      }
      if (!await _store.buy(offer, eligibility.accountId)) {
        _update(busy: false, message: 'canceled');
      }
    } catch (_) {
      _update(busy: false, message: 'unavailable');
    }
  }

  Future<void> restore() async {
    if (!_active || _store == null || state.busy) return;
    _update(busy: true, message: 'restoring');
    try {
      await _store.restore();
      await _queue;
      if (state.message == 'restoring') {
        _update(busy: false, message: 'restore_complete');
      }
    } catch (_) {
      _update(busy: false, message: 'verification_pending');
    }
  }

  Future<void> _handle(List<BillingEvent> events) async {
    for (final event in events) {
      if (!_active) return;
      switch (event.status) {
        case BillingEventStatus.pending:
          _update(busy: false, canPurchase: false, message: 'pending');
        case BillingEventStatus.canceled:
          _update(busy: false, message: 'canceled');
        case BillingEventStatus.error:
          _update(busy: false, message: 'unavailable');
        case BillingEventStatus.purchased:
        case BillingEventStatus.restored:
          _update(busy: true, canPurchase: false, message: 'verifying');
          try {
            final result = await backend!.verify(event.token);
            if (!_active) return;
            // Backend acknowledges after persisting entitlement; never complete a rejected purchase.
            if (result.acknowledged) await _store!.complete(event);
            if (!_active) return;
            final unlocked = await refreshEntitlements();
            if (!_active) return;
            final eligibility = await backend!.eligibility();
            _update(
              busy: false,
              canPurchase: eligibility.canPurchase,
              message: result.entitled
                  ? (unlocked ? 'success' : 'license_pending')
                  : 'inactive',
            );
          } on BillingFailure catch (error) {
            _update(busy: false, message: error.code);
          } catch (_) {
            _update(busy: false, message: 'verification_pending');
          }
      }
    }
  }

  @override
  void dispose() {
    unawaited(_listener?.cancel());
    super.dispose();
  }
}
