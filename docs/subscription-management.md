# Subscription management rollout

Implemented locally on 24 October 2026. Production deployment, real-device acceptance, and live reminder scheduling are not performed by this change.

## Admin workflow

Open **Subscriptions** to search customers, inspect admin-issued terms, Google Play states, promotional gifts and legacy assignments. User and organization detail pages embed the same controls. Record confirmed payment or a complimentary grant, review the server-calculated UTC dates, then confirm. Personal plans are Lite/Standard; organization plans are Fleet. Cash references and receipts are optional. A receipt may be recorded as a URL; receipt upload is not introduced.

Open **Plans & Pricing** to publish monthly/annual MMK/USD catalog prices and inspect price history. Benefits stay read-only; Free remains zero. These prices serve the public catalog and direct-sale defaults. Google Play and future Apple prices remain separate.

## Deployment order

1. Back up the database and deploy backend migration `0030_subscription_management.sql` through the existing migration runner. It is idempotent: existing organizations receive `billing_migrated=false`, new organizations default to true, published prices survive restart, and USD defaults are initialized once.
2. Deploy Admin, Fleet Portal, and mobile clients together with the updated API contract. Existing mobile versions do not understand the locked Free vehicle or Fleet read-only license claims. Server enforcement still rejects forbidden writes, but old clients can queue work that cannot sync.
3. Check real signed licenses on Android/iOS devices, particularly offline expiry, account switching, Driver mode, and preserving rejected outbox data. Existing signing keys and email configuration remain necessary.
4. Schedule `npm run billing:reminders` in `backend/` hourly with the same database and mail configuration as the API. No infrastructure schedule is created automatically. This worker is independent of `billing:reconcile` for Google Play. Investigate nonzero failure counts and nonzero exit status.
5. Review existing organizations individually, assign contractual paid terms or explicit complimentary terms, and confirm migration from the organization's subscription section. Confirming migration is permanent; term expiry/revocation does not restore legacy access.

## Operational semantics

- UTC calendar arithmetic with month-end clamping; one day is 24 hours. Paid grace is seven days; complimentary access has no grace. Date previews display exact instants.
- Effective access is evaluated at request time, independent of a cleanup job. Store providers retain their own lifecycle rules.
- Admin-issued personal licenses expire within 24 hours or at the access deadline, whichever comes first. Fleet write permission has its own signed deadline bounded to 24 hours. Connected revocations apply on subsequent requests; offline revocation cannot be instantaneous.
- Managed personal accounts keep one locked editable vehicle after returning to Free. The lock is independent of active-vehicle navigation. An archived/removed selection requires admin correction.
- A new managed term replaces a legacy personal base assignment; subsequent plan-field edits are rejected to prevent bypassing the term lifecycle.
- Reminder records deduplicate successful milestones and serialize against subscriber updates. Delivery is at-least-once across a process crash after external email delivery but before the database commit; no provider idempotency guarantee is assumed.
- No automatic refund, charge, invoice, or outstanding balance is created by a subscription action. Additional upgrade payments are preserved in audit history alongside the original payment.
- Persisted store purchases are never discarded to conceal a conflict. Admin sees overlapping-access reconciliation flags; store restoration remains available.

## Validation

Local validation completed:

- Full backend regression run: 130 tests passed. Subsequent focused subscription coverage: 11 tests passed, including list/preview, migration permanence, price persistence, source conflicts, locked vehicle selection, and reminder deduplication.
- Admin and Fleet Portal production builds passed. Admin lint and TypeScript checks passed after the final UI changes.
- Mobile focused billing, gating, garage, and sync suite: 68 tests passed. Changed core billing/gating analysis passed; full mobile analysis reports existing warnings/style notices and no errors.
- `git diff --check` passed.

Real-device acceptance remains necessary before rollout. Local automated checks do not establish store-console configuration, email deliverability, or production deployment.
