# Currency Selection — Implementation Plan

**Date:** 29 October 2026  
**Status:** Implementation started — additive backend currency storage and read contracts implemented locally; feature activation remains pending.  
**Requirements:** [Currency Selection FRD](../product/frd/multi-currency.md)

## 1. Delivery objective

Implement USD/MMK/THB/CNY selection for personal garages and fleet organizations, persistent currency on operational monetary records, locking after the first monetary creation, and safe historical/offline behavior. No automatic conversion. Subscription pricing and payment currencies remain separate.

Deliver this as a coordinated API, Fleet Portal, and mobile change. Do not enable additional currency choices while any supported client can silently relabel history or omit currency from queued writes.

## 2. Findings from the current code

| Area | Current implementation | Required change |
|------|------------------------|-----------------|
| Backend scope | `backend/src/db/schema.ts` has no operational currency/lock columns on users or organizations. | Add authoritative personal/organization settings and durable lock state. |
| Monetary storage | Vehicles have purchase prices; service records and items, fuel logs, expenses, and work orders have monetary fields. | Inventory all fields, give each independent monetary event a currency, and propagate it through linked representations. |
| Fleet analytics | `backend/src/modules/fleet-analytics.ts` stores `settings.analytics.currency`, accepts many currencies, and locks on reporting confirmation. | Use organization operational currency; preserve timezone independently and replace the reporting-only confirmation flow. |
| Analytics history | Migration `0022_fleet_analytics.sql` captures JSON payloads in `analytics_records` and tenure snapshots. | Backfill archived payloads as well as live tables; snapshots must preserve record currencies. |
| Mobile preference | `AppCurrency` in `features/settings/domain/entities/user_preferences.dart` currently contains only MMK; `currencyProvider` reads local preferences. | Introduce all four currencies and resolve effective currency by account/organization/vehicle context. |
| Mobile history | Several expense, service, dashboard, and stats screens format amounts with `currencyProvider`. | Historical amounts use record currency; totals use scope currency and expose exclusions. |
| Mobile persistence | Drift schema version is currently 24. | Add an incremental migration and regenerate code; never edit generated Drift files manually. |
| Mobile synchronization | Personal and organization sync are separate, with account-scoped databases/outboxes. | Carry intended currency and revision metadata through both paths, preserving recoverable conflicts. |
| Fleet transfers | `fleet-operations.ts` stores service snapshots with amount but no currency. | Include immutable currency in snapshots and preserve currencies through transfer. |

Paths and version numbers above reflect inspection on the plan date. Recheck migration numbering and concurrent changes before implementation.

## 3. Engineering decisions to use

These are proposed implementation choices for the agreed FRD, not claims about existing behavior:

- Default new personal onboarding and fleet setup selectors to Myanmar Kyat (MMK). Persist the confirmed choice; preserve existing saved currencies. Fleet preselection is not setup completion and must not bypass the monetary-entry gate.
- Store a constrained currency code and nullable `currency_locked_at` on each personal account and organization. New organizations start with no currency; existing scopes migrate to MMK.
- Use explicit immutable record currency. For a vehicle's purchase amount, use `purchase_currency` so a historical purchase does not accidentally dictate the currency of future expenses.
- Service item costs inherit the service event's currency. Derived expense/service representations of one event retain the source currency and do not count as independent payments.
- Lock on any newly saved operational monetary event, including an allowed zero amount or vehicle purchase price. Null cost fields and drafts do not lock. Inherited records and corrections to them do not lock the recipient.
- Allow currency correction only online against authoritative state. Offline cost creation remains supported and locally locks currency correction immediately.
- Use exact decimal arithmetic for validation and totals. Proposed final-cost rounding is decimal half-up; allow up to six decimal places for computed/input unit prices. Keep current quantity precision unless a separate requirement needs it.
- Preserve legacy fractional MMK values exactly. Render their full precision on detail/edit/export views; allow unchanged legacy values on unrelated edits, but validate newly entered/replaced amounts under the new rules. Do not round migrated storage.
- Require explicit intended currency on new-client monetary writes. Missing currency must not be silently assigned after multi-currency activation. Use a coordinated client compatibility gate rather than an unsafe permanent MMK fallback.
- Currency mismatch is a recoverable conflict, distinct from authorization failure and ordinary network retry. An offline correction must involve explicit user entry and confirmation; never treat matching digits as automatic conversion.

Before coding, record these choices in the FRD/API contract, especially rounding, zero-cost locking, purchase-price treatment, and legacy exceptions. If the data inventory reveals incompatible evidence, update the plan before migrations are written.

## 4. Phased delivery

### Phase 0 — Inventory and contract

**Primary files:** `backend/src/db/schema.ts`, `backend/src/modules/{owner,vehicles,sync,organization-sync,fleet,fleet-operations,fleet-analytics,auth,social-auth,me,profile}.ts`, `backend/src/lib/serialize-records.ts`, `architecture/openapi.yaml`.

1. Build a field/write-path matrix for purchase prices, expenses, fuel/charging costs, service totals/items, work-order completion, linked expense generation, imports, workshop writes, and admin-supported paths.
2. Trace create, update, duplicate replay, transfer, archive, and historical snapshot behavior for every monetary event.
3. Identify all personal/social/admin account creation paths and fleet setup/session payloads.
4. Inventory legacy fractional MMK, deleted records, transfer provenance, analytics currency settings, snapshot payloads, and pending local operations using synthetic or sanitized fixtures first.
5. Define proposed currency state reads/updates for personal accounts and organizations in OpenAPI. Include currency, locked state, and a setting revision/version for stale writes.
6. Define response codes for selection required, currency locked, currency mismatch, invalid precision, immutable historical currency, and incompatible clients. Include current state in conflict responses where authorized.
7. Define effective vehicle context metadata for collaborators and drivers without exposing unrelated account data.

**Exit:** Every amount field has an owner, currency source, lock behavior, serializer, aggregation consumer, and migration rule. No unknown write paths remain.

### Phase 1 — Schema and migration

**Primary files:** `backend/src/db/schema.ts`, a new numbered migration in `backend/drizzle/`, migration registration under `backend/src/db/`, migration tests.

1. Add scope currency/lock fields and event currency fields with supported-code constraints.
2. Backfill all existing operational amounts and retained JSON snapshots as MMK without changing their numerical values.
3. Initialize existing accounts/organizations to MMK; leave newly provisioned organizations unselected.
4. Determine existing locks from monetary creation provenance, including collaborators/drivers. Exclude inherited history from the recipient lock. Deletion must not later clear a lock.
5. Preserve analytics timezone. Replace the old analytics currency authority with the organization currency. Flag any legacy non-MMK analytics setting for review rather than treating it as evidence that stored values were converted.
6. Ensure capture triggers and transfer snapshots include currency for future records and retain historical values.
7. Identify provenance gaps explicitly; do not infer original ownership solely from current vehicle ownership. Resolve gaps before production backfill.
8. Use an additive migration compatible with the staged rollout. Inspect the migration runner because database creation currently applies migrations automatically.

**Exit:** Migration tests cover pristine and populated databases, transfers, snapshots, repeated startup, fractional values, and numerical preservation. Production rollout remains disabled.

### Phase 2 — Backend invariants and all write paths

**Primary files:** a shared operational-currency service under `backend/src/lib/`; modules and serializers from Phase 0.

1. Centralize scope resolution, supported codes, decimal validation, setting changes, creation validation, and lock acquisition.
2. Use one transaction to validate effective ownership/currency, lock the scope, and save the monetary event. Serialize concurrent setting changes against that same scope row; revalidate ownership where transfers race with writes.
3. Wire email/social signup currency and personal state reads/updates. Returning users retain existing currency; login preferences never overwrite it.
4. Wire organization setup with Fleet Admin authorization. Block monetary creation before selection across every API path, including driver, workshop, import, and sync paths.
5. Persist and serialize record currency. Historical updates reject currency mutation; editing an inherited event never substitutes the recipient's setting.
6. Update linked records without duplicate charges or inconsistent currency. Preserve current authorization, revision, and review rules.
7. Replays of already accepted operations return their saved result without creating another event or relocking a new owner. New stale operations fail safely.
8. Apply the same contracts to direct REST and both sync pipelines, including organization review acceptance.

**Exit:** API integration tests prove no bypass through alternate routes, duplicate retries, concurrent first creates, historical edits, and ownership transfer races.

### Phase 3 — Fleet Portal setup and cost surfaces

**Primary files:** `fleet-portal/src/app/(fleet)/`, portal session/context helpers, generated API types.

1. Add first-login currency setup for Fleet Admin after existing mandatory account gates, with Myanmar Kyat (MMK) preselected. Require confirmation of MMK or another supported choice. Other roles see a clear setup-needed state.
2. Allow authorized pre-lock correction and show a read-only currency after locking.
3. Replace analytics' independent currency selector with organization currency; timezone remains editable under its existing permissions.
4. Show effective currency on all operational forms. Show record currency on history, detail, review, and transfer views.
5. Display backend setup, lock, mismatch, and precision errors with recovery guidance.
6. Regenerate API types using the portal's existing `gen:api` script; update other generated consumers of OpenAPI as needed.

**Exit:** Fleet Admin can configure/correct currency, other roles cannot override it, costs cannot bypass setup, and historical details are not relabeled.

### Phase 4 — Mobile storage, domain, and sync

**Primary files:** `mobile/lib/core/database/{tables,app_database}.dart`, `core/sync/`, relevant feature entities/mappers/repositories, `core/storage/entry_preferences.dart`.

1. Add an incremental Drift migration for record currency and cached scope state. Backfill legacy rows and queued monetary payloads as MMK, preserving amounts.
2. Extend domain entities and DTOs for record currency and effective vehicle currency/lock metadata. Keep shared context contracts in `core/` or domain interfaces, respecting mobile layer rules.
3. Cache authoritative personal/organization state in account-scoped local storage. UI reads local repositories; network results populate that cache.
4. On local monetary creation, persist amount, intended currency, setting revision, and outbox operation atomically; record the local pending lock.
5. Carry currencies through push, pull, change application, organization review, and linked records. Never use a global preference to reconstruct old payloads.
6. Park currency mismatches as actionable conflicts, preserving the draft and original currency. Continue unrelated valid operations. Ordinary retry must not clear the conflict.
7. Add an explicit repository/use-case operation to resolve the draft with a reviewed amount/current context and safely supersede the failed operation without duplicate creation.
8. Preserve account/organization isolation across logout and account switches. A stale pull must not overwrite an unresolved local draft.

**Exit:** Drift upgrades, offline writes, stale-setting conflicts, transfer conflicts, conflict resolution, retries, and account-switch tests pass.

### Phase 5 — Mobile onboarding, settings, and monetary UI

**Primary files:** auth introduction/signup/session flows; settings entities/providers/screens; garage, expenses, fuel, maintenance, dashboard screens; `core/units/money_format.dart`; English/Myanmar localization files.

1. Add four-currency selection to first-time onboarding with Myanmar Kyat (MMK) preselected, and carry the confirmed choice through email/social signup. Existing-account login must ignore entry-screen preferences and preserve saved currency.
2. Show settings correction only while unlocked and online, respecting pending local monetary records. Drivers see organization currency as read-only.
3. Resolve creation currency from the active vehicle owner or organization. Separate scope currency providers from historical record formatting.
4. Apply input precision to final costs, support unit-price precision, and explain manual equivalent entry for foreign purchases.
5. Format historical values with saved currency, including retained fractional MMK exceptions and purchase price history.
6. Provide the recoverable sync-conflict screen/form with original amount/currency, current currency, and explicit re-entry confirmation.
7. Regenerate localization and model/database code. Verify narrow screens, light/dark themes, and English/Myanmar against existing design tokens.

**Exit:** Personal, collaborator, and driver journeys work online/offline without displaying a historical amount under a different code.

### Phase 6 — Totals, analytics, exports, and support views

**Primary files:** mobile stats calculators/repositories and dashboard/expense summaries; `backend/src/lib/fleet-analytics.ts`; analytics module and snapshots; existing export serializers; Web Admin monetary detail views.

1. Filter monetary aggregation by effective scope currency while retaining all authorized history.
2. Return exclusion metadata (count and currency codes) with totals; show clear explanations in summaries, charts, metrics, and existing reports.
3. Preserve existing aggregation semantics: Dashboard remains expenses-only; do not introduce double counting of service/fuel source events and generated expenses.
4. Keep nonmonetary distance and fuel calculations independent of foreign-cost exclusion. Cost-based metrics must disclose that they represent included costs only.
5. Include each record's currency in existing exports and preserve it in drill-downs/snapshots. Never label all exported rows with one report currency if history is mixed.
6. Remove hardcoded operational currency labels and viewer-preference formatting across supported surfaces; leave subscription pricing behavior intact.

**Exit:** Mixed-currency fixtures produce correct totals, exclusions, cost metrics, historical detail, and exports after transfers and corrections.

### Phase 7 — Integration, release, and documentation

1. Map automated and manual checks to all FRD acceptance criteria; complete the verification matrix below.
2. Update affected FRDs, OpenAPI/generated types, data-model/sync documentation, `mobile/AGENTS.md`, production scope, and as-built status only to match verified implementation.
3. Build releases with multi-currency activation disabled until migrations, API validation, portal, and mobile are compatible.
4. Stage migration on a production-shaped sanitized dataset. Compare row counts, exact amounts, currency coverage, lock attribution, and analytics snapshot consistency.
5. Ship capable clients and enforce a minimum compatible client/version on monetary writes before enabling non-MMK selection. Preserve legacy offline drafts and explain upgrade requirements.
6. Enable progressively and monitor currency conflicts, invalid writes, excluded-history metadata, and setup failures without logging sensitive notes or payloads.

**Exit:** End-to-end acceptance passes and deployment readiness is documented. Implementation completion is separate from production deployment approval.

## 5. Verification matrix

| Suite | Required coverage |
|-------|-------------------|
| Migration | Existing MMK amounts unchanged; empty/new scopes; inherited/deleted history; fractional values; archived analytics payloads; provenance gaps. |
| API | Four codes, permissions, setup gate, durable locking, precision, concurrent writes/settings, transfer races, linked events, REST/sync parity, idempotency. |
| Mobile unit/database | Exact money calculations, record formatting, Drift upgrades, queued legacy operations, effective shared/fleet context, aggregate exclusions. |
| Mobile sync/integration | Stale currency, retained drafts, explicit resolution, no duplicate operation, offline lock, pull conflict, account isolation. |
| Portal | First login, role-specific setup, pre-lock correction, locked settings, historical labels, analytics and CSV exclusions. |
| Regression | Sharing and edit permissions, driver review rules, transfers, subscription/pricing behavior, dashboard counting, nonmonetary statistics. |
| Manual UI | MMK preselection on personal/fleet setup, explicit confirmation, existing currency preservation; all four currencies; English/Myanmar; dark/light; narrow screens; account/device switches; offline reconnect. |

Use the existing backend Vitest/PGlite test harness; add real PostgreSQL concurrency checks for transaction guarantees that an in-memory fixture cannot prove. Run `npm test` and `npm run build` in `backend/`; `npm run lint` and `npm run build` in affected Next.js apps; Flutter analysis and relevant tests in `mobile/`, followed by the existing regression suite. Regenerate types/code before checks. Do not run production migrations as part of tests.

## 6. Rollback and operational limits

- Before activation, disable the feature and retain additive schema if a release fails.
- After non-MMK data exists, do not roll back to a client/server that ignores record currency. Disable new writes/selection as needed while deploying a compatible fix; preserve reads with accurate labels.
- Never recover by relabeling or converting stored values, deleting drafts, clearing durable locks, or dropping currency columns.
- Keep a migration backup and reconciliation report. Production data access and deployment are separate execution steps, not implied by writing this plan.

## 7. Work sequence and progress tracking

| Order | Deliverable | Depends on | Status |
|-------|-------------|------------|--------|
| 0 | Field inventory and API contract | FRD | In progress — monetary storage/read inventory below; mutation/state contracts pending |
| 1 | Schema and legacy migration | 0 | Partial — additive fields, MMK/snapshot backfill, source currency propagation; lock attribution pending |
| 2 | Backend state and monetary invariants | 1 | Not started |
| 3 | Fleet setup and forms | 2 | Not started |
| 4 | Mobile persistence and conflict handling | 2 | Not started |
| 5 | Mobile onboarding/settings/forms | 4 | Not started |
| 6 | All totals, history, exports, support views | 2–5 | Not started |
| 7 | Integration, documentation, staged release | 0–6 | Not started |

Keep each phase in reviewable commits with its tests. No phase is independently ready for multi-currency activation until every supported read/write path honors the contract. This plan does not authorize or start parallel agent work.


## 8. Implementation log — 29 October 2026

First slice, on `codex/currency-selection`:

- Added migration `0031_operational_currency.sql` and Drizzle fields for personal/organization currency and lock timestamp, record currency on expenses/service/fuel/work orders, and purchase currency on vehicles.
- Existing operational monetary columns default/backfill to MMK without rounding. Existing organization settings initialize to MMK exactly once; new organizations remain unselected across restart.
- Historical analytics and transfer JSON snapshots receive MMK currency metadata without modifying numerical values or array order. New transfer snapshots include record currency.
- Added database protection against changing the currency of existing monetary events and a source-currency trigger for derived service/fuel expenses. This is important because earlier accounting migrations recreate their functions on every boot.
- Expense, fuel, service, purchase, work-order, and recent-service serializers now include currency. OpenAPI read schemas and Fleet Portal/Web Admin generated types were updated for the typed record contracts.
- Added exact decimal helpers for final costs, fuel multiplication with six-decimal unit prices/half-up final rounding, and totals with foreign-currency exclusion metadata. These helpers are tested infrastructure; existing entry/aggregation paths are not yet wired to them.

### Remaining activation prerequisites

The feature is **not ready for activation or production release**. Currency selectors/state endpoints are not implemented. Lock timestamps have storage only: historical lock attribution, first-write lock enforcement, and all mutation validation remain pending. No production data was migrated during development. No existing user choice is exposed for non-MMK yet.

Before activation, complete legacy provenance reconciliation, all direct/sync/workshop/import write paths, server state endpoints and client compatibility checks, Fleet Portal setup, mobile Drift/outbox/onboarding/forms, all monetary aggregation/exclusion UI, and final integration tests. Existing client formatting and fleet analytics reporting settings still need replacement.

### Monetary field inventory

| Event / representation | Currency storage added | Write and read follow-up |
|------------------------|------------------------|--------------------------|
| Vehicle purchase price | `vehicles.purchase_currency` | Personal/fleet creation and edits; sync; preserve on transfer; scope lock on first price. |
| Expense | `expenses.currency` | Owner/organization CRUD, sync, summary calculators, imported entries, local entities. |
| Service total | `service_records.currency` | Owner/organization routes, driver/workshop/WO completion, sync and local entities. |
| Service item cost | Inherits parent service currency | Validate line cost with parent currency; no independent event or lock. |
| Fuel/charging cost | `fuel_logs.currency` | Owner/organization and legacy driver routes, sync, unit-price calculations, local entities. |
| Work-order completion cost | `work_orders.currency` | Completion validation and source-linked service creation must share one currency. |
| Derived expense | Copies source service/fuel currency via trigger | Preserve existing accounting identity and historical corrections. |
| Retained fleet analytics payload | JSON `currency` | Filter monetary aggregates and add exclusion metadata; retain nonmonetary records. |
| Transfer service/vehicle snapshots | JSON `currency` / `purchase_currency` | Render original codes in portal and buyer history. |
| Subscription payments/catalog | Existing independent currency fields | Excluded from this feature. |

### Validation of the first slice

- Backend TypeScript build passed.
- Full backend Vitest suite passed: 29 files, 138 tests.
- After strengthening linked-event currency protection, the affected migration/money tests passed again: 3 files, 8 tests; backend build passed again.
- `git diff --check` passed. No production database or deployment was touched.
