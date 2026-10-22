enum BillingEventStatus { pending, purchased, restored, canceled, error }

class BillingOffer {
  const BillingOffer({
    required this.plan,
    required this.period,
    required this.price,
  });
  final String plan, period, price;
  String get key => '$plan:$period';
}

class BillingEvent {
  const BillingEvent({
    required this.token,
    required this.status,
    required this.productId,
  });
  final String token, productId;
  final BillingEventStatus status;
}

class BillingEligibility {
  const BillingEligibility({
    required this.enabled,
    required this.canPurchase,
    required this.accountId,
    required this.packageName,
  });
  final bool enabled, canPurchase;
  final String accountId, packageName;
}

class BillingVerification {
  const BillingVerification({
    required this.entitled,
    required this.acknowledged,
  });
  final bool entitled, acknowledged;
}

abstract interface class BillingStore {
  Stream<List<BillingEvent>> get events;
  Future<bool> available();
  Future<List<BillingOffer>> offers();
  Future<bool> buy(BillingOffer offer, String accountId);
  Future<void> restore();
  Future<void> complete(BillingEvent event);
}

abstract interface class BillingBackend {
  Future<BillingEligibility> eligibility();
  Future<BillingVerification> verify(String token);
}

class BillingFailure implements Exception {
  const BillingFailure(this.code);
  final String code;
}
