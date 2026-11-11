# Showroom handover implementation audit

Date: 11 November 2026. Phase 0 investigation, not a completed migration or handover implementation. Product contract: [approved handover plan](../product/frd/showroom-handover-plan.md).

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

## Next implementation boundary

Before exposing handover preparation/completion, finish the period schema and access predicates, legacy reconciliation, draft/revision and delegated permission contracts, independent plan representation, atomic delivery, and admin correction semantics. Initial-service-required needs an explicit model/UI representation; do not simulate it with fabricated service records.

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

- Migration 0040 and Drizzle mappings add ownership periods and attribution to eight core vehicle-record tables.
- Database triggers observe current principal changes and stamp new records; derived accounting inherits source attribution. Cross-period reassignment by ordinary row update is rejected.
- Existing history remains intact, unattributed, and explicitly queued for evidence-based review. No automatic guess based on service date or current vehicle owner is made.
- Tests cover handover boundaries, backdated buyer records, historical expense attribution, rejection of spoofed/reassigned periods, repeated migration, legacy preservation, and principal/current-period constraints.

This is attribution infrastructure, not access isolation. The immediate legacy transfer endpoint and existing record access behavior remain unchanged. Draft/finalize UI, read/write filtering, safe late-write acceptance, migration reconciliation, and full buyer sync delivery are still pending. Do not enable or market the new clean-history handover based on this increment alone.

### Second-increment validation

Backend TypeScript build passed. Ownership tests cover rollback as well as commit. Full backend run: 164 passed, 2 failed, 1 skipped across 37 files. The only failures were existing fixed-date license fixtures whose JWTs had expired relative to the current clock; tests now pass an explicit verification time matching issuance. The corrected license suite passed all 7 tests on focused rerun. The final ownership suite passed both tests. No database migration was executed against live data.
