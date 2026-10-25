# Subscription Management and Admin Pricing

Status: implemented locally; regression validation and deployment status are recorded in [rollout notes](../../docs/subscription-management.md).
Date: 24 October 2026.
Surfaces: AutoX Admin, backend API, Fleet Portal, personal mobile app, public pricing site.

## 1. Overview

Provide a central admin view of subscriptions, time-limited access for directly paid customers, complimentary grants, and editable catalog prices. A Fleet organization buying one year directly must receive organization-owned access with an explicit start date and expiry, rather than an indefinite plan assignment.

This document records the approved interview decisions and identifies engineering proposals and unresolved details separately. Implementation resolutions and local validation are recorded below and in the rollout notes. Production deployment remains separate. This release extends the older admin billing exclusions.

### Current implementation evidence

- `backend/src/modules/pricing.ts` reads MMK monthly/annual prices and displayed limits from the database `plans` table. USD display prices and marketing descriptions are defined in code.
- `backend/src/lib/plans.ts` defines Free, Lite, Standard, and Fleet and supplies enforcement limits. Database reference values and the code registry are currently expected to agree.
- Organization creation in `backend/src/modules/admin.ts` assigns `enterprise` and `pending`, without a subscription term in that flow. Product Fleet and the existing organization plan representation require an explicit mapping.
- Google Play personal checkout, verification, subscription state, and expiry are implemented; see [Google Play subscriptions](../../docs/google-play-subscriptions.md). iOS checkout and local payment integrations are future work.
- Promotional gifts exist; see [Mobile pricing and subscription gifts](mobile-pricing-promotions.md). They are distinct from the admin-issued complimentary grants introduced here.
- Existing `changeUserPlan` logic can delete excess shares. That behavior must not be used for the non-destructive subscription downgrades specified here.

## 2. Objectives

- Let admins determine who has access, which plan applies, why access exists, and when it ends.
- Record confirmed direct payments and activate personal or organization subscriptions.
- Make expiry, renewal, corrections, and complimentary extensions predictable and auditable.
- Prevent overlapping personal store subscriptions and admin-issued access.
- Let admins publish catalog price changes without editing source code.
- Preserve customer records and purchased history when terms or catalog prices change.

## 3. Scope

### Included

- Central subscription list and subscription sections on user and organization detail pages.
- Personal Lite/Standard direct-paid terms and Fleet organization direct-paid terms.
- Separate complimentary grants for personal paid tiers and Fleet organizations.
- Admin-selected starts; calendar month/year durations and custom days.
- Renewal, seven-day paid grace, expiry, immediate revocation, and audited date corrections.
- Manual personal Lite-to-Standard upgrades with unchanged expiry.
- Direct-payment records and negotiated price overrides.
- Expiry emails and notices in the relevant customer interface.
- Per-organization migration from existing indefinite access.
- Price-only administration of MMK/USD monthly and annual catalog prices.
- Read-only visibility into existing Google Play subscription data; future provider compatibility.

### Excluded

- Implementing Apple checkout or local payment gateways in this release.
- Editing store prices, billing dates, or store subscriptions through catalog controls.
- Automatic collection, invoices, receivables, debt collection, or automated refunds.
- Automatic proration, store tier replacement, and overlapping personal paid sources.
- Editable plan benefits, quotas, feature flags, arbitrary new plans, or paid Free plans.
- Scheduled catalog price publication and automatic trials for new organizations.

## 4. Personas and authorization

| Actor | Capabilities |
|---|---|
| System admin | View all subscriptions; record direct payments; grant complimentary access; renew, upgrade, correct dates, revoke; migrate organizations; publish prices. |
| Organization admin | View their organization's subscription, renewal information, and notices; export existing records after expiry within existing permissions. Cannot grant or extend access. |
| Organization member or driver | Use organization access within existing role permissions; retain authorized read access after expiry. |
| Personal customer | View own access and expiry, receive notices, choose the one editable Free vehicle after downgrade, and use eligible store checkout. |

All system admins receive management permissions in the first release. Server authorization must enforce these boundaries independently of the UI. Subscription access never bypasses account suspension, organization suspension, membership rules, or data permissions.

## 5. User stories

- As a system admin, I can search a customer and inspect plan, provider, access end, payment records, and action history.
- As a system admin, I can create a Fleet organization, record its annual payment, and activate one year of organization access.
- As a system admin, I can record a direct personal-plan payment without requiring a store purchase.
- As a system admin, I can give a documented complimentary term without falsely reporting revenue.
- As a system admin, I can correct a mistaken date while retaining the original values and reason.
- As a customer, I retain my records after expiry and understand the restrictions and renewal path.
- As a system admin, I can publish new catalog prices and record a negotiated contract price without rewriting past transactions.

## 6. Functional requirements

### FR-01: Subscription visibility

Provide a central subscription list with search by user or organization and filters for plan, source, and status. Support discovery of expiring terms and organizations awaiting migration review.

List/detail data must identify:

- Subscriber type, identity, and linked account or organization.
- Plan and access source: Google Play, direct payment, complimentary grant, promotional gift, or legacy access; accommodate future Apple and local payment sources without showing unimplemented checkout as available.
- Effective access state, start, paid/grant expiry, grace deadline where applicable, and remaining time.
- Store renewal state and latest verified provider status where available.
- Payment records, catalog price snapshot, actual paid amount, override reason, and term history.
- Audit history, including actor, timestamp, action, reason where required, and before/after values.

Show the same subscription details on the related account/organization page. Distinguish provider billing status from effective access: canceled auto-renewal may still leave paid access active. Do not imply an admin can edit store-controlled terms.

### FR-02: Direct payment and activation

An admin selects the personal account or organization, compatible plan, start date, and duration. The start defaults to today and may be future-dated. Offer calendar months/years, including one month and one year, and a custom number of days. Show the exact start and expiry before saving.

Required payment fields: amount, currency, payment date, and payment method. Reference and receipt are optional, including for cash payments. Treat the record as a confirmed external payment; saving does not charge a payment instrument.

Prefill supported monthly/annual purchases from the published catalog. An admin may negotiate a different amount with a required reason. Preserve the catalog amount/version and the actual amount paid. Complimentary access uses its own action and never masquerades as a paid renewal.

Future-dated terms are scheduled and do not unlock operations early. A new organization requires a valid paid or complimentary term before operational access. Organization activation and subscription validity remain separate prerequisites.

### FR-03: Ownership

Fleet subscriptions belong to the organization, cover authorized members and assigned drivers within their roles, survive organization-admin changes, and do not upgrade personal accounts. A personal subscription does not increase organization benefits or storage.

### FR-04: Renewal

- Before paid expiry: append the purchased duration from the current paid expiry, preserving remaining paid time.
- During seven-day paid grace: append from the previous paid expiry because service continued during grace.
- After grace: default the new term start to today; admins retain the agreed start-date selection capability.
- Present resulting dates before confirmation and retain each payment/term relationship.
- An unpaid extension must be an explicit complimentary grant with a reason and expiry, not an unpaid renewal or outstanding balance.

### FR-05: Paid expiry and grace

Direct-paid personal and Fleet terms receive exactly seven days of grace after paid expiry. Normal subscribed operations continue through grace. At grace end, absent another valid access source:

| Subscriber | Result |
|---|---|
| Personal | Return to Free; preserve records and existing shares; enforce Free creation/storage limits and editable-vehicle selection below. |
| Fleet organization | Become read-only; all existing members retain their authorized viewing access; organization admins retain export access. Block new operational activity. |

These grace rules do not add an independent grace period to store subscriptions. Store access follows verified provider lifecycle rules, including provider grace, hold, expiry, and revocation.

### FR-06: Personal Free downgrade

Preserve vehicles, records, and existing shares. Do not delete excess shares on subscription expiry. New vehicles and shares remain constrained by Free limits. Preserve readable/downloadable files and the existing storage policy for quota-reducing actions.

Only one chosen vehicle remains editable on Free; additional vehicles become read-only. The selection remains locked while the customer stays on Free. System admins may correct it with a required reason and audit history. Existing sharing permissions cannot provide a write bypass for an otherwise read-only vehicle.

Proposed interaction detail, not separately approved in the interview: when several vehicles exist and none is selected, keep them readable and require selection before edits; automatically select the sole eligible vehicle when there is only one. Finalize deletion/archive and replacement-selection behavior before implementing this gate.

### FR-07: Complimentary grants

Provide a distinct action with subscriber, compatible plan, start, expiry, and required reason. Record the issuing admin. Do not record revenue or auto-renewal. Expire exactly at the grant deadline without grace: personal accounts return to Free and fleets become read-only unless other valid access applies.

Use this mechanism for explicitly free extensions. Define its relationship to existing paid terms so an extension does not erase purchased history or accidentally shorten paid access.

### FR-08: Personal source exclusivity

Block direct-paid terms and complimentary personal grants while store subscription access remains active. Canceling auto-renewal is insufficient while store-paid access remains valid.

Conversely, block store checkout while direct-paid or complimentary personal access remains active, including applicable paid grace. Show the blocking source and expiry. Retain existing gift/store eligibility safeguards. Enforce rules server-side and handle concurrent checkout/grant attempts without double activation.

Provider verification, restore, and reconciliation must remain available even when new checkout is blocked. If an external provider reports an unexpected purchase, preserve the verified purchase and expose a reconciliation issue rather than silently losing the customer's payment record. Detailed conflict resolution is an implementation prerequisite.

### FR-09: Manual personal upgrades

Allow admin-managed Lite-to-Standard upgrades for directly paid customers, effective immediately with unchanged expiry. Record the additional payment or a required complimentary-upgrade reason. No automatic proration. Preserve the preceding plan and payment history. Other mid-term plan changes are not approved by this interview.

### FR-10: Corrections and revocation

Allow date corrections and revocation for admin-issued terms. Require a reason and preserve original values and change history. Validate corrected dates and show the resulting access effect before confirmation.

Revocation removes the revoked term's access immediately, with no grace. Resolve any other valid source before applying Free/read-only restrictions. Revocation neither issues a refund nor records that money was refunded. Store-controlled dates remain read-only.

### FR-11: Reminders and customer notices

For direct-paid subscriptions, send email and show notices in the relevant personal/Fleet interface:

1. Seven days before paid expiry.
2. When paid grace begins.
3. When restrictions begin after grace.

Recipients are the personal customer or current organization admin. Include plan, exact expiry/grace dates, expected restrictions, and the available renewal/contact route. These reminders do not apply to store subscriptions. Re-evaluate reminders after renewal, correction, or revocation so stale messages do not describe an obsolete term. Deduplicate retries.

For short terms created after the pre-expiry threshold, proposed behavior is an immediate current-status notice rather than sending a backdated reminder. Complimentary reminder schedules remain unspecified; never describe complimentary access as having paid grace.

### FR-12: Existing-organization migration

Existing Fleet organizations retain their current access temporarily while admins review and assign the correct paid or complimentary terms. Mark these organizations visibly as awaiting review; do not invent payment history.

Migration is per organization. An admin assigns the appropriate term and explicitly confirms migration after reviewing the resulting access dates. From that point, subscription enforcement applies permanently and the legacy exemption cannot return through ordinary edits, expiry, or revocation. New organizations never receive this exemption.

### FR-13: Plans & Pricing

Show Free, Lite, Standard, and Fleet with monthly and annual MMK/USD catalog prices. Benefits, limits, and features are read-only. Free remains zero.

Admins edit and publish price changes. Publication immediately affects the authoritative pricing API, frontend catalog displays on their next fresh fetch, and defaults for new direct purchases and renewals. Invalidate applicable caches; cached/offline views must not be treated as current purchase quotes.

Persist USD prices alongside managed catalog prices rather than leaving them hardcoded. Separate editable commercial prices from code-controlled benefit enforcement. Existing seed/migration/sync checks must not overwrite published edits or require runtime prices to equal code defaults.

Store localized checkout prices remain provider-controlled. Catalog edits do not change Google Play prices or future Apple prices. Do not display a catalog amount as a confirmed store charge.

Preserve existing paid terms, historical payment amounts, and price snapshots. Record who changed prices, when, and old/new values. Show a publication confirmation with the proposed changes. Concurrent edits must not silently overwrite each other.

## 7. Primary workflows

### Sell a new Fleet annual subscription

1. Create organization and organization-admin account through the existing provisioning flow.
2. Open its subscription section and select Record direct payment.
3. Select Fleet, one year, and the contractual start date, defaulting to today.
4. Review catalog price; record actual amount, currency, date, and method. If negotiated, provide an override reason.
5. Review exact expiry and grace deadline, then save.
6. Unlock operations when both organization status and term validity permit; show subscription details to the organization admin.

### Inspect an Android subscriber

1. Search the user in the subscription list.
2. View verified Google Play plan, provider status, expiry, and renewal state.
3. Inspect access and event history without editing store dates.
4. Explain why direct-paid/complimentary personal activation is blocked while store access remains active.

### Publish a catalog price

1. Open Plans & Pricing and edit a paid plan's monthly/annual MMK or USD price.
2. Review the old/new values and confirm publication.
3. Serve the published prices through catalog APIs and direct-sale defaults.
4. Retain historical sales and store pricing unchanged.

## 8. Validation and time semantics

Approved: admin-selected starts, calendar durations or custom days, explicit expiry preview, seven-day paid grace, no complimentary grace, and immutable payment history.

Engineering requirements/proposals to finalize in API design:

- Use authoritative server time and persist UTC instants; display explicitly labeled local dates/timezones.
- Use half-open access intervals: active at start, expired at end; grace begins exactly at paid expiry and ends at its deadline.
- Define the business timezone and whether a date-only start means local midnight. Do not silently inherit the server timezone.
- Define month-end/leap-day clamping for calendar arithmetic and whether custom days/grace are calendar days or exact 24-hour periods.
- Require positive durations and expiry after start. Validate currency precision and nonnegative prices; paid records should represent actual positive receipts, with free access routed to grants.
- Do not silently derive custom-day prices from a monthly rate; define the quoting basis and capture the agreed amount explicitly.
- Revalidate price version and subscriber eligibility at confirmation. A concurrent catalog change should prompt review rather than silently changing a confirmed amount.
- Define allowed backdating and its effect on reminders and immediate expiry; past dates must not imply access existed historically when it did not.

## 9. Data and consistency requirements

Maintain separate concepts for catalog price versions, payment records, subscription terms/grants, effective access, provider state, migration state, and audit events. Exact schema and endpoint names are implementation design work.

- Every term identifies its subscriber, plan, source, start/end, state, and related payment or grant reason.
- Preserve historical facts via audit/version records rather than overwriting the only copy.
- Record term creation, renewal, upgrade, correction, revocation, migration confirmation, price publication, and Free-vehicle corrections.
- Make mutation retries idempotent and subscriber updates concurrency-safe. Double-clicking or retrying after a lost response must not create duplicate payments/terms.
- Compute expiry correctly even if background cleanup is delayed. Reconciliation must not overwrite a newer grant or renewal.
- Refresh effective permissions, caches, tokens, and signed mobile licenses after access changes. Define the maximum offline delay for admin revocation before rollout; do not promise instantaneous revocation on disconnected devices.
- Enforce restrictions across mobile, Fleet APIs, shared access, uploads, exports, and sync. Preserve queued offline records when a write is rejected, explain the restriction, and allow recovery after renewal.
- Payment-record access and optional receipt access require the appropriate authorization; do not expose provider purchase secrets in admin lists or logs.

## 10. Error states

Provide actionable messages for active-store conflicts, active-admin-term checkout conflicts, incompatible subscriber/plan, invalid dates/durations, missing payment or override reason, concurrent edits, stale prices, duplicate requests, failed saves, and failed entitlement refresh.

A failed or unknown save must not claim activation. Support fetching the confirmed result after retry. Distinguish a saved payment/term with a pending client refresh from a transaction that never committed. Email failure must not roll back valid paid access; retries must remain observable and deduplicated.

## 11. Acceptance criteria

1. An admin can find a personal subscriber or organization and see source, effective status, dates, payments, and history on both list and detail surfaces.
2. A new Fleet organization without a valid term cannot perform operational work. A future term does not unlock it early.
3. An annual direct purchase shows its exact calendar expiry before saving, records required payment details, and covers the organization independently of its admin's personal plan.
4. Early renewal preserves remaining paid time; grace-period renewal extends from prior paid expiry; post-grace renewal defaults to today.
5. At direct-paid expiry, access continues for seven days. At grace end, personal access becomes Free and Fleet becomes read-only without deleting records.
6. Existing Fleet members retain only their authorized read access; organization admins can export. Operational writes fail server-side after grace.
7. Personal excess vehicles and shares survive downgrade. Only the chosen Free vehicle is editable; swapping requires an audited admin correction.
8. Complimentary access has a required reason, no payment record, and no grace. Unpaid extensions are represented as complimentary grants.
9. Direct-paid and complimentary personal grants are blocked while store access is active; canceling auto-renewal does not bypass the rule. New store checkout is likewise blocked during admin-issued access/grace.
10. A manual Lite-to-Standard upgrade is immediate, keeps expiry, and records added payment or a complimentary reason.
11. Date corrections retain before/after history. Revocation takes effect without grace on connected authorization checks and preserves other valid access and payment history.
12. Direct-paid reminders are sent at the three agreed milestones to the correct recipient, without duplicates or obsolete expiry messages after renewal.
13. Existing organizations retain legacy access until explicit per-organization migration; migrated organizations cannot regain that exemption. New organizations are never exempt.
14. Admin publishes MMK/USD prices; fresh catalog responses and new sale defaults reflect them while benefits remain read-only and Free remains zero.
15. Negotiated prices require a reason and preserve both the catalog snapshot and actual payment. Historical transactions and purchased terms remain unchanged after catalog edits.
16. Android checkout continues using provider prices. Catalog publication does not modify provider billing.
17. Unauthorized users cannot perform billing mutations or inspect another subscriber's records. Retries and concurrent requests do not create duplicate access or payments.
18. Expiry remains enforced with delayed jobs, stale client sessions, and offline license boundaries; rejected offline writes are retained for recovery.

## 12. Dependencies and contract reconciliation

Before implementation, align [production scope](../production-scope.md), [Admin](admin.md), [Fleet Management](fleet-management.md), [pricing reference](../../docs/pricing.md), [feature gating](../../architecture/feature-gating.md), and the API/schema contracts with this release.

Specific conflicts to resolve:

- Older admin/scope documents exclude billing; distinguish this planned release from as-built behavior.
- The gift FRD currently permits continued editing of existing records after expiry. This interview requires one editable vehicle on return to Free. Decide explicitly whether existing promotional gifts adopt that new policy or retain their old expiry contract; do not silently change it.
- Existing manual plan changes can remove excess shares; this release requires preservation.
- Organization `enterprise` values and the catalog `fleet` tier must map consistently.
- Editable catalog prices must no longer be coupled to immutable registry price assertions.
- Mobile signed-license/gating contracts must express scheduled access, grace deadlines, and the selected editable vehicle as needed.

## 13. Remaining implementation decisions

These details were not independently approved and must be resolved before shipping their affected paths:

- Business timezone, date-only boundaries, month-end arithmetic, and backdating rules.
- Missing/deleted/archived Free-vehicle selection and compatibility with promotional gift expiry.
- Scheduling complimentary extensions alongside paid terms, and renewal after such an extension.
- Handling external store purchases discovered despite checkout blocking, future scheduled personal terms, and unresolved provider states.
- Custom-duration quotes, supported payment method values, and receipt storage/access details.
- Maximum offline revocation latency and safely upgrading older clients.
- Reminder behavior for short/backdated terms and any complimentary reminder policy.

These do not reopen the approved business decisions; they identify cases that the interview did not specify.

## 14. Validation, rollout, and success measures

Implement backend contracts and enforcement before exposing admin actions. Validate lifecycle boundaries, authorization, source conflicts, concurrent mutations, renewal calculations, historical-price preservation, and offline/sync behavior. Exercise the full annual Fleet sale and personal downgrade flows across the affected interfaces.

Deploy the catalog migration with existing prices preserved. Roll out new-organization enforcement alongside the legacy review marker and per-organization migration controls. Do not bulk-expire existing organizations by treating missing terms as unpaid.

Monitor organizations awaiting review, expiry/grace transitions, blocked overlap attempts, failed reconciliation, reminder delivery, price publications, and admin corrections. Measure whether admins can complete a direct annual sale and locate a customer's subscription without database intervention. Numeric targets remain to be set; no implementation or test completion is claimed here.

## 15. Future enhancements

Apple in-app subscriptions, local payment integrations, provider reconciliation improvements, automated quoting/proration, scheduled catalog publication, and finer billing-admin permissions may be designed separately. Editable benefits and automatic collection require their own requirements and are not implied by this document.


## Implementation resolutions — 24 October 2026

- Forms use explicitly labeled UTC instants. Calendar months/years clamp to the last valid day; custom days and grace use exact 24-hour durations. Expiry is exclusive.
- One active owned vehicle may be selected automatically on a server write when no selection exists; multiple vehicles require explicit selection. Deleting/archiving the selected vehicle does not silently unlock rotation; an admin correction is required.
- Existing promotional gifts retain their historical expiry contract for accounts not enrolled in managed billing. Admin-issued terms enroll personal accounts in managed billing. Active promotional gifts block new admin-issued personal terms.
- Scheduled personal terms also block new store checkout. Unexpected externally verified store purchases remain recorded and overlapping admin access is flagged for reconciliation; effective access uses the highest applicable plan.
- Manual quotes for custom durations require a negotiated-price reason. Payment methods are bounded text; optional receipts are reference URLs, not a new file-upload system.
- Existing legacy personal assignments are visible. Issuing a managed term replaces the indefinite base plan with Free plus term-derived access. Admin plan-field changes are rejected afterward; use subscription actions.
- Connected revocation applies on subsequent authorization checks. Admin-issued personal and Fleet offline access is bounded to 24 hours and the actual access deadline. Old clients must be upgraded to honor the new mobile restrictions.
- Short terms receive the current applicable reminder on the next scheduled reminder run. Renewal/extensions suppress obsolete prior-term reminders. Email transport is at-least-once across a crash after delivery but before database commit; ordinary retries/concurrent runs deduplicate persisted milestones.
- Complimentary extensions should start when paid service/grace ends; overlapping paid dates are rejected. A renewal conflicting with an extension requires an explicit audited correction before recording the new term.
