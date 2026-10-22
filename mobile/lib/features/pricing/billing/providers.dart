import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/providers.dart';
import '../../../core/gating/providers.dart';
import '../data/play_billing_backend.dart';
import '../data/play_billing_store.dart';
import '../providers.dart';
import 'play_billing_controller.dart';

final playBillingProvider =
    StateNotifierProvider<PlayBillingController, PlayBillingState>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      final keyring = ref.watch(licenseKeyringProvider).valueOrNull ?? [];
      final enabled =
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          userId != null &&
          ref.watch(authUserProvider.select((u) => u?.role)) != 'org_driver' &&
          !ref.watch(appConfigProvider).mockAuth;
      return PlayBillingController(
        store: enabled ? GooglePlayStore(InAppPurchase.instance) : null,
        backend: enabled
            ? PlayBillingBackend(
                ref.watch(dioProvider),
                keyring.map((k) => k.kid).toSet(),
              )
            : null,
        isCurrentAccount: () => ref.read(currentUserIdProvider) == userId,
        refreshEntitlements: () async {
          await ref.read(pricingRepositoryProvider).refresh();
          if (ref.read(currentUserIdProvider) != userId) return false;
          await ref
              .read(licenseControllerProvider.notifier)
              .refreshIfStale(force: true);
          if (ref.read(currentUserIdProvider) != userId) return false;
          await ref.read(refreshAccountProfileProvider)();
          final plan = ref.read(licenseControllerProvider).valueOrNull?.planId;
          return plan != null && plan != 'free';
        },
      );
    });
