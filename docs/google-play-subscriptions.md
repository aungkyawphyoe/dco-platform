# Google Play subscriptions — AutoX setup and release guide

Implementation date: 22 October 2026. This guide matches the code in this repository. Console labels can change; official references are linked below.

## What is implemented

Android purchases use Flutter's official `in_app_purchase` plugin. AutoX queries Google's product details and shows the actual localized price for the selected base plan. The API's MMK comparison price is never used as the Android checkout price. Regular auto-renewing monthly/annual plans are supported; trials, introductory offers, prepaid/installment plans, and in-app tier switching are excluded from this release. iOS checkout is not implemented.

The app listens across navigation, verifies purchased/restored tokens with our backend, refreshes the signed entitlement license, and offers Restore purchases and Manage subscription. Pending payments do not unlock access. An obfuscated account ID binds a purchase to its original AutoX account. Restore requires that same AutoX account and the Google account that owns the subscription.

The server calls `purchases.subscriptionsv2.get`, persists entitlement, then acknowledges. It processes authenticated Pub/Sub notifications by fetching the latest Google state, rather than trusting event contents/order. Active, grace-period, and canceled-but-unexpired subscriptions retain access. Pending, hold, paused, expired and revoked subscriptions do not. Paid access does not overwrite an admin-assigned plan or delete vehicle records. Offline paid licenses last at most 24 hours and never past Google's expiry; a refund/revocation can therefore take up to that window to affect an offline device.

New checkout requires a verified personal Free account with no live gift or existing unresolved Play subscription. Existing subscribers manage/cancel in Google Play and wait for expiry before purchasing a different tier/period in this first release. This avoids parallel charges without implementing replacement/proration yet.

## Where users subscribe

Open **Setting → Plans & subscriptions**, select Lite or Standard and a billing period, then tap **Subscribe with Google Play**. Selecting Free shows **Choose a paid plan** instead. Android keeps this action visible even when billing is unavailable; it stays disabled until checkout is ready. Debug builds using mock authentication show an explicit demo-mode message. Use `DCO_MOCK_AUTH=false` with a real account to exercise billing. Non-Android platforms explain that Google Play checkout requires the Android app.

## 1. Confirm the app identity and release signing

The current package/application ID is **`com.dco.dco_mobile`** in `mobile/android/app/build.gradle.kts`. Use this exact package in Play Console and `PLAY_PACKAGE_NAME`. If you want a different permanent package ID, change it before the first upload and update Firebase, Android namespace/source package, OAuth registration, and server configuration together. This guide does not rename it.

Create or reuse an upload keystore following [Flutter's Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app). Keep the keystore and passwords private and backed up. Add **untracked** `mobile/android/key.properties`:

```properties
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/private/path/autox-upload.jks
```

Release builds now require this configuration and no longer silently use the debug certificate. Debug builds remain available. Enroll in Play App Signing during the first release upload. Register the Play app-signing certificate with Firebase/Google authentication as appropriate; it differs from the upload certificate.

## 2. Create and activate the products

Complete your Play developer account/app setup and payments profile. Upload a signed Billing-enabled bundle to Internal testing. In the app's **Monetize with Play → Products → Subscriptions**, create:

| Product ID (exact) | Display name | Base plan ID (exact) | Type | Period |
|---|---|---|---|---|
| `autox_lite` | AutoX Lite | `monthly` | Auto-renewing | Monthly |
| `autox_lite` | AutoX Lite | `annual` | Auto-renewing | Yearly |
| `autox_standard` | AutoX Standard | `monthly` | Auto-renewing | Monthly |
| `autox_standard` | AutoX Standard | `annual` | Auto-renewing | Yearly |

For each base plan, set the desired regional prices and country availability, configure grace period/account hold, save, and **Activate**. Do not create a paid Free product. You do not need offers for this implementation. Confirm final regional prices in Console; AutoX's existing MMK prices are not automatically synchronized to Play. The app displays whatever Play returns for the customer's account/region.

See Google's [subscription setup guide](https://support.google.com/googleplay/android-developer/answer/140504). Configure products and base plans in that order; at least one activated base plan is needed to sell a product.

## 3. Configure secure backend verification

In Google Cloud, enable the **Google Play Android Developer API** and create a dedicated service account. In Play Console **Users and permissions**, invite its email and grant access to this app with the billing permissions Google lists: **View financial data, orders, and cancellation survey responses** and **Manage orders and subscriptions**. No developer-account/project linking step is required by the current API setup guide.

Supply its JSON credential to the **backend secret store only**, never to Flutter assets, Dart defines, source control, or a client build. The current integration reads a service-account JSON credential; rotate it through your deployment secret store.

Backend environment:

```text
PLAY_BILLING_ENABLED=on
PLAY_PACKAGE_NAME=com.dco.dco_mobile
PLAY_SERVICE_ACCOUNT_JSON=<secret JSON credential>
PLAY_RTDN_AUDIENCE=https://YOUR_API_HOST/v1/billing/google-play/notifications
PLAY_RTDN_SERVICE_ACCOUNT=YOUR_PUSH_IDENTITY@YOUR_PROJECT.iam.gserviceaccount.com
LICENSE_KID=<your signing key ID>
LICENSE_ED25519_KEY=<existing backend-only signing private key>
```

Apply the migration through the existing backend migration command: `npm run db:migrate` in `backend/`. Deploy the API before enabling checkout. New sales default **off** until configured. Turning `PLAY_BILLING_ENABLED` off later disables new sales while configured verification, restore, RTDN and reconciliation continue for existing customers. API service credentials and Pub/Sub push identity may be separate service accounts; this guide recommends separating them.

**Required app key:** `mobile/assets/license_keys.json` currently ships empty. Generate/manage the Ed25519 signing key using the existing `npm run license:key` tooling in `backend/`. Put only its public keyring entry in the app and keep the matching private key on the backend. The app refuses checkout if the server's `LICENSE_KID` is absent from its bundled keyring. Exercise a signed-license refresh before enabling sales.

See [Google Play API setup](https://developers.google.com/android-publisher/getting_started) and [purchase verification](https://developer.android.com/google/play/billing/security).

## 4. Configure real-time subscription notifications

1. In Google Cloud Pub/Sub, create a topic such as `autox-play-subscriptions`.
2. Grant `google-play-developer-notifications@system.gserviceaccount.com` **Pub/Sub Publisher** on that topic.
3. Create a **push subscription** delivering to `https://YOUR_API_HOST/v1/billing/google-play/notifications`. Enable authenticated push, select the push service account, and set the audience to the same URL used in `PLAY_RTDN_AUDIENCE`. Ensure the Pub/Sub service agent has the token-creation permission required for authenticated push and the configuring identity can act as the push service account.
4. In Play Console's **Monetization setup → Real-time developer notifications**, set the full topic name `projects/YOUR_PROJECT/topics/autox-play-subscriptions`. Enable subscription notifications and send a test notification.
5. Confirm the endpoint returns 204 for an authenticated test. Monitor Pub/Sub retries/dead letters and API failures. The endpoint checks Google's signature, issuer, audience, verified service-account email, and package name.
6. Schedule `npm run billing:reconcile` from `backend/` **hourly** with the same backend environment as a backstop for missed notifications. It refreshes purchases whose expiry is within the last 60 days or later. Alert on a nonzero exit status. For compiled production deployments run `node dist/scripts/reconcile-play.js` instead.

Unknown purchase tokens in notifications are not attached to an arbitrary account. The app's authenticated verification/restore binds the initial purchase; startup/resume restore retries if the initial response was lost. Known tokens are refreshed on every notification. Pub/Sub non-2xx responses retry automatically according to your subscription policy.

References: [RTDN setup](https://developer.android.com/google/play/billing/getting-ready), [authenticated push](https://cloud.google.com/pubsub/docs/authenticate-push-subscriptions), [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

## 5. Build and test on the internal track

From `mobile/`, after signing and public-key configuration:

```sh
flutter pub get
flutter build appbundle --release --dart-define-from-file=config/prod.json --dart-define=DCO_MOCK_AUTH=false
```

Upload `mobile/build/app/outputs/bundle/release/app-release.aab` to Internal testing. Increment `version`'s build number in `pubspec.yaml` for later uploads. Use the current target-SDK requirements shown in Console; the project inherits Flutter's target/compile SDK settings.

Add testers to **both** the internal testing track and **Settings → License testing**. Install through the opt-in Play Store link using that Google account. Internal-track membership alone does not make purchases free. Confirm Play's test payment instrument is shown before buying.

Run this release test matrix against the deployed backend:

- Lite/Standard × monthly/annual: correct localized price, native checkout, one acknowledged purchase, matching signed license and limits.
- Cancel checkout; pending payment completes and pending payment cancels; declined payment.
- Close/kill the app during checkout; resume and restore; retry after a lost verification response.
- Reinstall/second device with the same AutoX and Google accounts; wrong AutoX account must not receive access.
- Renewal, cancellation with remaining paid time, expiry, grace, hold, recovery, refund/revoke. Use Play Billing Lab/test instruments and verify RTDN plus reconciliation.
- No Play Store, offline, unavailable region/product, missing backend config or app license key: checkout stays disabled and Free remains usable.
- Active gift/admin plan/Driver account: no duplicate personal checkout. Expiry preserves existing records.
- English/Burmese, light/dark, narrow screen and enlarged text.

See [Google's billing test guide](https://developer.android.com/google/play/billing/test). Repository tests use simulated store/API responses; they do not replace internal-track purchase tests.

## Release checklist

- Permanent package ID, release signing, payments profile and active products/base plans confirmed.
- Server migration deployed; API credential permissions, authenticated RTDN and hourly reconciliation verified.
- Public license key bundled and signed license verification tested on the release build.
- All purchase lifecycle cases above pass using license testers.
- Store listing, privacy policy, Data safety/account deletion, subscription terms and any Console-mandated testing/review steps completed for this developer account.
- Enable production sales only after those checks. No Console configuration, cloud deployment, keystore generation, credential installation, or publishing is performed by the code change itself.
