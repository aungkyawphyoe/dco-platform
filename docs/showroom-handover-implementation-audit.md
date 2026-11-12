# Showroom handover implementation audit

Date: 11–12 November 2026. Investigation and local implementation progress; the complete handover is not yet implemented. Product contract: [approved handover plan](../product/frd/showroom-handover-plan.md).

## Delivered first increment

- Inventory status badges/counts/filters remain; inline mutation controls, bulk status UI, its unused hook, and unused selection checkboxes are removed.
- Vehicle Detail uses `fleet-portal/src/components/vehicles/vehicle-status.tsx`: readable lifecycle explanations, allowed-next-state selection, explicit Save, loading/success/error states, and no manual Sold action.
- `backend/src/modules/fleet.ts` status PATCH accepts optional `expected_status`, serializes updates under vehicle then organization-link locks, rejects stale state with 409, rejects Sold with `handover_required`, and writes its change event transactionally.
- OpenAPI and Fleet Portal generated types reflect the status contract.
- The old immediate-transfer endpoint still exists. These status safeguards do not make that endpoint satisfy the new handover contract.

## Record and access inventory

| Area | Evidence / implementation location | Required handover work |
|---|---|---|
| Current ownership | `backend/src/modules/fleet-operations.ts`, transfer route; `db/schema.ts` vehicles/organizationVehicles | Add ownership periods and atomic reviewed completion; current owner change alone exposes vehicle-linked history |
| Service, expenses, fuel, documents, parts | `modules/owner.ts`, `lib/serialize-records.ts`, schema child tables | Scope list/detail/write/derived-cost paths to period; keep attribution distinct from creator and service date |
| Vehicle access | `modules/vehicles.ts` personal access functions | Existing org-link denial stops at transfer; add period-aware record checks, master-field privacy, and correction rules |
| Vehicle master payload | `lib/serialize.ts` publicVehicle includes purchase price/date/currency and photo ID | Preserve showroom values in its evidence; explicitly initialize buyer-visible master fields without disclosing acquisition cost |
| Maintenance | `lib/reminder-schedule.ts`, `plan_items`, `service_record_items` | Clone reviewed due targets into new plan IDs; no old completion linkage; scope recalculation to buyer period; support initial-service-required state |
| Personal sync | `modules/sync.ts` reads per-user `change_log`; transfer emits only vehicle ID/user/mileage | Transactionally emit complete vehicle/plan/warranty/receipt data; reconcile prior access and old events; do not replay showroom records |
| Driver sync | `modules/organization-sync.ts` bootstrap joins records by assigned vehicle; complete assignment manifest exists | Close assignments; constrain historical serialization and late review submissions by period |
| Late review | `modules/owner.ts` currently rejects accepted records when organization link is gone | Introduce historical review path that cannot modify buyer mileage, reminders, costs, or frozen handover evidence |
| Media | `modules/media.ts`, document links and storage ownership | Retain organization storage attribution; authorize historical attachments separately; verify legacy media and signed links |
| Analytics | `drizzle/0022_fleet_analytics.sql` analytics_tenures/analytics_records; later currency/service-item migrations | Reuse frozen reporting evidence; do not mistake organization-only reporting attribution for a complete personal ownership/access ledger |
| Warranty | `vehicle_warranties` references mutable template, unique vehicle ID; workshop service routes in fleet-operations | Snapshot actual terms/workshops; define correction behavior and explicit scoped post-sale service access |
| Transfer audit | `transferred_vehicles` stores vehicle and service snapshots | Add reviewed plan, recipient, authorization, warranty evidence and correction events; never reconstruct missing history from buyer rows |
| Limits | `lib/limits.ts` counts all active owned vehicles; mobile FeatureGate uses vehicle count | Preserve user-approved transfer exemption in both backend and offline mobile. Existing transfer bypass does not exclude the car from later count-based checks |
| Legacy data | `0032_currency_enforcement.sql` already marks transfer provenance ambiguity | Backfill only supported attribution; quarantine ambiguous legacy records instead of date-based guesses |

## Fifth increment — reviewed handover backend core

Implemented locally on 12 November 2026:

- Migration 0041 adds handover drafts, the single-pending-draft database constraint, frozen plan/warranty evidence, delivery events, delegated manager permission, initial-service-required plan state, work-order cancellation evidence, and handover linkage on the existing transfer audit.
- `modules/handover.ts` provides exact-email and account-ID buyer lookup with masked contact details, draft create/update/cancel, revision-bound review, and atomic idempotent completion. Completion rechecks delegated permission, buyer eligibility, reserved showroom state, mileage, reviewed revision, plan, explicit warranty choice, and open repairs inside the transaction.
- Completion closes showroom access, opens the buyer ownership period, copies only the reviewed maintenance plan into new buyer-owned rows, freezes warranty terms, records showroom vehicle/service evidence, ends driver assignments, writes buyer sync changes and a receipt, and queues delivery events. Repeated completion returns the original result without duplicating ownership, plan, warranty, or receipt rows.
- Showroom purchase price/date and vehicle photo are captured in the handover evidence and cleared from the buyer-facing vehicle. Buyer plan/service isolation continues to use ownership periods.
- The immediate `POST /organizations/{id}/vehicles/{vehicleId}/transfer` route now returns `410 handover_required`; fleet tests now drive the reviewed flow.
- Work orders can be explicitly cancelled with a reason, and open reported/in-progress repairs block review and completion.
- Organization admins can grant or revoke `can_complete_handover` for managers; the permission is rechecked under a membership lock at completion.
- OpenAPI and both generated API type sets describe the new operations; Fleet Portal and Web TypeScript checks pass.

Still pending at the end of this increment: Fleet Portal draft/review/finalize UI and member permission controls (added in the sixth increment below), QR scanning, buyer receipt presentation, mobile first-sync/incremental-sync presentation checks, platform-admin correction with existing buyer activity, delivery retry worker, late-write review path, legacy reconciliation, and live migration rehearsal.

### Fifth-increment validation

Backend TypeScript and full suite passed: 170 passed, 1 skipped across 39 files. Migration 0041 reapplies cleanly. Handover integration tests cover clean buyer delivery, frozen warranty terms and workshops, independent plan targets and initial-service state, idempotent retry, duplicate pending drafts, review/plan/warranty/open-repair blocking, delegated permission and recheck, stale revisions, cancellation, buyer changes, legacy-route retirement, buyer sync delivery, and ownership isolation.

## Sixth increment — Fleet Portal handover preparation

Implemented locally on 12 November 2026:

- Vehicle Detail now renders `fleet-portal/src/components/vehicles/handover-panel.tsx` for showroom vehicles. While the vehicle is Reserved, admins and managers can identify a buyer by exact email or account ID/QR value, see the matched name and masked contact details, and start a handover draft. No directory or autocomplete lookup is offered.
- Starting a draft seeds the buyer plan from the vehicle’s enabled showroom reminders, sets the sale date to the server calendar day, and uses the current odometer as the handover mileage. The vehicle stays Reserved and showroom-owned until completion.
- `handover-plan-editor.tsx` edits the draft plan snapshot: service name, due date, due odometer, optional date/distance recurrence, notes, and an explicit “initial service required” state for unknown baselines. Local validation mirrors the server’s due-target and initial-service rules.
- Warranty choice is explicit: reviewed template terms or No warranty. Saving a template captures and displays the frozen duration, mileage limit, coverage, exclusions, and approved workshops. Undecided warranty blocks review and completion.
- The draft shows server blocking issues for sale date, mileage, plan, warranty, buyer eligibility, vehicle readiness, and open repairs. Open-repair issues link to the affected work orders. Unsaved edits hide stale readiness results and require a save before review.
- Review is bound to the saved revision, and completion requires a fresh review, a final acknowledgement, and the delegated completion permission. Revocation is enforced by the backend; the portal surfaces `transfer_permission_required`. Stale-revision and not-ready responses refresh the draft checks.
- Drafts can be cancelled with a reason. If the vehicle leaves Reserved while a draft exists, the panel remains reachable, explains that the draft cannot complete, and offers cancellation; it does not silently discard the draft.
- Members now shows an admin-only “Can complete” control for managers and a read-only completion state for non-admins. Work Orders can explicitly cancel reported or in-progress repairs with a reason, retain them in a Cancelled audit column, and thereby clear handover blockers.
- Vehicle status copy points Reserved handovers to the panel and keeps Sold non-selectable.

### Sixth-increment validation

- Fleet Portal TypeScript passed: `npx tsc --noEmit`.
- Fleet Portal ESLint passed with no warnings or errors.
- Fleet Portal production build passed: `npm run build` (23 routes).
- The flow was not browser-exercised against live data in this increment. QR camera scanning, buyer receipt presentation, and mobile presentation remain pending.

Still pending: QR camera scanning, buyer receipt presentation, mobile first-sync/incremental-sync presentation checks, platform-admin correction with existing buyer activity, delivery retry worker, late-write review path, legacy reconciliation, and live migration rehearsal. The portal flow must not be described as the complete handover journey until those client and correction phases ship.

## Next implementation boundary

The period schema, core access predicates, reviewed handover backend, and Fleet Portal preparation/review/finalize flow now exist locally. Remaining work is the buyer-facing receipt and mobile presentation, QR camera scanning, platform-admin correction with existing buyer activity, delivery retry, late-write review, and legacy reconciliation. Initial-service-required is represented explicitly in both the API and portal; do not simulate it with fabricated service records.

Use existing per-vehicle reminder configuration, assignment manifests, review queues, and analytics evidence where appropriate. A schema migration alone cannot satisfy privacy: direct APIs, serializers, expense derivation, reminders, media, reporting, and both sync paths must be verified together.

The approved transfer exemption is resolved. Draft expiry/QR lifecycle and correction behavior with existing buyer activity remain phase-0 technical design work. Do not mark phase 0 complete until the final contract and migration mapping are reviewed.

## Verification

- Backend TypeScript build passed.
- Fleet Portal TypeScript and ESLint passed.
- Fleet integration suite: 15 tests passed, including stale-status and manual-Sold rejection assertions.
- Disposable in-memory showroom browser check: inventory has no status mutation; selecting Listed leaves Inventory unchanged until Save; saving advances state; Reserved offers Listed but no Sold option; explanations and success feedback render.
- Browser used the default desktop viewport. Narrow/mobile viewport, other lifecycle screenshots, and the unimplemented handover were not visually verified.
- No deployment, live data migration, or production transfer performed.

## Second increment — ownership attribution foundation

Implemented locally on 11 November 2026:

- Migration 0040 and Drizzle mappings add ownership periods and attribution to eight core vehicle-record tables (extended to media in the third increment).
- Database triggers observe current principal changes and stamp new records; derived accounting inherits source attribution. Cross-period reassignment by ordinary row update is rejected.
- Existing history remains intact, unattributed, and explicitly queued for evidence-based review. No automatic guess based on service date or current vehicle owner is made.
- Tests cover handover boundaries, backdated buyer records, historical expense attribution, rejection of spoofed/reassigned periods, repeated migration, legacy preservation, and principal/current-period constraints.

At the end of this increment, attribution infrastructure existed without access isolation. The third increment below adds core access filtering. The immediate legacy transfer endpoint remains unchanged. Draft/finalize UI, read/write filtering, safe late-write acceptance, migration reconciliation, and full buyer sync delivery are still pending. Do not enable or market the new clean-history handover based on this increment alone.

### Second-increment validation

Backend TypeScript build passed. Ownership tests cover rollback as well as commit. Full backend run: 164 passed, 2 failed, 1 skipped across 37 files. The only failures were existing fixed-date license fixtures whose JWTs had expired relative to the current clock; tests now pass an explicit verification time matching issuance. The corrected license suite passed all 7 tests on focused rerun. The final ownership suite passed both tests. No database migration was executed against live data.


## Third increment — core record isolation

Implemented locally on 11 November 2026:

- Shared period predicates now restrict personal and organization record APIs, serializers, dashboard costs, currency-history relabeling, reminder recalculation/email, and sync. Authorization still requires the existing actor/vehicle checks.
- Personal sync converts inaccessible historical upserts into deletion tombstones, without replaying private payloads. Driver bootstrap and record serialization exclude closed-period rows. Shares granted by a previous personal owner no longer authorize access.
- Media receives ownership attribution. Buyer reads, signed downloads, and attachment linking cannot reuse closed-period showroom media. Fleet Admin retains read-only access to its attributed historical attachments.
- `GET /organizations/{id}/transferred/{vehicleId}/records` returns only the organization's closed-period service, expense, fuel, document, part, and plan records. The existing frozen history endpoint remains available.
- Shared record mutations and vehicle uploads lock/recheck vehicle ownership to serialize against transfer.
- Unattributed legacy rows remain visible only for an untransferred current legacy-baseline vehicle. Previously transferred ambiguous rows require reconciliation; they are not guessed into the buyer's history.
- OpenAPI and both portal-generated API types describe the historical-record endpoint.

Regression coverage exercises buyer list/detail/edit denial, dashboard totals, stale sync payloads, reminder emails, signed media, historical showroom reads, independent new buyer records, and rejection of old attachment reuse.

Still pending: evidence-based legacy reconciliation, draft/review/finalize, explicit initial-service-required plans, immutable warranty terms, recipient lookup/QR, delegated authorization, count exemption, master-field privacy cleanup, complete buyer sync delivery, historical late-review acceptance, correction flow, and mobile integration. The old immediate-transfer endpoint does not satisfy the approved handover contract. This increment must not be advertised as the completed clean-history handover.


### Third-increment validation

Backend build and Fleet Portal/Web TypeScript checks passed; both API type generators passed; `git diff --check` passed. Full backend run: 165 passed, 2 failed, 1 skipped across 38 files. One failure was an old currency test expecting cross-period editing; it now checks current-period correction and post-transfer preservation, including bulk relabeling. The other was an analytics assertion relying on unspecified row order; its comparison now ignores order. Final focused rerun of ownership access, currency API, and fleet analytics: all 13 tests passed. The full suite was not rerun after those corrections. No live migration or deployment was performed.


## Fourth increment — end-to-end vehicle-count exemption

Backend personal vehicle-limit counting excludes vehicles with a transfer audit naming the current buyer. Ordinary active personal vehicles still count. The transfer regression verifies a free buyer can receive a transferred vehicle without consuming the allowance, while one ordinary vehicle exhausts it.

Personal sync vehicle upserts now carry server-controlled `transfer_limit_exempt`; clients persist it with a safe false default. Mobile schema 28 adds the column, clears sync cursors so existing devices replay vehicle events, and excludes exempt vehicles from offline personal allowance counting. Backend build, the focused regression, Fleet Portal types, and the mobile gating test passed. This completes the count exemption only; the reviewed handover flow and full buyer delivery remain pending.
