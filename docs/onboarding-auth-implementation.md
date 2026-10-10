# Onboarding and Authentication — Implementation Specification

**Date:** 9 October 2026 (Asia/Rangoon)
**Status:** Implemented in the working tree; live provider/email and real-device acceptance pending. See [setup and rollout](auth-provider-setup.md).
**Contract:** [Auth FRD](../product/frd/auth.md), [production scope](../product/production-scope.md).

## Outcome

A new owner explores three optional illustrated introduction screens (Burmese/English preselected from the device language and switchable from the app bar), and creates an account using email/password, Google, or Apple. Email signup offers immediate code verification with a skip action. First vehicle setup is optional. Personal access never depends on email verification; new share creation and invitation acceptance do. Existing shares continue working.

## Current implementation and gaps

- `backend/src/modules/auth.ts` owns signup, login, session refresh, token verification, resend, and password reset. Verification defaults off in environment configuration.
- `backend/src/lib/mail.ts` supports stdout and Azure Communication Services. Current verification/reset emails link to API paths whose handlers expect POST bodies; a browser click does not complete either flow.
- Mobile already has secure tokens, auth repositories, session state, and localization. Extend these contracts rather than replacing the session system.
- Existing user password/schema assumptions must be reviewed before adding accounts without passwords. Drivers may have usernames and no email.
- Pre-login language and installation completion need storage independent of account profile rows. Existing language preference persistence is local; do not promise cross-device preference restoration without adding a server contract.
- Apple Developer, Google provider setup, callback domain, and production sender are not configured. Local development may proceed with explicit test fakes; release validation requires real credentials.

## Mobile flow and state

1. Resolve an existing session before showing first-run UI. Existing authenticated installations must not be trapped by a newly introduced completion flag.
2. For a fresh unauthenticated installation, show the three-page illustrated introduction; language comes from the device (switchable from the app bar). Persist completion on finish, skip, or Sign in.
3. Account entry offers email signup/login and Google/Apple. Preserve pending invitations across auth and verification; validate return destinations rather than accepting arbitrary URLs.
4. For an unknown provider identity, exchange proof for a short-lived server-bound continuation, then display new/existing account choices. Authenticate the existing account before binding the identity.
5. Email signup leads to verification with resend, correction, and Do this later. Social signup with validated verified email skips the code.
6. New owners may add a first vehicle or skip to the dashboard. Fleet/driver destinations follow existing authorization.
7. On account restoration, load the saved language if present; otherwise keep the pre-login choice. Keep account data and unsent writes isolated during all transitions.

Screen responsibilities belong in auth presentation and repositories; shared pre-login locale/installation state belongs in core. No direct Dio or Drift access from screens. New illustration assets should match existing themes, have a license/provenance record, and leave text in localization resources rather than baked into images. Final Burmese copy needs language review.

## Backend design

### Identity and account data

- Add external identity records with user ID, provider, stable subject, and timestamps; enforce unique `(provider, subject)` in the database.
- Permit an absent password credential for social-only accounts without breaking provisioned drivers or existing password users. Never manufacture a known placeholder password.
- Email uniqueness must remain consistent with existing normalization. Provider email is metadata, not an account key or permission to link.
- Linking requires recent DCO account authentication plus valid provider proof, with expiry, one-time consumption, and transactional uniqueness checks.
- Provider proof must validate signature, issuer, audience, expiry, and applicable nonce/state/PKCE protections. Register platform-specific client identifiers and validate against an explicit allowlist. Final SDK and callback implementation must be checked against official provider documentation during implementation.
- Browser callbacks must not place DCO bearer or refresh tokens in query strings. Exchange a short-lived, single-use continuation bound to the initiating flow.

### Challenges

Use purpose-specific challenge records with an opaque ID, account/address binding, protected code digest, expiry, attempt count, resend/request counters, consumed timestamp, and locale. A six-digit code has low entropy: use a keyed digest with a server-held secret rather than an unkeyed hash vulnerable to offline enumeration.

Generate codes cryptographically, retain leading zeroes, and never log codes, provider tokens, or reset grants in production. Compare safely, atomically increment failed attempts, and atomically consume successful challenges. Distributed rate limits must work across Container App replicas; an in-memory limiter alone is insufficient.

Initial proposed defaults: ten-minute lifetime, five attempts, sixty-second resend cooldown. Add configurable per-address/account and per-IP hourly request budgets; verify those thresholds against delivery and abuse testing before release. Resend must not create unlimited guesses by resetting only a per-code counter. Retire the previous challenge and handle delayed/out-of-order emails explicitly.

Email correction for an unverified account requires recent authentication. Update the address and invalidate old challenges transactionally; reset verification and send a challenge bound to the new address. Preserve account identity and its records. Do not reuse this flow for an unrestricted verified-email change.

Recovery submits the six-digit code and replacement password together. Consume the challenge atomically with password replacement; no session or reusable reset grant is issued. Social-only or unknown accounts return the same public request response and receive no password-creation grant. Adding a first password from Settings requires recent provider authentication and verified email control.

### Enforcement and revocation

Add a reusable owner-email-verification guard to share creation and acceptance paths, including code/QR flows. Do not blanket-block existing shared reads/writes or revoke grants. Client visibility is a convenience; direct API calls must be guarded.

Audit current access JWT validation: deleting refresh rows alone does not revoke issued access tokens. Implement a session/auth-version check or equivalent server-side revocation strategy, and test old access and refresh tokens after reset. Preserve existing token audiences and role guards.

### API changes

Design exact paths and payloads in `architecture/openapi.yaml` before endpoint implementation, covering:

- Request/confirm verification challenge, resend, and authenticated email correction.
- Generic recovery request, recovery confirmation, and reset completion.
- Provider exchange, new-account continuation, authenticated linking, connected-provider listing, and authenticated first-password setup.
- Stable errors for verification required, invalid/expired challenge, attempt exhaustion, cooldown, identity collision, and reauthentication required.

Keep current clients operational during deployment. Version or add routes where six-digit challenges differ from current link-token payloads. Decide an explicit expiry/deprecation window for already-issued links; do not silently reinterpret tokens as codes. Regenerate API types for both web apps when the contract changes.

## External setup checklist

- [ ] Confirm release app name, Android package ID, iOS bundle ID, and controlled callback domain from project/release configuration.
- [ ] Enroll/configure Apple Developer resources for the system-browser flow on iOS and Android; register callbacks and secure server credentials.
- [ ] Configure Google project, consent/branding, confidential web client, and callback registrations for staging and production.
- [ ] Configure domain/DNS/TLS and platform link association files where applicable; allowlist callbacks per environment.
- [ ] Configure Azure Communication Services email sender/domain, DNS authentication, sender address, and delivery monitoring. Verify English and Burmese email content.
- [ ] Store secrets in deployment secret storage, provide placeholders in environment examples, and document rotation. Never commit credentials or private keys.
- [ ] Verify provider policies and app-store release requirements against official documentation at implementation/release time.

Provider account ownership, paid enrollment, and domain choice require user-supplied setup. Do not invent credentials or mark live provider acceptance complete from mocks.

## Validation snapshot

- Backend and both web applications pass TypeScript checking; OpenAPI types regenerated for both portals.
- All 57 backend tests pass, covering email codes, recovery revocation, account linking, and signed Google/Apple callback exchanges using test keys. Live provider credentials are not used by these tests.
- All 300 mobile tests pass, including first-run persistence, existing preference preservation, failed-login feedback, account-transition sync waiting, and per-account attachment selection.
- iOS simulator and Android debug builds succeeded with the browser auth plugin. Android reports a future Kotlin-plugin compatibility warning; the current build succeeds.
- Flutter analysis reports 43 pre-existing warnings/infos elsewhere in the app and no new auth/onboarding issues. Native-language copy review and real-provider/email/device acceptance remain outstanding.

## Phased task list

### Phase 1 — Contracts and compatibility

- [x] Inventory auth routes, token claims, user credential constraints, share mutations, driver exceptions, and existing tests.
- [x] Finalize OpenAPI requests/errors and additive database migrations for identities, challenges, continuations, and session revocation.
- [x] Record feature flags and migration policy for existing users, active sessions, old clients, and old email links.
- [x] Add secure configuration placeholders and setup instructions.

**Exit:** Reviewed contracts and migration tests preserve current user IDs, passwords, shares, plans, and driver login.

### Phase 2 — Email verification and recovery backend

- [x] Implement challenge issuance, expiry, atomic attempt/consume logic, rate limits, resend, and correction.
- [x] Add localized email delivery with retry/error handling; challenge issuance must not falsely claim delivery succeeded.
- [x] Implement recovery and full session revocation, excluding social-only accounts.
- [x] Add collaboration guards.
- [ ] Complete deployed existing-share compatibility acceptance.

**Exit:** API integration tests cover wrong/expired/replayed codes, concurrent submissions, email collisions, resend abuse, and access/refresh revocation.

### Phase 3 — Mobile introduction and email flows

- [x] Add installation state and pre-login localization, then create the three illustrated pages and persistent Sign in action.
- [x] Add verification, email correction, resend timer, recovery, new-password forms, and dismissible existing-user reminder.
- [x] Connect optional first-vehicle setup and resume pending collaboration after verification.
- [x] Preserve existing driver routing, initialize new-account language without overwriting saved preferences, and retain local data.
- [ ] Complete physical-device offline/auth interruption acceptance.

**Exit:** Both languages and themes work with text scaling; completion persists through restart/logout; widget and navigation tests cover skips, returning users, and invitation resumption.

### Phase 4 — Social identity backend and mobile

- [ ] Complete provider configuration and select maintained platform packages using official docs.
- [x] Implement Google/Apple verification and continuation flows; enforce existing-account authentication before linking.
- [x] Implement both providers on both platforms, including Apple's browser flow on Android.
- [x] Add account connections and authenticated first-password setup in Settings.
- [ ] Cover hidden/missing email, missing name, identity collision, cancellation, replay, and concurrent linking.

**Exit:** Real provider sign-in, linking, and relaunch succeed on Android and iOS without duplicate/merged garages or elevated roles.

### Phase 5 — Release validation and rollout

- [x] Run backend/migration tests, mobile tests/static analysis, and web contract/type checks.
- [ ] Test physical-device/deployed-callback flows, delivery delays, code expiry, network loss, and email opened on another device.
- [ ] Test upgrades with existing sessions, unverified users, active shares, offline queues, and fleet/driver accounts.
- [x] Validate account switching does not upload another account's queued data or attachments; address the known sync isolation risk before release.
- [ ] Review localized copy and illustration accessibility; update as-built docs only after acceptance.
- [ ] Enable flags in staging first; monitor auth failures, delivery failures, throttling, verification completion, and duplicate-account support issues without logging sensitive data.

**Exit:** Real-device/provider acceptance and email delivery pass. Rollback preserves accounts and identity bindings; feature flags may hide new entry points but must not strand users whose only credential is a provider identity.
