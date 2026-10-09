# Authentication rollout and provider setup

The implementation extends the existing Fastify sessions. No production credentials are included. Real provider sign-in and email delivery are release gates, not covered by local fakes.

## Email codes

1. Apply backend migrations (`npm run db:migrate`, also run by server startup). Migration 0012 makes password credentials nullable, adds identities/challenges/flows/rate counters and an auth version. It performs a one-time correction of legacy owner addresses automatically marked verified when email verification was disabled. A consumed legacy verification token preserves verified status; personal data and shares are retained.
2. Generate an independent random secret of at least 32 characters and store it as `AUTH_CODE_SECRET` in the deployment secret store.
3. Configure `MAIL_PROVIDER=acs`, `MAIL_API_KEY` (ACS connection string), and `MAIL_FROM` using your verified sender. Complete sender-domain/DNS verification in Azure and test deliverability. `MAIL_PROVIDER=stdout` prints codes in local development only; it refuses code delivery in production.
4. Set `AUTH_CODES_ENABLED=on` after the sender is ready. Keep `EMAIL_VERIFICATION=on` as well for old-client compatibility. This enables new-owner verification and new collaboration guards; existing shares remain usable.
5. Start the mobile app with `--dart-define=DCO_MOCK_AUTH=false` and the API URL. The existing debug mock is not a fake OAuth or fake code service.

Codes expire after ten minutes; five failed guesses exhaust a challenge. Resend requires sixty seconds and is limited to eight requests per address/hour and thirty/IP/hour across purposes. Verification submission is limited to sixty/IP/hour; reset hashing to twenty/IP/hour. Limits are shared through PostgreSQL, including across replicas. Monitor and tune these initial budgets for real traffic, including users behind shared networks. `AUTH_TRUST_PROXY_HOPS` defaults to 0. Configure the verified number of trusted, sanitizing ingress hops for your deployment so rate limits use individual client IPs rather than a shared proxy. Request forwarding must preserve a trustworthy client IP; do not blindly trust arbitrary X-Forwarded-For values.

New mobile clients use `/auth/email-code` and `/auth/recovery-code`. Legacy link endpoints remain available for issued links and old clients. Recovery never creates a password for social-only accounts. Successful reset invalidates both access and refresh tokens. Existing refresh tokens without version claims remain valid only at auth version zero.

## Google

- Create a Google Cloud OAuth project, configure consent/branding and publish/verify as required for your audience.
- This implementation uses a confidential web OAuth client with the mobile system browser on both platforms. Configure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` only on the backend.
- Register the exact HTTPS redirect `PUBLIC_API_URL/auth/social/google/callback` (PUBLIC_API_URL includes `/v1`). Set the actual public API URL, not the infrastructure placeholder.
- The backend uses authorization-code exchange with PKCE, state, nonce, Google signing keys, and explicit issuer/audience validation. The app receives only a flow identifier through the redirect; its separately held secret completes the exchange.

## Apple

- Obtain an Apple Developer membership. Configure the primary App ID and Sign in with Apple, then the associated Services ID for this browser flow.
- Register your HTTPS callback domain and exact return URL `PUBLIC_API_URL/auth/social/apple/callback`.
- Configure `APPLE_CLIENT_ID` (Services ID), `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and `APPLE_PRIVATE_KEY` (PKCS8 .p8 PEM; escaped newlines are accepted). Keep the private key only in backend secrets.
- Backend-generated Apple client secrets last five minutes. Apple returns to the backend using form_post; the backend validates the exchanged ID token before redirecting to the app.
- Configure Apple's private email relay sender registration for delivery to users who hide their email. Test relay delivery as well as normal addresses.
- Both platforms currently use the system-browser flow, including iOS. Validate Apple account configuration, consent, and store-review behavior on real devices before release.

## App callback and platform checks

- App callback: `dco-auth://callback?flow_id=...`. No DCO tokens, provider tokens, or exchange secret appear in that URL. The retained random secret prevents another app intercepting the scheme from redeeming the flow.
- Android registers the flutter_web_auth_2 callback activity, empty task affinity, and Internet permission. iOS uses the plugin's ASWebAuthenticationSession custom-scheme completion; no embedded webview or client secret is used.
- The plugin's implementation includes an iOS pre-17.4 fallback, preserving the existing iOS 15.6 deployment target.
- Test Google and Apple login, cancelled login, hidden/missing email, existing-account linking, expired flow, app backgrounding, and relaunch on both devices. A killed app discards its in-memory flow secret and must restart sign-in.
- Existing account choice requires password/provider authentication; matching an email never connects accounts automatically. Settings → Account connections supports linking and adding a first password after recent authentication and verified email.

## Deployment and operations

Add the environment values above to Container Apps secrets/env configuration; the current Bicep template does not provision external OAuth registrations or populate these values. Do not deploy by copying local stdout/debug settings. Provider login returns `provider_not_configured` until its settings are present; mobile renders a localized explanation and preserves email login.

Back up the database before rollout. Apply the migration before deploying code which selects `auth_version`. Roll forward fixes rather than dropping identity tables. Turning off new UI entry points must not remove login for users who have only a provider identity. Do not disable provider credentials as a general rollback.

Schedule maintenance for expired transient data (retain at least 24 hours for operational inspection): delete expired `auth_flows` and `auth_challenges`, and expired `auth_limits`. Never delete `auth_identities` as cleanup. Logs redact authorization headers and omit request query strings; production email codes are not logged. Monitor callback failures, code delivery failures, rate limits, and verification completion without including credentials or raw emails in telemetry.

## References checked during implementation

- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
- [Apple environment configuration](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)
- [Apple token validation](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens)
- [Flutter Web Auth 2](https://pub.dev/packages/flutter_web_auth_2)

The new English/Burmese onboarding and auth messages are implemented. Burmese copy should receive native-language review before store submission; the pre-existing app also has untranslated messages outside this release.
