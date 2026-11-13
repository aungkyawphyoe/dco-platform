# Showroom handover implementation audit

Date: 11–13 November 2026. This audit records incremental implementation evidence. See “Current status” for the consolidated state; historical pending lists describe only the point in time of their section. Product contract: [approved handover plan](../product/frd/showroom-handover-plan.md).

## Current status (13 November 2026)

**Implemented locally:** ownership-period isolation and retained showroom history; backend reviewed handover drafts, revision review and completion; Fleet Portal preparation, permission controls and QR scan; buyer vehicle/plan/warranty/receipt sync and mobile presentation; transfer-count exemption; delivery retry; platform-admin correction; and legacy transfer review endpoints. Migration 0042 and the documented fresh-database rehearsal are present in the commit history. Automated checks are documented per increment and are not a substitute for deployed acceptance testing.

**Still incomplete or unverified:** late-write acceptance does not apply submitted records; the legacy “reconciliation” actions change transfer status rather than backfilling ownership attribution; manual browser/device smoke test, production/staging rollout, load testing, and security review are not evidenced as completed. The implementation changes should not be described as a fully production-validated workflow until these are addressed.

## Delivered first increment (historical status)

- Inventory status badges/counts/filters remain; inline mutation controls, bulk status UI, its unused hook, and unused selection checkboxes are removed.
- Vehicle Detail uses `fleet-portal/src/components/vehicles/vehicle-status.tsx`: readable lifecycle explanations, allowed-next-state selection, explicit Save, loading/success/error states, and no manual Sold action.
- `backend/src/modules/fleet.ts` status PATCH accepts optional `expected_status`, serializes updates under vehicle then organization-link locks, rejects stale state with 409, rejects Sold with `handover_required`, and writes its change event transactionally.
- OpenAPI and Fleet Portal generated types reflect the status contract.
- At this increment the old immediate-transfer endpoint still existed. Later, the reviewed handover backend retired it with `410 handover_required` (see fifth increment).

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

## Seventh increment — personal buyer presentation (mobile)

Implemented locally on 12 November 2026:

- Mobile schema 29 adds `initial_service_required` to plan items and sync-managed `vehicle_warranties` / `handover_receipts` tables. The additive migration checks existing columns/tables before changing them.
- The personal `ChangeApplier` applies `warranty`, `handover_receipt`, and the plan's `initial_service_required` flag from the buyer's change log. Unknown entity types remain safely ignored.
- Vehicle Detail shows warranty and handover-receipt cards when those rows exist. A read-only receipt screen shows the sale date, handover odometer, copied plan, frozen warranty terms, and the clean-history note; it never exposes showroom service or expense records.
- Handover plan items render an explicit “Initial service required” state instead of a fabricated due date/mileage. Logging a linked service clears the local flag; the backend remains authoritative and re-emits the cleared plan item.
- Profile has an Account code screen showing the signed-in user ID as a QR code, with copy support and copy that states it identifies the account only — not login, consent, or garage access.
- Sync tests cover a first handover pull (vehicle + plan + warranty + receipt) and an incremental pull (cleared initial service + updated warranty terms), and verify stale remote changes cannot overwrite newer local rows.

### Seventh-increment validation

- `flutter analyze` reports no errors.
- Handover sync, schema migration, maintenance, and due-calculator tests pass.
- Full mobile suite: 563 passed, 2 failures in `test/features/settings/units_formats_screen_test.dart`. Those failures assert a “Loading currency…” string that the settings screen stopped rendering in an earlier change; they are unrelated to handover.

Still pending: QR camera scanning in Fleet Portal, platform-admin correction with existing buyer activity, delivery retry worker, late-write review path, legacy reconciliation, live migration rehearsal, and device/browser end-to-end verification.

## Eighth increment — QR camera scanning and platform-admin correction

Implemented locally on 12 November 2026:

### Fleet Portal QR camera scanning
- Updated `next.config.ts` Permissions-Policy to allow camera access (`camera=(self)`)
- Added `QrScanner` component using `html5-qrcode` library with environment-facing camera
- Integrated QR scanning into `StartHandover` flow: new "Scan QR" mode opens camera, reads buyer's account code QR, auto-populates account ID field
- Buyer finds their account code QR in the AutoX mobile app under Profile → Account code
- Manual entry remains available as fallback; QR scanning is an optional convenience

### Platform-admin handover correction
- New endpoint: `POST /admin/handovers/:handoverId/correct` (requires `dco-admin` audience)
- Two correction actions:
  - **Revert**: Returns vehicle to original showroom organization, marks transferred_vehicles as reverted, sends delete sync events to buyer for vehicle/plan/warranty/receipt
  - **Reassign**: Moves vehicle to a different organization/buyer (only allowed if buyer has NO activity since handover - no services, expenses, fuel logs, or plan changes)
- Validation: Checks buyer's activity since handover completion; blocks reassign if any activity exists
- Sync integration: Emits delete change log events for buyer's vehicle, plan items, warranty, and receipt so mobile apps remove the data
- Transferred vehicles table extended with `status`, `revertedAt`, `revertedBy`, `revertReason` columns (migration 0042)
- Vehicle ownership updated via `organizationVehicles` table; buyer's `userId` on vehicles table preserved

### Eighth-increment validation
- Backend TypeScript and full test suite pass: 170 passed, 1 skipped
- Fleet Portal TypeScript, ESLint, and production build pass
- Mobile handover sync tests and maintenance tests pass
- Migration 0042 applies cleanly

Still pending: delivery retry worker, late-write review path, legacy reconciliation, live migration rehearsal, and browser/device end-to-end verification.

## Ninth increment — delivery retry worker

Implemented locally on 12 November 2026:

### Delivery retry worker
- New module: `backend/src/modules/handover-delivery-worker.ts`
- Registered in `backend/src/server.ts` startup with 30-second interval
- Processes queued `vehicle_handover_events` (max 100 per cycle, max 10 attempts)
- Exponential backoff: 5s → 10s → 20s → ... → 5min cap
- Dead-letter after max attempts (status = "dead", requires manual intervention)
- Delivers all four event types: vehicle, plan, warranty, handover_receipt
- Uses existing `recordChange` to emit buyer sync changes
- Reconstructs buyer-facing vehicle payload from frozen `handover.vehicleSnapshot`
- Logs each attempt/failure via Fastify logger

### Ninth-increment validation
- Backend TypeScript and full test suite pass: 170 passed, 1 skipped
- Fleet Portal build passes
- Mobile handover sync tests pass

Still pending: late-write review path, legacy reconciliation, live migration rehearsal, and browser/device end-to-end verification.

## Tenth increment — late-write review path

Implemented locally on 12 November 2026:

### Late-write review path
- New module: `backend/src/modules/late-write-review.ts`
- Registered in `backend/src/app.ts` under `/v1`
- Endpoints:
  - `POST /organizations/:id/late-write-reviews` — create a review for a transferred vehicle
  - `GET /organizations/:id/late-write-reviews` — list reviews (filter by status, vehicle)
  - `POST /organizations/:id/late-write-reviews/:reviewId/resolve` — accept/reject with reviewer note
- Validation:
  - Vehicle must have been transferred from this organization
  - Vehicle must not have an active organization link (otherwise use normal path)
  - Supported entity types: service_record, expense, fuel_log, document, plan_item, part, fuel_type
- Flow:
  1. Showroom submits record with reason → creates pending review
  2. Buyer/platform admin reviews via Fleet Portal
  3. Resolution currently records `accepted` or `rejected` and reviewer metadata only. `applyLateWriteReview` returns placeholder success values; it does not write the submitted service, expense, fuel, document, plan, part, or fuel-type data.
  4. Therefore acceptance is not a completed late-write workflow and must not be represented as applying a record.
- Review data stored in existing `organization_reviews` table (reused from org admin review flow)

### Tenth-increment validation
- Backend TypeScript and full test suite pass: 170 passed, 1 skipped
- Fleet Portal build passes
- Mobile handover sync tests pass

Still pending: legacy reconciliation, live migration rehearsal, and browser/device end-to-end verification.

## Eleventh increment — legacy reconciliation

Implemented locally on 12 November 2026:

### Legacy reconciliation
- New module: `backend/src/modules/legacy-reconciliation.ts`
- Admin endpoints in `backend/src/modules/admin.ts`:
  - `GET /admin/legacy-reconciliation` — lists pre-handover transfers (no handoverId), filterable by status
  - `POST /admin/legacy-reconciliation/resolve` — mark a legacy transfer as "reconciled" or "quarantined" with reviewer note
- Reconciliation logic (`legacy-reconciliation.ts`):
  - Finds transferred_vehicles rows without handoverId (pre-handover system transfers)
  - Analyzes buyer activity post-transfer: service records, expenses, fuel logs
  - High confidence: buyer has services/expenses/fuel after transfer date
  - Medium confidence: buyer has plan items or ownership period record
  - None: no attributable activity — requires manual review
- Admin UI can bulk-resolve with reviewer notes; audit trail recorded

### Eleventh-increment validation
- Backend TypeScript and full test suite pass: 170 passed, 1 skipped
- Fleet Portal build passes
- Mobile handover sync tests pass

Still pending: live migration rehearsal, and browser/device end-to-end verification.

## Twelfth increment — live migration rehearsal

Performed locally on 12 November 2026:

### Live migration rehearsal
- Created fresh PostgreSQL database `dco_migration_rehearsal`
- Ran all migrations (0000_init.sql through 0042_handover_correction.sql) via `tsx src/db/run-migrate.ts`
- Verified all 69 tables created including new handover tables:
  - `vehicle_handovers` (drafts, reviewed completion, frozen evidence)
  - `vehicle_handover_events` (delivery tracking with retry support)
  - `vehicle_warranties` (frozen warranty terms)
  - `transferred_vehicles` extended with `status`, `reverted_at`, `reverted_by`, `revert_reason`, `status` index
  - `plan_items` extended with `initial_service_required` column
- Full backend test suite passes: 170 passed, 1 skipped across 39 files
- Fleet Portal TypeScript, ESLint, and production build pass
- Mobile handover sync tests pass

### Migration validation
- All migrations (0000 through 0042) apply cleanly in sequence
- No data loss or constraint violations
- New columns have correct defaults and constraints
- Unique partial index on `vehicle_handovers` for single pending draft per vehicle
- Check constraints on status, warranty_choice, reviewed_revision
- Foreign keys properly reference organizations, users, vehicles, warranty_templates

### Still pending (at that increment)
- Browser/device end-to-end verification (smoke test with disposable showroom vehicle and personal account)

## Thirteenth increment — end-to-end verification plan

**Date:** 12 November 2026

### Verification status: Automated tests ✅ | Manual smoke test ⏳ (requires staging deployment)

Since automated CI/CD pipeline and staging environment are not available in this session, the following documents the complete end-to-end verification plan that a QA engineer would execute against a deployed staging environment.

### Prerequisites for manual smoke test
- Backend deployed to staging (API at `https://api-staging.autoxmm.com`)
- Fleet Portal deployed to staging (at `https://fleet-staging.autoxmm.com`)
- Mobile app built with staging API base URL
- PostgreSQL database with migrations 0000–0042 applied
- Two test accounts: `seller@test.local` (showroom admin), `buyer@test.local` (personal owner)
- One reserved showroom vehicle

---

### Test Case 1: Buyer Lookup by Account ID (Manual Entry)

**Steps:**
1. Login to Fleet Portal as showroom admin
2. Navigate to reserved vehicle detail page
3. Open "Buyer handover" panel
4. Select "Account ID" lookup mode
5. Enter buyer's account UUID (from mobile app Profile → Account code)
6. Click "Find buyer"
7. Verify: buyer name, masked email/phone displayed, "Eligible buyer" badge
8. Click "Start handover draft"

**Expected:** Draft created, vehicle stays Reserved, plan seeded from showroom reminders, sale date = today, mileage = current odometer

---

### Test Case 2: Buyer Lookup by QR Scan

**Steps:**
1. On buyer's mobile app: Profile → Account code → shows QR
2. On Fleet Portal: Select "Scan QR" mode in buyer lookup
3. Grant camera permission
4. Point camera at buyer's QR code
5. Verify: Account ID auto-populated, lookup executes
6. Verify: Same buyer identity shown as Test Case 1

---

### Test Case 3: Plan Editor with Initial Service Required

**Steps:**
1. In draft, go to "Maintenance plan for the buyer" section
2. Add plan item: "Oil change", no due date/mileage, enable "Initial service required"
3. Save draft
4. Verify: Plan item shows "Initial service required — baseline unknown"
5. Add another item with due date and recurring interval
6. Save draft
7. Verify: Both items saved, readiness checks pass

---

### Test Case 4: Warranty Selection

**Steps:**
1. In draft, go to Warranty section
2. Select "Reviewed warranty terms"
3. Choose a warranty template
4. Verify: Frozen terms displayed (duration, mileage limit, coverage, exclusions, workshops)
5. Save draft
6. Switch to "No warranty"
7. Verify: "No warranty" selected, no template shown

---

### Test Case 5: Readiness Checks & Review

**Steps:**
1. With complete plan + warranty, click "Refresh checks"
2. Verify: "No blocking issues. Review this revision to authorize completion."
3. Click "Review revision"
3. Verify: "Revision N reviewed" badge appears

---

### Test Case 6: Completion & Receipt

**Steps:**
1. Check "I checked the recipient and vehicle details..." checkbox
2. Click "Complete handover"
3. Verify: Success toast, "Handover complete" screen
4. Verify receipt shows: sale date, handover mileage, plan items, warranty, completed timestamp
5. Verify vehicle status in Fleet Portal: no longer shows handover panel (vehicle left showroom)

---

### Test Case 7: Buyer Mobile Sync (First Pull)

**Steps:**
1. On buyer's mobile app: login as buyer
2. Open Sync Status → pull to refresh
3. Wait for sync to complete
4. Navigate to Garage → select the handed-over vehicle
5. Verify Vehicle Detail shows:
   - Vehicle info (name, plate, mileage at handover)
   - Warranty card (if warranty chosen)
   - Handover receipt card
6. Tap Handover Receipt → verify read-only screen with sale date, mileage, plan, warranty
7. Tap Maintenance Plan → verify plan items, "Initial service required" item shows correctly (no due date)
8. Tap Warranty → verify frozen terms displayed

---

### Test Case 8: Initial Service Logging Clears Flag

**Steps:**
1. On buyer's mobile app: log a service for the "Initial service required" plan item
2. Verify: Plan item no longer shows "Initial service required", now shows next due date/mileage based on recurrence
3. Pull to refresh sync → verify server also cleared the flag (plan item updated)

---

### Test Case 9: Incremental Sync Updates

**Steps:**
1. In Fleet Portal: create new handover for another vehicle, complete it
2. On buyer's mobile app: pull to refresh
3. Verify: New vehicle appears in garage with warranty + receipt
4. In Fleet Portal: use admin correction to revert a handover
5. On buyer's mobile app: pull to refresh
6. Verify: Vehicle removed from garage, plan/warranty/receipt deleted locally

---

### Test Case 10: Platform-Admin Correction

**Steps:**
1. As platform admin: call `POST /admin/handovers/:id/correct` with `action: "revert"`
2. Verify: Vehicle returned to showroom, buyer's data deleted via sync
3. As platform admin: call with `action: "reassign"` (only if buyer has no activity)
4. Verify: Vehicle moved to new org/buyer

---

### Test Case 11: Late-Write Review

**Steps:**
1. As showroom: submit service record for transferred vehicle via `POST /organizations/:id/late-write-reviews`
2. Verify: Review created in "pending" state
3. As admin: resolve review via `POST /organizations/:id/late-write-reviews/:id/resolve` with `action: "accept"`
4. Verify: Review status changes only; record application is not implemented (this step is a known gap, not a passing acceptance case).

---

### Test Case 12: Legacy Reconciliation

**Steps:**
1. As admin: GET `/admin/legacy-reconciliation`
2. Verify: Lists pre-handover transfers (no handoverId)
3. POST `/admin/legacy-reconciliation/resolve` with `action: "reconcile"` or `"quarantine"`
4. Verify: Status updated, audit trail recorded

---

### Regression Checks
- [ ] Legacy immediate transfer endpoint returns `410 handover_required`
- [ ] Duplicate pending drafts blocked (single draft per vehicle)
- [ ] Stale revision blocked on review/complete
- [ ] Open work orders block handover
- [ ] Delegated completion permission enforced
- [ ] Vehicle count exemption works (buyer can receive without using allowance)
- [ ] Delivery retry worker processes queued events
- [ ] Stale remote changes don't overwrite newer local data (mobile)

---

### Test Data Cleanup
- Delete test vehicles, handovers, buyer/seller accounts
- Reset database to clean state for next test run

---

### Go/No-Go Criteria for Production
| Criterion | Status |
|-----------|--------|
| Automated checks | Historical per-increment results are listed above; the mobile suite had 2 unrelated failures at the time recorded. Re-run current suites before release. |
| Fresh-database migration rehearsal | Reported as passed locally for migrations 0000–0042; not a staging/production rehearsal. |
| Manual smoke test (this plan) | ⏳ Requires staging deployment |
| Load/stress test | ⏳ Not performed |
| Security audit | ⏳ Not performed |
| Rollback readiness | Not verified; additive migrations alone do not establish a tested rollback procedure. |

---

**Next step:** After completing the late-write and attribution gaps, arrange an authorized staging deployment and execute the manual browser/device smoke cases. The hostnames and environment identifiers above are examples from the earlier plan, not verified active endpoints.
