class PricingPlan {
  const PricingPlan({
    required this.id,
    required this.name,
    required this.monthly,
    required this.annual,
    required this.vehicles,
    required this.sharing,
    required this.storageBytes,
  });
  final String id, name;
  final num monthly, annual;
  final int? vehicles, sharing;
  final int storageBytes;
  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    final prices = json['prices'] as Map<String, dynamic>;
    final limits = json['limits'] as Map<String, dynamic>;
    return PricingPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      monthly: prices['monthly']['mmk'] as num,
      annual: prices['annual']['mmk'] as num,
      vehicles: (limits['vehicles'] as num?)?.toInt(),
      sharing: (limits['sharing'] as num?)?.toInt(),
      storageBytes: (limits['storage_bytes'] as num).toInt(),
    );
  }
}

class GiftAccess {
  const GiftAccess({required this.plan, required this.endsAt});
  final String plan;
  final DateTime endsAt;
  factory GiftAccess.fromJson(Map<String, dynamic> json) => GiftAccess(
    plan: json['plan'] as String,
    endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
  );
}

class SubscriptionStatus {
  const SubscriptionStatus({required this.plan, this.gift});
  final String plan;
  final GiftAccess? gift;
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        plan: json['plan'] as String,
        gift: json['gift'] == null
            ? null
            : GiftAccess.fromJson(json['gift'] as Map<String, dynamic>),
      );
}

class RedemptionFailure implements Exception {
  const RedemptionFailure(this.code);
  final String code;
}

abstract interface class PricingRepository {
  Stream<List<PricingPlan>?> watchPlans();
  Stream<SubscriptionStatus?> watchSubscription();
  Future<void> refresh();
  Future<GiftAccess> redeem(String code);
}
