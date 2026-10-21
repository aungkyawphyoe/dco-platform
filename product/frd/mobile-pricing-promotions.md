# Mobile pricing and subscription gifts

Status: implemented locally on 21 October 2026; deployment and real-device acceptance pending.

## Release scope

Add personal-plan comparison and gift-code redemption to the Flutter mobile app, plus promotion management in AutoX Admin. Reuse the existing pricing API and entitlement/gating infrastructure. Paid checkout, payments, automatic renewal, permanent gifts, and fixed-calendar-end gifts are outside this release.

Production scope, the mobile agent contract, feature-gating architecture, and HTTP/data-model contracts are updated for this release. Paid billing remains outside scope.

## Agreed product decisions

1. Settings → **Plans & subscriptions** shows the current plan, gifted-access expiry when applicable, plan comparison, and a **Redeem a gift code** action opening the separate `/pricing/redeem` screen. Limit-reached prompts offer **View plans** and open the same screen.
2. Show Free, Lite, and Standard, monthly/annual prices, and **Paid subscriptions coming soon**. Do not offer a functioning paid-purchase action. Personal pricing and promotion entry points are hidden in Driver mode; gifts never increase organization limits.
3. Support both batches of unique single-use codes and shared campaign codes. Both belong to a promotion.
4. Each promotion grants either Lite or Standard for a configured number of days starting at successful redemption. There is no charge or automatic renewal.
5. A promotion has one redemption deadline, shared by all codes in its batch. The deadline limits when redemption can occur, not when granted access ends. A gift redeemed shortly before the deadline still receives its full duration.
6. Shared codes have a total redemption cap. Single-use batches are bounded by the number of generated codes.
7. Only accounts currently on Free can redeem. Existing admin-assigned Lite, Standard, or Fleet access must not be replaced or removed by this flow.
8. Verified email is required. Unverified users can view plans and are prompted to verify before redeeming; the attempt does not consume a code.
9. One active gift per account. No stacking, extension, or replacement while a gift is active. Rejected attempts do not consume codes or campaign capacity.
10. An account may redeem a given promotion only once, regardless of code type or how many codes it receives. After its gift expires, it may redeem a different promotion.
11. Redemption requires internet. Successful activation must refresh the account's effective entitlements and signed offline license.
12. At gift expiry, the account returns to Free. Existing records remain readable and editable, and existing active shares remain available. Block new vehicles, new shares, and uploads exceeding Free limits. Permit deletion, revoking shares, and storage-reducing operations. Existing domain rules still apply; editing must not bypass creation or storage limits.
13. Gift expiry applies locally while offline. The signed license must carry an enforceable gift deadline; changing the server plan alone is insufficient.
14. AutoX Admin can create promotions, select plan/duration/deadline, generate single-use batches or configure shared codes and redemption caps, inspect redemption counts/history, and disable future redemptions.
15. Disabling a promotion preserves access already granted. Revocation of redeemed gifts is outside this release.

## Implementation requirements derived from those decisions

These are engineering requirements, not additional interview decisions.

- Treat successful redemption as an atomic server operation: eligibility, deadline, enabled state, account/promotion uniqueness, single-use consumption or campaign capacity, grant creation, and entitlement changes must agree under concurrent requests.
- Handle retries after a lost response without granting twice or consuming additional capacity. A previously successful request must be distinguishable from a new rejected attempt.
- Persist promotion, code, redemption, and grant history. Enforce account/promotion uniqueness and single-use consumption in the database, not only in application prechecks.
- Use server timestamps and UTC instants for grant boundaries and deadline checks. Display understandable localized dates to users and administrators.
- Restrict promotion administration to the existing AutoX Admin authorization surface. Enforce redemption eligibility server-side, including personal-account restrictions; hiding Driver UI is insufficient.
- Protect redemption against guessing and automated abuse. Avoid exposing full redeemable secrets in routine logs or redemption-history views.
- Effective entitlement checks must honor expiry even if a scheduled cleanup job has not run. Expiry reconciliation must not overwrite a later independent admin plan change; define grant ownership/versioning before implementation.
- Refresh entitlement caches, navigation state, and signed licenses after redemption. Revisit parked sync writes through the existing requeue mechanism with fresh limits. An interrupted refresh must remain recoverable without a second grant.
- Reuse pricing API limits and prices. Filter personal plans; do not expose Fleet features through a personal-plan comparison. Follow existing app localization and display only shipped capabilities.
- Provide loading, offline/cached pricing, retry, verification-required, invalid/unavailable code, exhausted campaign, previously redeemed promotion, ineligible account, active-gift, and success states. Server failures must not imply that an unconfirmed gift was activated.

## Existing contract conflicts to resolve

- `mobile/AGENTS.md` and production scope describe plans as admin-managed and disallow inventing purchase UI. This release explicitly permits informational pricing and gift redemption while retaining the paid-checkout exclusion.
- `architecture/feature-gating.md` describes a seven-day billing grace window and rolling pre-billing licenses. Gift access must end at its own deadline without that billing grace. Existing `period_end` is currently documented as display-only in mobile claims; simply filling it will not enforce expiry.
- Existing clock rollback handling accepts limitations against deliberate device-clock manipulation. Do not claim tamper-proof real-time offline expiry. Retain the established threat model, enforce the signed deadline against trusted app time, and enforce server time on connected operations.
- `docs/pricing.md` includes future features and billing concepts. It must not be copied wholesale into this release's screen or treated as evidence that checkout exists.

## Implementation sequence (completed)

1. Reconcile production scope and contracts; define schema, redemption API, admin API, grant provenance, and expiry semantics.
2. Implement backend promotion management, atomic redemption, audit history, effective-plan resolution, and gift-aware license issuance.
3. Add AutoX Admin promotion creation, batch generation, shared-code configuration, history, and disable actions.
4. Add mobile pricing, redemption, status/expiry display, Settings and gate entry points, localization, and entitlement refresh.
5. Validate expiry online/offline, concurrency and retry behavior, and downgrade behavior across sync, sharing, vehicles, and storage.

## Acceptance scenarios

- Verified Free account redeems a valid Lite/Standard code and receives the configured duration starting at server redemption time.
- A code redeemed just before the promotion deadline grants the full duration; attempts at or after the deadline fail without consuming capacity.
- Two accounts race for one single-use code or the final shared-code slot: exactly one succeeds.
- Concurrent requests by one account cannot produce overlapping gifts or multiple redemptions of a promotion.
- Unverified, non-Free, Driver, and active-gift accounts cannot redeem; failed attempts leave codes/capacity unchanged.
- A second code from the same promotion remains unusable by that account even after its first gift expires; another promotion is eligible after expiry.
- A response lost after successful redemption can be retried/reconciled without a duplicate grant.
- Disabling a campaign blocks subsequent redemptions and leaves existing grants intact.
- Expiry applies on the server and on an offline device using trusted time, including while the screen remains open and after app resume.
- Over-limit accounts retain existing record access and active shares after expiry; forbidden additions/uploads fail consistently locally and server-side, without losing local pending data.
- Admin-assigned access is not accidentally removed by stale gift-expiry processing.
- Pricing and redemption entry points are available in personal mode and absent in Driver mode; no paid checkout is presented.


## Validation and rollout

- Backend: full existing suite plus initial gift coverage passed (92 tests); expanded promotion integration coverage passed (6 tests), including Driver rejection and preservation of over-limit records/shares after expiry.
- Mobile: 31 focused tests pass for gating, exact expiry, issuer/account checks, account-scoped caches, persistent retry IDs, and English/Burmese pricing UI at 375 px. Full-project analysis encounters pre-existing generated iOS Firebase example dependency errors and existing unrelated warnings; changed feature sources are analyzed separately.
- AutoX Admin: generated API types, TypeScript, ESLint, and production build pass.
- Apply migration `0026_promotions.sql` through the existing API migration runner before serving new endpoints. Deploy API before updated clients.
- Configure the existing license signing environment and ship its matching public key in `mobile/assets/license_keys.json` (currently empty). Do not distribute the private key. Without the matching key, redemption can be confirmed server-side but mobile local limits cannot unlock.
- Email verification must be configured for unverified users to become eligible. The gift API always requires verified email, independently of legacy sharing verification flags.
- Complete real-device acceptance with a configured signing key: redeem, reopen offline, expire, reconnect, and confirm existing data/shares survive. No production deployment or signing-key changes were performed in this implementation session.


## Visual refinement — 21 October 2026

Subscription comparison uses a featured, shadow-elevated plan card, explicit tier selection, large price typography, icon-led benefits, and monthly/annual price options. Selection is for comparison only and never activates a paid plan. Annual savings are calculated from live API prices. The current entitlement remains separately labeled. Gift entry, verification, redemption feedback, and access-refresh recovery live on `/pricing/redeem`, which is also guarded against Driver access. All new/redesigned mobile cards use shadow/elevation without permanent outlines, per the design-system and mobile agent contract.
