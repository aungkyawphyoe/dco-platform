# Customer fleet feature implementation plan

Date: 22 November 2026

Status: PR-0 in progress. This document decomposes the four approved investigation priorities into proposed implementation slices. A repository source review is recorded in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md). Customer evidence and live workflow demonstrations remain open. No feature implementation, customer delivery date, or rollout is authorized by this plan.

Source: [Customer fleet feature improvements](customer-fleet-feature-improvements.md). The [review plan](customer-fleet-feature-review-and-plan.md) records trade-offs. Current product choices and evidence live in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md) or the approved feature FRD.

## What changes

The Fleet Portal gains agreement tracking, finance-ready expense exports, incident review linked to repairs, and planned driver assignment changes. The Driver app gains incident capture and visibility into its next planned assignment change. The backend remains authoritative for ownership, permissions, lifecycle transitions, and export identity.

Proposed landing order:

| Order | PR | Scope | Depends on |
| --- | --- | --- | --- |
| 0 | PR-0 | Discovery decisions, FRDs, API and data-model contracts | None. Must pass before implementation PRs begin. |
| 1 | PR-1 | Contract tracking and expiry alerts | PR-0 contract examples, reminder policy, and document access decision |
| 2 | PR-2 | ERP-ready expense records and first export format | PR-0 spreadsheet format and reconciliation contract |
| 3 | PR-3 | Incident capture and incident-to-repair review | PR-0 reporter, field, evidence, and access decisions; PR-2 only if incident cost views use its export mapping |
| 4 | PR-4 | Planned driver assignment changes | PR-0 assignment timing, authorization, and late-return policy |

PR-1, PR-2, and PR-4 do not depend on one another after PR-0 and may be developed on separate branches from trunk. Land them in the listed order for product review. PR-3 branches from the latest trunk containing PR-2 only if it uses its canonical expense references; otherwise it can branch from trunk after PR-0. Keep each PR limited to its listed files and generated contract or migration files.

## PR-0: Close discovery and write feature contracts

**Depends on:** Approved review document.

**Change:** Validate real workflows and record decisions before schema or UI work. This is a docs-only gate.

**Files it may touch:**

- `docs/decisions/customer-fleet-feature-improvements.md` for original requests, rationale, and deferred scope.
- `docs/decisions/customer-fleet-feature-pr0-discovery.md` for repository evidence, live workflow checks, and unresolved customer evidence.
- `product/frd/fleet-management.md` for approved fleet behavior and exclusions.
- `product/frd/expenses.md` for canonical expense/export behavior.
- `product/frd/notifications.md` for agreement reminder rules, if the existing reminder channel is reused.
- New focused FRDs under `product/frd/` for approved behavior not owned by an existing FRD.
- `architecture/openapi.yaml` and `architecture/data-model.md` only after the product contract is settled.

**Checklist:**

- [x] Record public agreement research and current product-owner decisions in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md). No customer agreement sample is available.
- [ ] Resolve the remaining evidence and open decisions listed in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md). Confirm the spreadsheet contract, governing organization records policy, and real workflows before implementation.
- [ ] Record measurable outcomes, role matrix, acceptance scenarios, empty/error/conflict states, and explicit exclusions for each feature.
- [x] Review the current source and document existing data shapes, APIs, and product boundaries in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md).
- [ ] Demonstrate the current Fleet Portal and Driver app workflows before describing a runtime gap.
- [ ] Resolve or defer each open customer evidence item in the PR-0 discovery record.
- [ ] Update the relevant FRDs and contracts only after the evidence resolves product behavior.

**Result:** Each feature retained for implementation has a signed-off behavior contract and no unresolved decision that changes its data model or access policy. If evidence does not support a feature, mark it deferred and remove its implementation PR from this plan. Repository source review is complete; runtime walkthroughs and customer/product decisions remain open in the [PR-0 discovery record](customer-fleet-feature-pr0-discovery.md).

**Verification:** Product owner reviews the scenarios and the actual sample artifacts. API and schema contracts match the approved FRD. No implementation claims are added to `docs/mvp-as-built.md`.

## PR-1: Contract tracking and expiry alerts

**Progress:** Agreement storage is scaffolded in migration `0046_fleet_agreements.sql`. Agreements retain numbered terms with per-term vehicle coverage and optional links to existing documents. The API must check organization membership, vehicle ownership, and document access before writing these references.

**Depends on:** PR-0 evidence and the approved agreement FRD.

**One change:** Implement the agreement workflow defined by the approved PR-0 FRD. Do not add lease billing, claims, or a general document-expiry reminder system.

**Files it may touch:**

- `backend/src/db/schema.ts` and a new Drizzle migration for agreement terms and delivery deduplication.
- `backend/src/modules/` new contract module or the smallest suitable fleet module, plus module registration.
- `architecture/openapi.yaml` and generated API types.
- `architecture/data-model.md` and the accepted FRD from PR-0.
- `fleet-portal/src/app/(fleet)/vehicles/[id]/page.tsx` or a focused agreement route, plus a contracts component under `fleet-portal/src/components/vehicles/`.
- `fleet-portal/src/lib/api/` hooks/types only as needed by the generated contract.

**Implementation order:**

- [ ] Implement agreement records and renewal history from the approved FRD. Link existing documents by ID; do not copy files or double-charge storage.
- [ ] Implement organization-scoped management and reminder delivery from the approved FRD. Keep reminder scheduling and delivery idempotent.
- [ ] Add Fleet Portal agreement list/detail/forms, including empty, upcoming, due, expired, renewal, and delivery-failure states.
- [ ] Add migration and backfill only if approved customer data already exists. Make the migration retry-safe.

**Result:** A manager can create and renew an agreement, authorized users can see its state and linked file, and the selected due-list or organization reminder behavior follows the approved recipient policy. The existing personal maintenance-email scheduler is not reused without an explicit organization authorization and recipient design.

**Verification:**

- [ ] Unit: date boundary, renewal history, role authorization, reminder deduplication, and update/cancel behavior pass.
- [ ] Live: in a seeded organization, create a policy due in the approved interval, confirm the UI state, run the delivery worker twice, and confirm one delivery; verify an unauthorized role cannot open the metadata or file.
- [ ] Perf: capture trunk p95 and query count for vehicle detail and organization vehicle listing with the same seeded fleet. Repeat after the change. Fail if either existing path regresses over 10% p95 or query count. Record baseline and result in the PR.
- [ ] Operator reviews the agreement create/renewal and reminder-failure interactions before merge.

## PR-2: ERP-ready expense records and export

**Depends on:** PR-0 approved spreadsheet format and reconciliation contract. An ERP product or connector is not required for this first release.

**One change:** Implement the expense export defined by the approved PR-0 contract. Reuse the existing analytics records and `/analytics/export` path when they meet that contract. Do not create a second ledger, stable-ID system, or export API for fields the existing records already provide. ERP-specific mappings and connectors remain deferred.

**Files it may touch:**

- `backend/src/db/schema.ts` and migration only for a missing field or constraint demonstrated by the approved sample. Existing `expenses` already include a UUID ID, currency, source kind, source ID, revision, correction actor, and ownership period.
- `backend/src/modules/fleet-analytics.ts` only if the existing records or `/analytics/export` cannot satisfy the approved contract. Avoid parallel export paths.
- `architecture/openapi.yaml`, generated API types, and `architecture/data-model.md`.
- `product/frd/expenses.md` and `architecture/fleet-analytics.md` if the agreed dimensions affect analytics.
- `fleet-portal/src/app/(fleet)/reports/page.tsx` or a dedicated expenses export page, with focused export components and API hooks.

**Implementation order:**

- [ ] Compare the customer sample with `/analytics/records` and `/analytics/export`, then document the fields the existing report lacks.
- [ ] Reuse existing expense identities and ordering. Add only fields or change markers required by the approved export contract.
- [ ] Implement the approved format and reconciliation behavior. Keep ERP-specific mappings and connectors deferred.
- [ ] Validate one representative accounting period against source rows and the agreed spreadsheet output.

**Result:** A representative period opens in Excel and reconciles to existing fleet expense and cost figures. Repeated exports preserve the same record IDs and source references.

**Verification:**

- [ ] Unit: source mapping, stable IDs, correction/tombstone behavior, date boundaries, organization scoping, and deterministic ordering pass.
- [ ] Live: export a representative seeded period in the Fleet Portal, open it in Excel, reconcile its rows and totals, correct and remove one source row, re-export, and confirm stable IDs and source references. Confirm another organization cannot retrieve the file.
- [ ] Perf: capture trunk p95 and row count for `/analytics/export` on the same fixture. Measure the changed export at the approved period size. Fail if existing paths regress over 10% p95 or the workbook/report exceeds the agreed response-time target. Set the export format and size target in PR-0.
- [ ] Operator reviews column names, currency presentation, and correction handling before merge.

## PR-3: Incident capture and repair linking

**Depends on:** The approved incident FRD and PR-0 retention/workflow evidence. Depends on PR-2 only if incident cost summaries use its canonical expense IDs.

**One change:** Implement the approved incident case and repair-link behavior in [fleet-incidents.md](../../product/frd/fleet-incidents.md). Work orders keep their own repair lifecycle and costs.

**Files it may touch:**

- `backend/src/db/schema.ts` and a migration for incident records and incident-to-work-order links, if the separate entity is approved.
- `backend/src/modules/fleet.ts` or a focused incident module.
- `architecture/openapi.yaml`, generated API types, and `architecture/data-model.md`.
- `product/frd/fleet-incidents.md`, approved in PR-0.
- `mobile/lib/features/fleet/domain/`, `data/`, and `presentation/screens/driver_report_issue_screen.dart` for Driver app capture and own-report status.
- `fleet-portal/src/app/(fleet)/work-orders/page.tsx` and focused incident detail/review components.

**Implementation order:**

- [ ] Preserve event-time vehicle and driver attribution as defined in the incident FRD.
- [ ] Enforce create, view, edit, close, and reopen permissions from the incident FRD at the API boundary.
- [ ] Add one-to-many repair links with server validation against organization and vehicle.
- [ ] Keep incident lifecycle independent from work-order status and cost. Apply the approved audited reopen flow.
- [ ] Add Driver app report/confirmation/status and Fleet Portal review, link, and close flows. Respect Driver app connectivity behavior defined in its FRD.

**Result:** One event can group several repairs, or close with no repair, while work orders and actual cost records remain independently auditable.

**Verification:**

- [ ] Unit: duplicate links, cross-organization links, event-time driver snapshot, close reasons, cost rollup, and role checks pass.
- [ ] Live: create an incident in Driver mode, review it in the Fleet Portal, link two repairs, close a no-repair incident and an incident with open repairs, then reassign the driver and confirm original attribution is unchanged. Verify evidence cannot be read outside its permitted roles.
- [ ] Perf: capture trunk p95 and query count for Driver issue submission, own work-order list, and Fleet Portal work-order list on the same fixture. Repeat after incident support. Fail if existing paths regress over 10% p95 or query count. Measure incident detail p95 at the PR-0 agreed maximum evidence and repair count.
- [ ] Operator reviews the Driver submission and Fleet review/closure interactions before merge.

## PR-4: Planned driver assignment changes

**Depends on:** The approved driver assignment-change contract in the PR-0 discovery record.

**One change:** Implement the planned driver assignment change defined in the PR-0 discovery record. Keep it distinct from showroom ownership handover. Do not add shifts, route scheduling, or dispatch.

**Files it may touch:**

- `backend/src/db/schema.ts` and migration for scheduled assignment-change records or assignment effective-time fields, as selected in PR-0.
- `backend/src/modules/fleet.ts` for create, list, cancel, reschedule, and atomic completion.
- `architecture/openapi.yaml`, generated API types, and `architecture/data-model.md`.
- `product/frd/fleet-management.md` and any approved Driver realignment FRD section.
- `fleet-portal/src/app/(fleet)/assignments/page.tsx` and assignment components.
- `mobile/lib/features/fleet/domain/entities/driver_assignment.dart`, `data/repositories/fleet_repository_impl.dart`, and Driver mode assignment/status presentation.

**Implementation order:**

- [ ] Implement the schedule, completion, and cancellation lifecycle from the PR-0 assignment-change contract. Record actor and timestamp for each transition.
- [ ] Validate organization membership and conflicts on the server at schedule and completion. Block conflicts pending manager resolution.
- [ ] Complete by atomically ending the selected old assignment and creating or activating the new assignment. Reject retries or concurrent completion after the first successful transition.
- [ ] Keep the selected current Driver app access until completion. After completion, revoke only the ended assignment's access and grant the new assignment's access.
- [ ] Add Fleet Portal schedule, conflict, cancel/reschedule, and completion states. Add read-only Driver app assignment-change visibility without management actions.

**Result:** The Fleet Portal and Driver app follow the assignment-change contract. Existing assignment history remains intact.

**Verification:**

- [ ] Unit: state transitions, timezone boundaries, conflicts, atomic completion, idempotent retries, and access revocation pass.
- [ ] Live: schedule an assignment change, verify access before completion, cancel one schedule, complete another, attempt duplicate completion, and confirm the old pair ends, the new pair activates, and any other valid assignment remains active.
- [ ] Perf: capture trunk p95 and query count for assignment list/create/complete on the same fleet fixture. Repeat after the change. Fail if existing operations regress over 10% p95 or query count; measure pending assignment-change list p95 at the PR-0 agreed maximum scheduled rows.
- [ ] Operator reviews scheduling and conflict-resolution interactions before merge.

## Shared execution rules

- Create a separate worktree for each implementation PR. Keep its changes inside the listed file set unless a generated contract or migration requires a documented addition.
- Before each PR, capture its trunk performance baseline. Use the same dataset and request mix before and after. The 10% regression limit applies to p95 latency and query count on existing endpoints. Record absolute values and fixture size in the PR.
- Keep user-visible feature changes behind the approved acceptance scenarios. Run each PR's unit checks, then drive its live scenario in the actual Fleet Portal or Driver app. A green test suite does not replace the live scenario.
- Do not merge a feature PR until its unit, live, and performance checks pass and the operator has reviewed its changed interactions.
- For mobile behavior, include online success, offline/stale state, retry, and authorization-revocation cases where the FRD says they apply. Do not add offline support to portal-only flows.
- Update the relevant FRD, API contract, data model, and `docs/mvp-as-built.md` only after behavior is implemented and observed. Keep deferred scope and evidence limits visible.

## Execution gate

This plan is ready for implementation planning review. Implementation starts only after an explicit go. PR-0 must still gather or confirm the customer evidence and decisions that the source decision left open. Do not build a feature whose PR-0 evidence gate fails.
