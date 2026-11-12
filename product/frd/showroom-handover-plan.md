# Showroom handover implementation plan

**Date:** 10 November 2026
**Status:** Implementation started 11 November 2026. Vehicle Detail status controls and server-side status safeguards implemented locally; ownership attribution migration and core record-access isolation are implemented locally; the reviewed handover backend core (drafts, revision-bound review, delegated permission, atomic idempotent completion, frozen warranty/plan evidence, and legacy-route retirement) is implemented locally; the Fleet Portal preparation/review/finalize UI and member permission controls are implemented locally; the personal buyer presentation (clean-history vehicle + plan + warranty + receipt sync, receipt screen, initial-service state, and account-code QR) is implemented locally. QR camera scanning, platform-admin correction, and rollout remain pending.
**Scope:** Fleet Portal showroom-to-personal handover, supporting API, personal/driver sync, and platform-admin correction. This document supersedes conflicting showroom transfer requirements in `fleet-management.md`. It does not claim the proposed routes or schema already exist.

## Outcome

A buyer receives a vehicle in their personal garage with clean service and expense histories and a reviewed, independent maintenance plan. The showroom retains its private operational history. One vehicle identity persists across ownership periods; transferring ownership does not expose all rows linked to that vehicle.

## Current implementation and gap

Inspection on 10 November found an immediate transfer endpoint in `backend/src/modules/fleet-operations.ts`. The reviewed handover backend now replaces it locally: the immediate route returns `410 handover_required`, and `backend/src/modules/handover.ts` implements drafts, buyer lookup, revision-bound review, delegated completion permission, atomic idempotent completion, independent plan copies, and frozen warranty evidence. Fleet Portal now provides buyer lookup by exact email or account ID/QR value, draft plan and warranty preparation, blocking-issue review, revision-bound review, permission-aware completion, cancellation, and manager permission controls. QR camera scanning, buyer receipt presentation, personal/driver mobile presentation, platform-admin correction, delivery retry, and live rollout remain pending.

## Approved product rules

| Topic | Decision |
|---|---|
| Recipient | Existing active personal account; no automatic account creation or unclaimed-email ownership |
| Acceptance | Authorized staff can complete handover without buyer acceptance; an optional acceptance route is not required for this first implementation |
| Identification | Account QR scan or exact-email lookup; show matched name and masked contact details for review |
| Preparation | Organization admin or manager |
| Completion | Organization admin, or manager explicitly granted transfer permission by that admin |
| Delegation | Admin alone grants/revokes transfer permission; recheck at final submission |
| Draft | At most one pending handover per vehicle; changing buyer requires cancellation and a new draft |
| Eligibility | Vehicle remains in the showroom lifecycle and reserved until completion |
| History | Buyer starts clean; showroom service, inspection, repair, fuel, expense, document, and internal-note history remains private |
| Maintenance | Staff must confirm a nonempty plan with at least one applicable item; each item has next-due date/mileage or explicit initial-service-required status |
| Independence | Buyer owns an editable copy of reviewed plan configuration; later showroom changes do not propagate |
| Warranty | Explicit selection of reviewed warranty terms or No warranty; no implicit default |
| Open repairs | Complete all open work orders or explicitly cancel them with a reason before completion |
| Concurrency | Relevant changes invalidate review; repeat submissions cannot duplicate the transfer |
| Corrections | Cancellation before completion; afterward, platform-admin correction only, with reason and audit |
| Privacy after sale | Showroom retains historical access, not automatic access to buyer activity or vehicle editing |

## Frontend vehicle status requirements — approved 11 November 2026

**Status:** Status controls and explanations implemented locally on 11 November 2026; browser-tested with disposable showroom data. Handover entry and pending-draft integration were added to Vehicle Detail on 12 November 2026. Applies to Fleet Portal vehicle lifecycle status controls, with showroom handover rules taking precedence for Sold.

### Location and interaction

- Move all vehicle status-changing controls to **Vehicle Detail** (`/vehicles/:id`). Remove inline row status selectors and bulk status-change controls from the Vehicles inventory page. Keep list badges, counts, status filters, and links to detail.
- On detail, show a dedicated **Vehicle status** section with the current label and a visible explanation of its meaning. Explain each status for the vehicle's lifecycle in a readable list or expandable guide; explanations must not require hovering or rely on color alone.
- Authorized staff select only valid next states. Show the selected state's explanation and consequences before an explicit **Save status** action; selection alone must not submit a change.
- Preserve existing server-side lifecycle and role checks. Status-edit permission does not imply permission to finalize a transfer. Users without edit permission can still read status explanations.
- Show saving/error feedback, prevent repeat submissions, and refresh the displayed status only after success. If the server rejects a stale transition, refresh the vehicle and require a new selection.
- **Sold is not a manual status option.** Explain that it results from successful handover. From Reserved, provide the handover entry point according to preparation permissions, and enforce separate finalization permission. A status change must never bypass buyer, maintenance, warranty, or repair checks.
- If a status change makes an existing draft ineligible (for example Reserved → Listed), prevent finalization and require cancellation or renewed eligibility/review. Never silently complete or discard the draft.

### Status explanation copy

Display only the statuses belonging to the vehicle's lifecycle. Descriptions explain recorded operational state; they do not imply that the system published a listing, collected payment, or certified roadworthiness.

| Lifecycle | Status | Explanation shown to staff |
|---|---|---|
| Showroom | Inventory | This vehicle is in showroom stock and has not yet been marked as listed for sale. |
| Showroom | Listed | This vehicle is marked as offered for sale. This status does not publish an advertisement automatically. |
| Showroom | Reserved | This vehicle is being held for a prospective buyer. Ownership remains with the showroom until handover is completed. |
| Showroom | Sold | Handover is complete and ownership has moved to the buyer's personal account. The showroom retains its historical records. Corrections require platform support. |
| Taxi fleet / rental / commercial | Available | This vehicle is recorded as available for its next assignment or rental. Check its condition and maintenance before use. |
| Taxi fleet | Leased | This vehicle is recorded as leased out and is not marked available for another lease. |
| Taxi fleet / commercial | Maintenance | This vehicle is recorded as undergoing maintenance. Review its repair work before returning it to service. |
| Rental | Rented | This vehicle is recorded as rented to a customer and has not yet been marked as returned. |
| Rental | Return | This vehicle has been marked as returned and is awaiting the next inspection stage. |
| Rental | Inspection | This vehicle is in the inspection stage before being marked available again. |
| Commercial | In service | This vehicle is recorded as active in normal operations. |
| Commercial | Retired | This vehicle has been removed from active operations. This is a terminal lifecycle status. |

### Frontend acceptance checks

- Inventory still supports status visibility/filtering but contains no individual or bulk status mutation controls.
- Detail explains every status in the applicable lifecycle, including the current state, with keyboard/touch-accessible text.
- Selecting a valid state does not save until explicitly confirmed; invalid transitions and unauthorized changes remain server-denied.
- Showroom Sold routes through handover only; ordinary status controls cannot transfer ownership.
- Failed/stale saves leave accurate state and actionable feedback. Existing handover drafts cannot complete after eligibility is lost.

## Data and access design

### One vehicle, separate ownership periods

Introduce or extend an ownership-period representation with vehicle, principal (organization or personal account), start/end, and transfer provenance. Inspect existing analytics tenure/provenance models before selecting the physical schema; reporting attribution alone must not become an authorization boundary without verification.

Classify all linked entities: service records and line items, fuel, expenses, inspections, work orders, plan items, documents/media, parts, notifications, assignments, and sync operations. Reads and writes must check the correct period in addition to vehicle identity. Preserve creator attribution separately from ownership. Backdated service dates must not select an ownership period; authenticated operation context does.

| Data | Buyer after handover | Showroom after handover |
|---|---|---|
| Vehicle identity/current mileage | Current owner access | Frozen handover identity/mileage snapshot |
| Previous operational records and attachments | No access | Historical read access for authorized staff |
| Reviewed maintenance configuration | Independent editable buyer plan | Frozen handover version and original showroom plan |
| Agreed warranty | Read agreed terms/status | Retained agreed terms; scoped warranty workflows |
| Buyer-created records | Owner access | No automatic access |
| Transfer audit | Buyer-facing receipt subset | Organization audit; platform-admin correction access |

Do not duplicate the vehicle. Copy only approved maintenance configuration and immutable handover/warranty evidence. Never copy prior monetary costs, internal notes, receipts, or service completion rows into the buyer period. Audit vehicle master fields too: showroom purchase price/date, internal metadata, and image attachments must not leak merely because they live on `vehicles` rather than child tables. Define the buyer-visible vehicle-field allowlist in phase 0.

Historical showroom records are read-only after handover except explicit reviewed corrections/late submissions recorded separately. Never modify the frozen handover evidence. A late submission must not update current vehicle mileage, buyer totals, plan targets, or warranty baselines.

### Maintenance handover

Use the current per-vehicle reminder model from the November maintenance specification. The catalog supplies service names, not inherited intervals. Resolve fleet-private catalog references into buyer-owned configuration without granting access to the fleet catalog.

For every included item record its service name, supported date/distance recurrence, next-due target(s), and initial-service-required state where the baseline is unknown. Preserve legitimate overdue targets. Do not reset intervals to sale date/mileage or invent a completed service to initialize a plan. For example, oil due at 45,000 km stays due at 45,000 km when handed over at 43,000 km.

Adapt the due calculator to explicit handover targets if needed. Buyer service logging must advance the independent plan normally. Snapshot the reviewed version; any relevant plan, mileage, recipient eligibility, or warranty change requires renewed review.

### Warranty

Freeze coverage, exclusions, approved workshops, start date/mileage, and time/distance limits in the warranty instance; a template ID alone is insufficient evidence. Buyer reminder edits cannot rewrite warranty terms. Warranty does not grant general access to buyer history. Existing workshop eligibility and access must be reviewed against this boundary.

## Workflow and state

Persist draft, completed, and cancelled states. A draft carries a revision and reviewed revision rather than a separate durable reviewed state. Cancellation and completion are terminal; corrections are separately audited operations.

1. Admin/manager starts a draft for a reserved showroom vehicle.
2. Identify an existing buyer by QR or exact email. QR identifies the account; it is not consent, a login token, or garage access. No broad account autocomplete/directory.
3. Prepare current mileage, sale date, plan, and explicit warranty choice.
4. Resolve open repairs; review recipient name/contact, plate/VIN, mileage, plan, and warranty.
5. Finalizer confirms that recipient and vehicle were checked with the buyer and acknowledges that mistakes require platform support.
6. Server rechecks permission, organization/account eligibility, inventory status, draft revision, reviewed content, repair state, and mileage under concurrency protection.
7. In one transaction: close showroom period, open buyer period, change current owner, create independent plan and optional warranty, retain audit/snapshots, end assignments and inventory access, mark draft complete, and persist sync/notification delivery events.
8. Deliver the buyer vehicle/plan/warranty and receipt after commit. Retry delivery failures without reversing ownership. Return the original result for a completed retry, subject to authorization.

Enforce one pending draft with a database constraint, not only a UI check. Serialize competing completions and relevant writes. Direct status changes to sold must not bypass handover. Ensure the old immediate-transfer route cannot bypass the new requirements; replace or retire it atomically with the new backend behavior.

## Sync and privacy

Personal initial sync and incremental sync must both deliver only the new ownership period, complete vehicle payload, plan, and permitted warranty/receipt data. Reusing the vehicle ID must not cause previous showroom rows to be fetched implicitly.

Driver assignment manifests remove access at handover. Retain unsent operations in the appropriate review mechanism without leaving old records readable indefinitely. Validate stale sessions, old record IDs, attachment URLs, exports, and caches. Previously downloaded data cannot be remotely made unseen; do not promise instantaneous removal on disconnected devices.

Late submissions are routed to the closed showroom period for review, never accepted into the buyer period. Reject or quarantine ambiguous legacy submissions rather than guessing. Historical acceptance must not advance the buyer's maintenance or mileage.

## Platform-admin correction

Provide an audited correction workflow before releasing transfer completion. Showroom staff can request support but cannot reclaim vehicles themselves. Platform admin verifies the mistaken transfer and intended recipient, records evidence/reason, and previews affected ownership periods, plan, warranty, and delivery state.

Do not implement correction as a blind user_id reversal. Preserve buyer-created records and privacy; conflicting activity requires explicit resolution rather than automatic movement or deletion. Add corrective events while retaining the original transfer audit. Detailed correction transaction and access rules are a phase-0 design deliverable; this approval does not authorize arbitrary deletion or reassignment of buyer records.

## Implementation sequence

Status controls were delivered as an independent first increment. Phase 0 investigation is recorded in [the implementation audit](../../docs/showroom-handover-implementation-audit.md); ownership attribution and core access filters are implemented locally; legacy reconciliation and the complete handover remain pending.

| Phase | Work and affected areas | Exit criterion |
|---|---|---|
| 0. Inventory and contract | Inspect schema, fleet operations, owner/driver routes, media, sync, analytics tenure, warranty, maintenance calculators, and legacy transfers. Specify field allowlist, ownership-period schema, correction behavior, and endpoint/error contracts. | Reviewed mapping of every linked record and access path; unresolved policies below resolved |
| 1. Schema and migration (in progress) | Ownership-period ledger and new-record attribution implemented in migration 0040; legacy attribution flagged for review. Still add draft/revision/uniqueness, delegated permission, frozen warranty/plan evidence, and reliable delivery events. Backfill only from evidence. | Repeatable migration, reconciliation report, and ambiguous-row isolation without deletion |
| 2. Authorization and isolation (in progress) | Core record APIs, totals, reminders, media, and sync now filter by ownership period; Fleet Admin has read-only attributed historical records. Complete the remaining transfer/workshop/late-review paths and apply ownership-period checks to direct reads/writes, joins, totals, exports, media, workshop access, and sync; close stale assignments/shares as applicable. | Cross-period access tests pass before exposing the new handover flow |
| 3. Handover service | Implement draft, recipient lookup, cancel, review, atomic complete, work-order cancellation reason, idempotency, and legacy-route protection. Implemented locally in the backend and Fleet Portal. | Failure and concurrency tests prove all-or-nothing behavior |
| 4. Portal and personal mobile | Vehicle status changes on detail with lifecycle explanations, portal draft/review/finalize UI, and member permission controls are implemented locally. Still pending: QR camera scanning, personal account QR, buyer receipt presentation, mobile first/incremental sync presentation, and driver revocation/late-write behavior. | Existing buyer can receive and maintain vehicle with clean history on first and incremental sync |
| 5. Support correction and rollout | Audited platform-admin correction, delivery retries, migration rehearsal, end-to-end tests and updated user instructions. | Complete safety/acceptance matrix passes; enable only after backend and client compatibility are ready |

Proposed API operations are create/read/update/cancel draft, resolve buyer, review a revision, complete idempotently, and platform-admin correction. Select exact paths in phase 0 and update `architecture/openapi.yaml` plus generated clients with implementation; do not advertise proposed paths as available now.

## Acceptance checks

- Admin completes a handover; a manager can prepare but cannot complete until explicitly permitted. Revocation between review and submit is enforced.
- Exact email and QR resolve the intended account without exposing other accounts or garage data. Missing/inactive/driver-only accounts cannot receive a personal handover.
- Second pending draft is rejected; changing recipient requires cancellation; concurrent/repeated completion produces one ownership change, plan, warranty, and receipt event.
- Empty/unreviewed plan blocks completion. Unknown baseline requires initial service. Overdue and mixed date/distance reminders remain correct; buyer service completion advances the plan.
- Relevant concurrent updates invalidate review. Open repairs block completion; cancellation records a reason. No stale writer can reopen work across completion.
- Buyer sees clean histories and independent reminders in both fresh and existing app installations. Showroom costs, notes, documents, attachments, and private catalog data are inaccessible by direct ID, API, sync, or export.
- Showroom retains its own historical data and audit, but cannot read buyer activity or edit current vehicle/plan. Late driver updates cannot change buyer data.
- Warranty template edits and buyer reminder edits leave agreed warranty terms unchanged.
- Transaction failure leaves original ownership/access intact; delivery failure retries without losing or duplicating the handover.
- Correction retains the original evidence and protects any buyer activity; showroom cannot self-reverse.

## Policies to resolve during phase 0

These are implementation prerequisites, not reasons to reopen agreed product choices:

- **Resolved 11 November:** Preserve the showroom-transfer vehicle-count exemption. Apply it consistently in backend counting and mobile offline gating; do not silently charge or upgrade the buyer. Backend allowance counting excludes audited transfers to the buyer; personal sync now supplies `transfer_limit_exempt` and mobile offline gating consumes it.
- Decide draft expiration, account QR lifetime/rotation, and buyer receipt channel using current capabilities. Buyer acceptance remains unnecessary.
- Define treatment of ambiguous legacy transfers and already-exposed history, currency/storage attribution, suspended organization access to retained records, and personal-account eligibility when organization memberships also exist.
- Finalize buyer-visible vehicle fields and platform-admin correction outcomes when buyer activity already exists.

## Documentation and release boundary

Related contracts: [Fleet Management](fleet-management.md), [Maintenance](maintenance.md), [Fleet maintenance](fleet-maintenance-templates.md), [Sync](sync.md), [IAM](../../architecture/iam.md), [Data model](../../architecture/data-model.md), and [API index](../../architecture/api.md).

This plan records approved future behavior. Existing endpoint/schema documentation remains an implementation baseline where explicitly identified. Update OpenAPI, generated clients, schema diagrams, and user instructions alongside delivery; do not describe the planned handover as shipped.
