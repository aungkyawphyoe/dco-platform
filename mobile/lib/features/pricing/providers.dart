import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'domain/pricing.dart';
import 'data/pricing_repository.dart';

final pricingRepositoryProvider = Provider<PricingRepository>(
  (ref) => LocalPricingRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioProvider),
    ref.watch(currentUserIdProvider) ?? 'signed-out',
  ),
);
final pricingPlansProvider = StreamProvider.autoDispose<List<PricingPlan>?>(
  (ref) => ref.watch(pricingRepositoryProvider).watchPlans(),
);
final subscriptionStatusProvider =
    StreamProvider.autoDispose<SubscriptionStatus?>(
      (ref) => ref.watch(pricingRepositoryProvider).watchSubscription(),
    );
