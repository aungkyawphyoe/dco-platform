# Personal / Driver mobile realignment plan

Date: 2026-10-18
Status: Approved by the user; local implementation and automated validation complete on `codex/mobile-driver-realignment`. Release verification pending.

## Intended product

Personal and Driver accounts use one mobile presentation layer: the same Garage, Maintenance, Expenses, Settings, history, logging forms, and vehicle selector. Data ownership and explicit permissions differ. Fleet administration remains in the Fleet Portal.

This is more than a visual parity fix. It replaces the restricted, online-first Driver product with an offline-capable vehicle logging experience, including full assigned-vehicle history and costs.

This document records the user's confirmed decisions. Existing contradictory production scope, FRDs, API contracts, and mobile agent instructions must be reconciled during the first implementation phase. The implementation updates these contracts alongside the code.

## Confirmed decisions

| Concern | Personal | Driver |
|---|---|---|
| Account | Existing personal account | Separate account created by Fleet Admin; no Personal/Organization toggle |
| Storage | Personal ownership | Organization ownership in the same PostgreSQL database; logical separation, not separate physical databases |
| Vehicle access | Existing personal garage rules | Assigned vehicles only; many vehicles per Driver and many Drivers per vehicle |
| Vehicle administration | Existing permissions | Read-only vehicle master data; admin manages vehicles and assignments in portal |
| Plans | Existing personal plan management | Admin-defined plans; Driver cannot add, edit, or delete plan items, including suggested items |
| History and totals | Existing personal experience | Full history, amounts, and totals for assigned vehicles, including admin and previous-driver records |
| Expenses | Existing categories and forms | Same supported categories and forms; remove fuel-only restriction |
| Service logging | Shared completed-service form | Same form, no approval for ordinary completed services |
| Planned service | Linked plan completion | Linked admin-defined item; completion advances next due date |
| Unplanned service | Record completed work | Allowed; history and cost recorded without creating or changing a plan |
| Record correction | Existing personal permissions | Edit/delete own records; others' records read-only; Fleet Admin can correct any record |
| Admin correction | Existing behavior | Once corrected by an admin, record becomes read-only to Driver, with attribution |
| Documents | Existing document screens | Organization-owned vehicle documents; view assigned-vehicle documents, manage own uploads subject to admin lock |
| Notes | Private local notebook | Private account-local notebook; no org sync or admin access |
| Sharing | Existing personal sharing | Admin-managed assignments replace Personal sharing action |
| Offline | Existing local persistence and sync | Previously synced vehicle data available; maintenance, fuel, and expense writes queued; org data isolated locally |
| Fleet operations | Not added to Personal | Report Issue and Inspections remain separate fleet actions with existing workflows |
| Organization reporting | Not applicable | Organization-wide reporting stays in Fleet Portal; assigned-vehicle totals are visible on mobile |

### Revocation and conflicting uploads

- When the app learns an assignment was removed, remove that vehicle from accessible Driver data and stop ordinary reads/writes for it.
- Preserve pending offline submissions. Route submissions affected by revocation to admin review rather than applying them to live history, totals, or due dates.
- Keep a narrow status view for the submitting Driver without restoring vehicle access.
- Offline edits conflicting with an admin correction also go to review.
- Accepted submissions apply their business effects; rejected submissions do not. Never silently discard the user's pending work.
- Offline devices cannot learn about revocation until they reconnect. Do not promise immediate remote removal while disconnected.

## Current implementation and drift

Inspected during planning:

- `mobile/lib/core/router/tab_switchers.dart` chooses separate `DriverHomeScreen`, `DriverMaintenanceScreen`, and `DriverExpensesScreen` implementations rather than shared feature screens.
- `mobile/lib/features/fleet/providers.dart` uses network-backed Driver providers, a singular assigned-vehicle provider, and Driver suggested-plan additions.
- `mobile/AGENTS.md` explicitly specifies online-first Driver behavior, hidden spend cards, fuel-only Expenses, and different dashboard actions despite calling the experience personal parity.
- `architecture/data-model.md` specifies one active assignment per Driver and per vehicle, plus Driver suggested-plan creation.
- `backend/src/modules/sync.ts` filters change-log delivery by authenticated user. It cannot simply be reused unchanged for shared organization vehicles and their complete history.
- `backend/src/modules/fleet-operations.ts` contains assignment checks and Driver fuel endpoints that need review alongside the broader fleet module.
- `architecture/system.md` already specifies a shared API and PostgreSQL database; physical tenant database migration is unnecessary.

The correction must change specifications, server authorization, synchronization, and portal workflows as well as screens.

## Proposed technical design

These are implementation recommendations, not additional confirmed product choices.

### Shared screens and contextual repositories

Use a resolved account context containing account ID and either Personal ownership or organization ID. Resolve it from authenticated identity/entitlements, with a locally stored context for offline sessions. An unresolved identity must not silently fall back to Personal mode.

Expose common domain repository interfaces to the existing Personal feature screens. Context selects data scope, synchronization transport, and capabilities. Widgets must not pick separate Personal/Driver screen trees or make organization-specific HTTP calls directly.

Both modes read local persisted data. Sync adapters send Personal operations to Personal APIs and organization operations to organization-authorized APIs. Shared presentation does not require identical authorization rules or a single undifferentiated endpoint.

Capabilities cover vehicle/plan administration, author-owned record mutation, admin locks, and fleet-only actions. Enforce every capability on the server; hiding a button is not authorization. Preserve the shared core navigation and logging actions; add Report Issue and Inspections as supplemental Driver actions rather than replacing core actions.

### Scope and attribution

Every local data query, active-vehicle selection, outbox operation, media task, and sync cursor must be bound to its account and data scope. Local Notes must also be isolated by account. Account changes must not expose or upload another account's data.

On the server, derive organization membership and authorship from authenticated identity. Validate organization, vehicle membership, and assignment rather than trusting IDs in payloads. Preserve the original creator separately from the latest editor and record an explicit admin-correction lock.

Migrate assignments to allow multiple active links, while preventing duplicate active links for the same organization/Driver/vehicle tuple. Preserve assignment history for revocation review.

### Organization sync and review

Add organization-aware bootstrap, incremental changes, record revisions, deletion markers, and access-revocation handling. A new assignment needs full eligible vehicle history, including entries predating the assignment; incremental changes alone are insufficient.

Use stable operation IDs and expected revisions for idempotent writes and conflict detection. Recheck access during application and media access. A formerly assigned Driver may submit a preserved operation for review through a narrowly authorized route, not through a bypass of ordinary vehicle access. Historical assignment must be verifiable server-side; a client timestamp alone is insufficient proof.

Persist review submissions separately from live operational records, with submitter, scope, original operation, expected revision, reason, status, and reviewer attribution. Acceptance must be transactional and idempotent, including associated costs and maintenance effects. Status access must not expose unrelated review items or revoked vehicle history.

Ordinary authorized logs need no review. Do not turn every Driver write into an approval workflow.

### Consistency after corrections

Use one authoritative accounting path so service costs, fuel costs, and expense totals are not double-counted. Editing/deleting a service must recompute affected due dates from remaining applicable service history rather than advancing the interval again. Preserve existing mileage invariants; handle backdated records explicitly.

Keep existing issue/work-order and inspection behavior separate from completed-service logging. Ensure work-order completion does not create duplicate costs or service completion effects already recorded elsewhere.

## Delivery sequence

1. **Reconcile product contracts.** Update production scope, fleet management, maintenance templates, maintenance, expenses, documents, sync, architecture, navigation documentation, and `mobile/AGENTS.md`. Mark the previous Driver restrictions as superseded rather than appending another contradictory definition. Specify API schemas and error/review states in OpenAPI.
2. **Build server foundations.** Migrate assignment constraints and attribution/revision metadata; backfill conservatively without inventing authors. Add full assigned-vehicle reads, generic expense/document operations, author-only mutations, admin locks, and planned/unplanned service handling. Remove Driver plan-write permissions, including suggested additions.
3. **Build organization sync and review.** Add bootstrap/deltas, revocation delivery, idempotency, revision conflicts, review persistence and acceptance/rejection. Add Fleet Portal review UI and many-to-many assignment management. Keep personal synchronization behavior intact.
4. **Extend mobile persistence.** Migrate scoped local data, outbox, media queue, cursors, and account context. Implement organization repository adapters and access cleanup. Preserve pending submissions separately when removing revoked vehicle data.
5. **Unify presentation.** Bind existing shared feature screens to contextual repositories; replace Driver screen switches. Enable full expenses, history/totals, documents, assigned-vehicle selection, and shared planned/unplanned logging. Retain separate fleet issue/inspection actions and show pending/review/admin-lock states.
6. **Verify and release together.** Run authorization, sync, migration, domain, and shared-screen checks below. Coordinate compatible API/mobile/portal rollout. Remove obsolete Driver screens/providers only after their consumers have migrated. Do not enable organization offline writes before server review and conflict handling are available.

## Acceptance checks

- Personal and Driver use the same core screen implementations, layouts, fields, and navigation; only confirmed capabilities and fleet actions differ.
- A Driver assigned two vehicles can switch between them. Two Drivers can access the same assigned vehicle, with correct authorship and visibility.
- Full eligible history, documents, and totals include records by admins and previous Drivers, without exposing unassigned vehicles or another organization.
- Every existing supported Personal expense category can be logged in Driver context and appears once in portal/mobile totals.
- Planned and unplanned services work online and offline. Only planned services advance the linked plan. Retries do not duplicate records or effects.
- Drivers cannot mutate vehicle master data, plans, another author's records, or admin-corrected records through either direct API calls or sync.
- Own-record edits/deletions update totals and due dates correctly; ownership and admin locks survive retries and multiple devices.
- Revoked assignments stop ordinary access after refresh, including cached media. Preserved offline operations appear once in review, affect no live totals before acceptance, and expose only their own review status to the submitter.
- Admin correction racing with offline Driver edits yields review rather than lost updates. Approval cannot duplicate a service or its accounting effects.
- Account changes cannot expose or upload another account's data, notes, attachments, pending work, or cursors. An offline Driver session never falls back to Personal context.
- Existing Personal offline behavior and Fleet Portal issue/inspection workflows remain functional.
- Existing assignment/data migrations retain history. Legacy records with uncertain authorship do not become editable by arbitrary Drivers.

## Remaining bounded design details

Resolve these explicitly when writing contracts; they do not change the agreed core direction:

- Parts-specific UI and mutation rules need an inventory against the Personal feature set so they are not silently omitted from parity.
- Offline scope for fleet-only inspections/issues, attachment availability/download behavior, and document upload retries need explicit contracts; this session specifically confirmed offline maintenance/fuel/expense logging and cached vehicle data.
- Existing completed/approved inspection or work-order records may have lifecycle restrictions; apply the author-edit rule to ordinary logs without silently reopening completed workflows.
- Define what happens if an admin changes/deletes a plan while a Driver logs its completion offline, and how review handles a vehicle transferred out of the organization.
- Specify review rejection reasons, pending-item retention, and access for suspended/deactivated accounts without weakening authentication or organization boundaries.
- Audit existing org_manager/org_mechanic permissions; this session confirmed Fleet Admin powers, not broader permission changes for those roles.

## Drivvo comparison

Checked against public documentation during this session:

- [Fleet management](https://www.drivvo.com/en/fleet-management/): assigned-vehicle access, broad logging, offline synchronization, and customizable per-module view/add/edit/delete permissions.
- [FAQ](https://www.drivvo.com/en/faq/): a Driver can be assigned a vehicle or group of vehicles.
- Drivvo's standard Driver visibility is own records without reports. DCO deliberately differs by allowing full assigned-vehicle history and totals.
- The public pages do not establish our exact author-only mutation rule, admin-correction lock, review behavior, or simultaneous multi-Driver vehicle access. Those are DCO decisions, not claims about Drivvo.
- Income, trips, and configurable permission-profile tooling are not added just because Drivvo supports them. They were not included in this adjustment.

## Implementation checkpoint — 19 October 2026

The shared screen implementation, scoped APIs/local persistence, many-to-many assignments, revision/review handling, media authorization, and linked accounting are implemented on `codex/mobile-driver-realignment`. Seven obsolete Driver-only core screens have been removed. Personal behavior remains on its existing APIs and database.

Bounded decisions applied during implementation:
- Parts retain the Personal add/edit/read surface with Driver authorship/admin locks. No new inventory-management workflow is added.
- Issues and inspections remain online-only supplemental flows. Shared maintenance/fuel/expenses/documents use the organization outbox.
- Missing/changed plan references enter review. Acceptance must satisfy the current plan contract; an admin can decline an obsolete submission with a note. Transfers prevent acceptance into the old organization.
- Suspended/deactivated accounts do not gain a special authentication bypass for review status.
- Downloaded organization documents use authenticated access and scoped local files; the assignment manifest removes cached vehicle data/files after revocation is learned.
- Service/fuel deletion is exposed to authorized Drivers in the shared detail screens. Existing Personal deletion behavior is unchanged.

Rollout verification remains separate from local implementation: apply migrations to a restored database, run `backend/src/scripts/check-organization-accounting.sql`, and resolve any legacy costs with ambiguous existing expense links before release. No attribution is invented. The database refuses ambiguous legacy corrections until reconciled. Coordinate API/mobile/portal rollout; test offline account switching, receipt uploads and revocation on a device. No deployment has been performed.

Local validation:
- Backend: 70 tests pass; TypeScript build passes. Coverage includes authorization, many-to-many assignments, revision/review handling, media revocation, single-source accounting and maintenance schedule restoration.
- Mobile: 314 tests pass, including sign-in/sign-out, scoped outbox/review behavior, account-transition pausing, snapshot deletion recovery and shared Garage restrictions. Analyzer reports no errors; 41 warnings/informational diagnostics remain.
- Fleet Portal: TypeScript and ESLint pass; API types regenerated from the updated OpenAPI contract.
- Account transitions use an independent sync coordinator to avoid a session/provider dependency cycle. Review recovery resets the persisted cursor transactionally, so interruption before snapshot application cannot lose the server restoration.
