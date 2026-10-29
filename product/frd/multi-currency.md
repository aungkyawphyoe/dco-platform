# Currency Selection — Phase One

**Product:** AutoX Platform  
**Date:** 29 October 2026  
**Status:** Requirements agreed through grilling; implementation started (backend storage foundation only). Full feature and activation pending.  
**Surfaces:** Mobile Personal and Driver, Fleet Portal, API, local storage/sync, and Web Admin support views.

**Implementation plan:** [Phases, verification, and rollout](../../docs/multi-currency-implementation-plan.md).

## 1. Overview and objectives

Support USD, MMK, THB, and CNY for vehicle costs without exchange-rate services or automatic conversion. Each personal garage and fleet organization has one currency for new monetary records. Every saved monetary record retains its own currency permanently, preserving its meaning through sharing, ownership transfers, corrections, and offline synchronization.

This FRD replaces the currency-as-display-preference behavior described in Expenses, Stats, and the existing Settings documentation when implemented. It does not claim that the current application already follows these rules.

Objectives:

- Let users choose the currency in which they track vehicle costs.
- Keep routine entry and totals in one currency per personal garage or organization.
- Never silently relabel or combine amounts in different currencies.
- Preserve existing data as MMK without changing numerical values.

## 2. Scope and boundaries

In scope: onboarding and pre-lock correction; organization setup; vehicle expenses, fuel/charging costs, service costs, and other operational monetary fields already supported by the product; history, summaries, cost-based statistics, existing reports/exports, sharing, transfers, and offline sync.

Out of scope:

- Exchange-rate lookup, automatic conversion, or exchange-rate accounting.
- Choosing a different transaction currency for each new expense.
- Changing a locked personal or organization currency, including a support override.
- New payment collection, subscription currencies, pricing catalogs, or checkout behavior. Those remain governed by [Subscription Management](subscription-management.md).
- New transfer types, reports, export formats, or permissions. These rules apply wherever the existing product supports those actions.

## 3. Users and stories

| User | Need |
|------|------|
| Personal owner | Choose a currency before using the garage and correct a mistake before recording money. |
| Shared-vehicle contributor | Enter costs in the vehicle owner's currency, clearly shown on the form. |
| Fleet Admin | Choose the organization's operational currency before anyone records costs. |
| Driver or fleet staff | Use the organization currency consistently, including offline. |
| Vehicle recipient | Read original historical costs and enter new costs in their own currency. |
| Support staff | See the saved currency and lock state without changing historical meaning. |

## 4. Supported currencies and precision

| Code | Name | Final cost precision |
|------|------|----------------------|
| USD | US dollar | Up to 2 decimal places |
| MMK | Myanmar kyat | Whole amounts |
| THB | Thai baht | Up to 2 decimal places |
| CNY | Chinese yuan | Up to 2 decimal places |

**Default currency: Myanmar Kyat (MMK).** Preselect MMK for new personal onboarding and first-time fleet currency setup. Users may keep MMK or choose USD, THB, or CNY before confirming. Preselection does not bypass the required setup confirmation, override an existing saved choice, or relax currency locking.

Forms and detail views must make the currency unambiguous; symbols alone must not obscure whether an amount is USD, MMK, THB, or CNY. Language and distance/volume settings do not change currency.

Fuel unit prices retain extra precision so quantity × unit price remains accurate. Round the calculated final cost to its currency's supported precision. Exact unit-price scale and rounding mode must be specified consistently in the implementation contract before coding; they were not selected in the grilling session. Existing stored values must not be rounded or rewritten by migration.

## 5. Currency ownership and setup

### 5.1 Personal accounts

- New personal users select a currency on the first-time introduction/onboarding flow, before account creation completes. The flow must also cover supported social-signup paths.
- Display the selected code/name and explain the lock rule before confirmation.
- Save the choice with the personal account, shared across its devices; it is not merely a device preference.
- Permit correction in account settings until the first monetary record is created in that personal garage.
- A Fleet Admin's personal currency remains independent from their organization's currency.

### 5.2 Fleet organizations

- AutoX Admin can provision an organization without selecting its operational currency.
- Fleet Admin chooses the currency on first Fleet Portal login, before operational cost entry is enabled.
- Until selection, block monetary creation across all fleet entry paths, including driver clients and API requests. Read-only access to available data and existing nonmonetary permissions need not be blocked.
- Fleet Admin can correct the currency until the organization locks.
- Managers, mechanics, and drivers inherit the organization currency and cannot choose or override it.
- Setup does not replace existing password-change, activation, subscription, or authorization requirements.

### 5.3 Shared vehicles

New entries use the vehicle owner's personal currency, regardless of the contributor's personal currency. Show the effective currency on the entry form. An authorized contributor's first monetary entry locks the owner's garage currency, not the contributor's personal currency.

## 6. Lock lifecycle

| State | Behavior |
|-------|----------|
| Unselected organization | Fleet Admin must select; monetary creation is blocked. |
| Selected, unlocked | Authorized owner/Fleet Admin can correct the choice. |
| Locked | Currency is read-only; no self-service or support reset in phase one. |

The first monetary record created in the personal garage or fleet locks that scope. This applies regardless of whether the author is the owner, a collaborator, Fleet Admin, or a driver. Lock state is durable: deleting or archiving records never unlocks it.

Receiving a vehicle with historical monetary records does not trigger the receiving scope's lock. Editing those inherited records preserves their currency and does not count as creating a new monetary record. New operational records use the receiving scope's currently selected currency and trigger its lock.

Implementation interpretation: a valid saved zero-cost record still represents a monetary record; a draft or nonmonetary entry with no amount does not. Existing domain validation still decides whether zero is allowed. This interpretation should be included in implementation review rather than confused with a newly agreed pricing rule.

Clients must locally prevent currency changes after a monetary record is saved offline. The server atomically validates currency and applies the durable lock when it accepts the first monetary record. Concurrent currency correction and record creation must never produce a mislabeled accepted record.

## 7. Historical records and ownership transfers

Apply these rules to all supported transfers, including personal recipients and fleet recipients:

1. Preserve every historical amount and its original currency.
2. Use the new owner's personal or organization currency for newly created expenses.
3. Preserve a historical record's currency on every edit, subject to existing edit permissions.
4. Do not convert, relabel, or delete history during transfer.

Example: a vehicle with 500,000 MMK maintenance history transfers to a THB owner. History continues to show 500,000 MMK. New costs use THB. A permitted correction from 500,000 to 450,000 remains MMK.

Derived or linked records representing the same financial event must preserve that event's currency; copying an event into another supported representation must not relabel it as a new payment.

## 8. Totals, statistics, and reporting

- A personal garage's totals use that garage's selected currency; a fleet's totals use the organization currency.
- Shared-vehicle totals use the vehicle owner's currency, consistent with entry forms.
- Include only records matching the relevant scope's currency in monetary totals and monetary charts.
- Keep foreign-currency history visible with its original code, even when excluded from totals.
- Clearly explain exclusions wherever a displayed total covers history containing foreign-currency records, for example: “Historical costs in MMK are excluded from this THB total.”
- Apply the same currency filtering to cost-based metrics and comparisons. Do not include foreign amounts indirectly through category totals, averages, or cost-per-distance calculations.
- Nonmonetary history, dates, distance, and fuel quantities remain available according to existing rules.
- Existing reports/exports must retain currency alongside individual monetary values and clearly identify the currency and exclusions of totals. This requirement does not introduce new export capabilities.

## 9. Purchases paid in another currency

New-record forms use the effective personal/owner/organization currency only. If payment occurred in another currency, the user calculates and enters the equivalent themselves. They may add a note such as “Paid 1,000 THB.”

The system stores the entered base-currency amount; it does not verify the exchange rate, fetch a rate, or derive an amount from the note. Explain this behavior in relevant entry help text.

## 10. Offline use and conflicts

Persist the intended currency with each local monetary record and queued operation. Never resolve currency solely from the latest setting when replaying an old operation.

Example: a driver saves an MMK expense offline while Fleet Admin changes an as-yet-unlocked organization to THB. When the driver reconnects:

- Reject the mismatched creation without inserting or relabeling it.
- Preserve the offline draft, its entered amount, and its MMK code.
- Explain that the fleet currency changed and manual review is required.
- Require the user to explicitly re-enter/reconfirm an appropriate THB amount before resubmission; do not pre-approve unchanged digits as a conversion.
- Do not let the conflict block unrelated valid operations or create duplicates during retries.

The same rule applies to stale personal devices, shared-vehicle contributors, and queued creations after an ownership change. Historical edits are validated against the record's saved currency, not the owner's current currency. Existing authorization checks remain mandatory.

## 11. Data and API requirements

This is a functional contract, not a final schema or endpoint design:

- Persist personal currency and organization currency separately, with durable lock state.
- Persist a supported currency code alongside every operational monetary record. A record's currency must remain interpretable independently of its current owner or author.
- Return currency and setup/lock state to relevant clients.
- Enforce selection permissions, precision, immutable historical currencies, and lock rules server-side as well as in clients.
- Validate the client's intended currency against the effective creation scope. Do not silently substitute the server's currency when the request is stale or missing essential context.
- Use exact decimal/minor-unit handling suitable for money; serialization and calculations must not introduce floating-point drift.
- Audit actual monetary fields and linked representations before implementation so all write paths and aggregates follow this contract.
- Protect older-client writes during rollout; they must not bypass setup or currency conflict validation. Define the compatibility/version gate in the implementation plan.

## 12. Existing-data migration

The product owner confirmed that existing amounts were saved as MMK.

- Backfill existing operational monetary records as MMK without changing numerical values.
- Initialize existing personal garages and organizations to MMK.
- Lock scopes with existing monetary records. Scopes without monetary records may choose another currency.
- Preserve the inherited-history exception where transfer provenance is available; inherited records alone must not lock the recipient.
- Do not infer historical currency from a device's old USD/MMK display preference.
- Migrate local caches and queued operations as well as server data; legacy operational amounts remain MMK.
- Make migration repeatable and verify counts, amounts, and transfer ownership before and after.

Before implementation, inventory legacy fractional MMK values and provenance gaps. Preserve original amounts and explicitly resolve any legacy validation/display exception; never silently round values or invent ownership history. These are migration checks, not permission to convert data.

## 13. Error states and user feedback

| Condition | Required behavior |
|-----------|-------------------|
| Fleet currency not selected | Explain that Fleet Admin must finish currency setup; block cost creation. |
| Attempt to change locked currency | Reject and explain that monetary history has locked the currency. |
| Unauthorized fleet currency change | Reject under existing role enforcement. |
| Unsupported code or invalid precision | Show field-level guidance; reject invalid input. |
| Stale creation currency | Preserve draft and require explicit review in the current currency. |
| Attempt to change historical record currency | Reject; allow permitted amount correction in the original currency. |
| Foreign history excluded from totals | Show a visible exclusion explanation without hiding history. |

## 14. Acceptance criteria

1. New personal onboarding defaults to Myanmar Kyat (MMK), including social signup. The user can confirm MMK or choose any other supported currency; the confirmed choice persists across devices.
2. An owner can correct currency before a monetary record exists; the first record locks it and deletion does not unlock it.
3. First-time fleet setup preselects Myanmar Kyat (MMK). Fleet Admin must confirm MMK or choose another supported currency before any portal, driver, or API cost creation succeeds. Existing saved currencies are not reset to MMK.
4. Fleet staff use the organization currency; Fleet Admin's personal currency remains independent.
5. A THB contributor entering costs on an MMK owner's shared vehicle saves MMK and locks the owner's scope.
6. All supported transfers retain original historical amounts/currencies; new costs use the recipient currency.
7. Editing historical 50,000 MMK to 45,000 after transfer to a THB owner retains MMK.
8. Inherited history alone does not lock a recipient; a new monetary entry does.
9. THB totals exclude historical MMK costs and explain the exclusion across summaries, charts, and existing reports.
10. Foreign purchases can be manually entered in the scope currency with an optional original-payment note; no conversion occurs.
11. New USD/THB/CNY final costs accept up to two decimals; MMK final costs require whole amounts. Fuel unit-price precision is preserved until final-cost rounding.
12. A stale offline MMK creation against a now-THB scope is rejected without data loss; explicit correction permits a single successful resubmission.
13. Concurrent first-record creation and currency correction cannot accept an amount under the wrong currency.
14. Existing values remain numerically unchanged and become MMK; applicable scopes lock and empty scopes remain editable.
15. Historical edits, duplicate retries, old clients, and linked-record creation cannot bypass currency invariants or existing permissions.
16. Subscription pricing and payment currencies retain their separate existing behavior.

## 15. Dependencies and implementation readiness

Related contracts: [Auth](auth.md), [User Profile](user-profile.md), [Expenses](expenses.md), [Fuel](fuel.md), [Maintenance](maintenance.md), [Stats](stats.md), [Vehicle Sharing](vehicle-sharing.md), [Fleet Management](fleet-management.md), [Fleet Analytics](fleet-analytics-plan.md), and [Sync](sync.md).

Implementation planning must settle the exact schema/API payloads, rounding and unit-price precision, legacy data exceptions, old-client compatibility, and rollout order. Update the affected FRDs, API contract, and as-built documentation with implementation; this document alone does not mark them complete.

No new analytics pipeline is required. Within existing observability, record setup completion, rejected currency changes, and sync currency conflicts without logging monetary notes or sensitive payloads. Success means no silent relabeling, no mixed-currency totals, and no loss of drafts during conflicts.

Future phases may consider deliberate currency migration or transaction-level currencies and conversion, with separate requirements. They are not enabled by this phase.
