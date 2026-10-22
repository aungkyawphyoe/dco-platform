import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import '../domain/play_billing.dart';

/// Native prices/offer tokens are queried live, never reconstructed from API prices.
class GooglePlayStore implements BillingStore {
  GooglePlayStore(this._iap);
  final InAppPurchase _iap;
  final _products = <String, GooglePlayProductDetails>{};
  final _purchases = <String, PurchaseDetails>{};
  static const products = {'autox_lite': 'lite', 'autox_standard': 'standard'};
  @override
  Stream<List<BillingEvent>> get events => _iap.purchaseStream.map(
    (purchases) => [
      for (final purchase in purchases)
        if (products.containsKey(purchase.productID)) _event(purchase),
    ],
  );
  BillingEvent _event(PurchaseDetails purchase) {
    final token = purchase.verificationData.serverVerificationData;
    _purchases[token] = purchase;
    return BillingEvent(
      token: token,
      productId: purchase.productID,
      status: switch (purchase.status) {
        PurchaseStatus.pending => BillingEventStatus.pending,
        PurchaseStatus.purchased => BillingEventStatus.purchased,
        PurchaseStatus.restored => BillingEventStatus.restored,
        PurchaseStatus.canceled => BillingEventStatus.canceled,
        PurchaseStatus.error => BillingEventStatus.error,
      },
    );
  }

  @override
  Future<bool> available() => _iap.isAvailable();
  @override
  Future<List<BillingOffer>> offers() async {
    final response = await _iap.queryProductDetails(products.keys.toSet());
    if (response.error != null) throw const BillingFailure('unavailable');
    _products.clear();
    final offers = <BillingOffer>[];
    for (final product
        in response.productDetails.whereType<GooglePlayProductDetails>()) {
      final index = product.subscriptionIndex;
      if (index == null) continue;
      final offer = product.productDetails.subscriptionOfferDetails![index];
      // First release sells regular auto-renewing base plans only, not trial/intro offers.
      if (offer.offerId != null ||
          !['monthly', 'annual'].contains(offer.basePlanId) ||
          offer.pricingPhases.length != 1) {
        continue;
      }
      final phase = offer.pricingPhases.single;
      if (phase.recurrenceMode != RecurrenceMode.infiniteRecurring ||
          phase.billingPeriod !=
              (offer.basePlanId == 'annual' ? 'P1Y' : 'P1M')) {
        continue;
      }
      final entry = BillingOffer(
        plan: products[product.id]!,
        period: offer.basePlanId,
        price: phase.formattedPrice,
      );
      _products[entry.key] = product;
      offers.add(entry);
    }
    return offers;
  }

  @override
  Future<bool> buy(BillingOffer offer, String accountId) {
    final product = _products[offer.key];
    if (product == null) throw const BillingFailure('unavailable');
    return _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: accountId,
        offerToken: product.offerToken,
      ),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
  @override
  Future<void> complete(BillingEvent event) async {
    final purchase = _purchases[event.token];
    if (purchase?.pendingCompletePurchase == true) {
      await _iap.completePurchase(purchase!);
    }
  }
}
