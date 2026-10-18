# Fleet Maintenance Templates

Plan doc locked via grilling session (14 Oct 2026). Status: **Implemented** (phases 1–7 Done — see Sequencing table). **Amended 16 Oct 2026 (second grilling):** driver-side plan completion logging is now in scope — see locked decision 11. **Amended 18 Oct 2026 (third grilling):** admin catalog and fleet templates pages standardized to one "Maintenance Catalog" contract — see locked decision 12.

## Overview

Predefined maintenance item templates by vehicle class (car, motorcycle, truck, van, bus) for the fleet. Platform seeds global defaults; fleet orgs copy and customize templates in the Fleet Portal; admins assign a template to a vehicle and generate a one-time plan snapshot. Drivers see the pre-populated plan on mobile and can add items from the assigned-template suggested list.

Supersedes nothing; extends `maintenance.md` (owner catalog) and `fleet-management.md` (fleet portal).

---

## Locked decisions

| # | Decision |
|---|----------|
| 1 | Templates are **global** + org-scoped **copies** (same `maintenance_catalog` table, nullable `org_id`) |
| 2 | Primary dimension: **`vehicle_class`** = `car` \| `motorcycle` \| `truck` \| `van` \| `bus`; optional `lifecycle_template` narrowing; `fuel_types[]` filter retained |
| 3 | Platform seeds defaults; orgs copy/customize their own in Fleet Portal |
| 4 | **Manual** assignment per vehicle → **one-time snapshot** plan generation |
| 5 | No cost/price fields on templates — market prices change too often, seeding them would create stale inconsistent data (was `estimated_cost`, cut 14 Oct 2026) |
| 6 | Driver: sees pre-populated plan + can add from assigned-template suggested list |
| 7 | `vehicle_class` lives on `vehicles.vehicle_class` (default `'car'`) |
| 8 | Assignment FK: `organization_vehicles.maintenance_template_id` |
| 9 | Admin portal = global templates; Fleet Portal = org copies + assignment |
| 10 | Priority: **backend + fleet portal first**, mobile driver second |
| 11 | **(16 Oct 2026, second grilling)** Driver plan completion logging is **in scope**: Maintenance tab → Register service with **Report \| Do myself** — plan-linked logs (service record or work-order completion) advance `nextDueMileage`/`nextDueOn`; free-text do-myself logs are orphans and never touch a plan. Contract lives in `fleet-management.md` (Driver Surface Decisions 18–20). |
| 12 | **(18 Oct 2026, third grilling) Cross-portal standardization:** both portals show **"Maintenance Catalog"** (fleet route stays `/maintenance-templates`); one column set/order — Name (key stacked), Class, Lifecycle, Fuel, Interval (merged `d · km`), [Source (fleet only)], Status; filters = class + fuel on both (fleet's lifecycle filter removed; admin gains `?fuel_type=`); `sort_order` removed from admin UI only (kept in API/DB/owner-app ordering; both lists sort class → lifecycle → sort_order → name); fleet row action on a **global** row is **Edit = copy-on-write** (opens the org copy if one exists — matched by case-insensitive name, same rule as `templateSetRows()` — else a prefilled create that clones via `source_template_id`); Copy button removed; canonical labels admin-wide (Petrol/Electric/Hybrid, friendly lifecycle labels, Status `Active`/`Disabled`); fleet new/edit form mirrors admin (name max 80, class, lifecycle, interval time + Day/Month/Year unit select, interval km, fuel types, enabled — no sort order). |

**Template → vehicle match rule:** `vehicle_class` matches AND (`lifecycle_template IS NULL` OR equals vehicle's lifecycle) AND vehicle `fuel_type ∈ fuel_types`.

**Snapshot semantics:** generating a plan copies template rows into `plan_items` once; later template edits do not retroactively change generated plans. Regenerate is skip-based idempotent (items with an existing name are not re-created).

---

## Template → vehicle matching

Assignment stores the FK directly on `organization_vehicles.maintenance_template_id` (manual choice, not auto-derived). The match rule is validated at assignment time: assigning a template whose class/lifecycle/fuel does not match the vehicle is rejected (HTTP 400).

---

## Seed content

### Existing 11 car items → tagged `vehicle_class='car'`, `lifecycle_template=NULL`

Intervals per user research (14 Oct 2026) — values from `0001_maintenance_catalog.sql` + `0002_maintenance_catalog_km.sql` rounded to optimal km figures (km intervals).

| Item | Time | Distance | Fuel types |
|------|------|----------|------------|
| Oil Change | 365 d | 15,000 km | petrol, hybrid_plugin |
| Air Filter (Cabin) | 365 d | 24,000 km | petrol, electric, hybrid_plugin |
| New Tires | 1,825 d | 80,000 km | petrol, electric, hybrid_plugin |
| Brake Change | — | 100,000 km | petrol, electric, hybrid_plugin |
| Brake Fluid | 730 d | 50,000 km | petrol, electric, hybrid_plugin |
| Rotate Tires | 365 d | 10,000 km | petrol, electric, hybrid_plugin |
| Fuel Filter | — | 40,000 km | petrol, hybrid_plugin |
| Wash | 14 d | — | petrol, electric, hybrid_plugin |
| Battery | 1,095 d | 60,000 km | petrol, electric, hybrid_plugin |
| Air Conditioning | 365 d | — | petrol, electric, hybrid_plugin |
| Belts | 1,825 d | 120,000 km | petrol, hybrid_plugin |

### NEW: motorcycle

| Item | Recurring | Time | Distance | Fuel |
|------|-----------|------|----------|------|
| Engine Oil Change | ✓ | 180 d | 5,000 km | petrol |
| Chain Clean & Lube | ✓ | 30 d | 1,000 km | petrol, electric |
| Air Filter | ✓ | 365 d | 10,000 km | petrol |
| Tyre Replacement | ✓ | 1,095 d | 20,000 km | all |
| Brake Pads | ✓ | — | 20,000 km | all |
| Brake Fluid | ✓ | 730 d | — | all |
| Coolant | ✓ | 730 d | 20,000 km | petrol, hybrid_plugin |
| Valve Clearance Check | ✓ | — | 8,000 km | petrol |
| Battery | ✓ | 1,095 d | 30,000 km | all |
| Wash | ✓ | 14 d | — | all |

### NEW: truck

Fuel: `petrol`, `hybrid_plugin` (no `diesel` in the current enum — see Deferred).

| Item | Time | Distance |
|------|------|----------|
| Engine Oil + Oil Filter | 180 d | 10,000 km |
| Fuel Filter | — | 20,000 km |
| Air Filter | 365 d | 30,000 km |
| Brake Adjustment (drums) | — | 30,000 km |
| Brake Fluid | 1,095 d | — |
| Transmission Oil | 730 d | 40,000 km |
| Differential Oil | 730 d | 40,000 km |
| Clutch Service | — | 80,000 km |
| Tyre Replacement | 1,825 d | 80,000 km |
| Rotate Tyres | — | 10,000 km |
| Belts | 1,825 d | 60,000 km |
| Suspension / Shocks | — | 60,000 km |
| Battery | 1,095 d | — |
| Wash | 14 d | — |

### NEW: van (car-derived, heavier duty)

Fuel: `petrol`, `hybrid_plugin`, `electric` as appropriate per item.

| Item | Time | Distance |
|------|------|----------|
| Engine Oil Change | 365 d | 10,000 km |
| Engine Air Filter | 365 d | 20,000 km |
| Cabin Air Filter | 365 d | 20,000 km |
| Tyre Replacement | 1,825 d | 60,000 km |
| Rotate Tyres | — | 10,000 km |
| Brake Change | — | 50,000 km |
| Brake Fluid | 1,095 d | — |
| Battery | 1,095 d | — |
| Transmission Fluid | 730 d | 60,000 km |
| Coolant | 730 d | — |
| Air Conditioning | 365 d | — |
| Wash | 14 d | — |

### Deferred (future work — do not implement now)

- **bus** vehicle class templates
- **Lifecycle-specific variants** (e.g. taxi oil change @ 8,000 km via `lifecycle_template='taxi_fleet'`)
- **`diesel` fuel type** (current enum: petrol / electric / hybrid_plugin; Myanmar trucks/buses often need diesel — separate decision)
- ~~Driver-side plan-item completion logging~~ **moved into scope 16 Oct 2026** (locked decision 11 — driver service records + plan-linked work-order completion)
- Template change propagation to already-generated plans

---

## Backend implementation plan

### Migration `backend/drizzle/0013_maintenance_catalog_fleet.sql` (+ register in `src/db/migrate.ts`)

```sql
ALTER TABLE vehicles ADD COLUMN vehicle_class text NOT NULL DEFAULT 'car';
ALTER TABLE maintenance_catalog ADD COLUMN vehicle_class text NOT NULL DEFAULT 'car';
ALTER TABLE maintenance_catalog ADD COLUMN lifecycle_template text;
ALTER TABLE maintenance_catalog ADD COLUMN org_id uuid REFERENCES organizations(id) ON DELETE cascade;
CREATE INDEX maintenance_catalog_class_idx ON maintenance_catalog(vehicle_class);
CREATE INDEX maintenance_catalog_org_idx ON maintenance_catalog(org_id);
ALTER TABLE organization_vehicles ADD COLUMN maintenance_template_id uuid REFERENCES maintenance_catalog(id) ON DELETE set null;
-- + UPDATE the existing 11 car rows to the rounded intervals in Seed content (e.g. oil_change → 15000, brake_change → 100000, belts → 120000 …), plus re-seed sort_order to match the seed table order
-- + INSERT seed rows for motorcycle/truck/van (org_id NULL, lifecycle_template NULL)
```

- `catalog_key` stays globally UNIQUE — org copies get suffixed keys (`oil_change__a1b2c`: slug via existing `slugify()` + 5-char random).
- `src/db/schema.ts`: add `vehicleClass`, `lifecycleTemplate`, `orgId` to `maintenanceCatalog`; `vehicleClass` to `vehicles`; `maintenanceTemplateId` to `organizationVehicles`.

### New endpoints (`fleet.ts` / `fleet-operations.ts`, all `requireFleetPortal`)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/organizations/:id/maintenance-templates` | Returns **global (org_id NULL) + this org's copies**; query filters `vehicle_class`, `lifecycle_template`, `fuel_type`; response marks `source: "global" \| "org"` |
| POST | `/organizations/:id/maintenance-templates` | Creates org copy; optional `source_template_id` clones a global row (new suffixed key) |
| PATCH | `/organizations/:id/maintenance-templates/:itemId` | Org copies only — 403 on global rows |
| DELETE | `/organizations/:id/maintenance-templates/:itemId` | Org copies only; **409 if assigned** to any `organization_vehicles.maintenance_template_id` |
| PUT | `/organizations/:id/vehicles/:vehicleId/maintenance-template` | `{template_id}` or `null` to clear; validates match rule (class + lifecycle + fuel) |
| POST | `/organizations/:id/vehicles/:vehicleId/maintenance-template/generate` | **Snapshot:** copies template rows → `plan_items` (client-uuid via `newId()`), computes `nextDueOn`/`nextDueMileage` with existing `dueFrom()`, **skips names already present (case-insensitive)** → `{created, skipped}` |

### New driver endpoints (`fleet.ts`, dual-audience `requireFleetClient` — owner or fleet surface)

Owner routes live behind `getAccessibleVehicle`, which 404s any org-linked vehicle, so driver access goes through dedicated `/drivers/*` routes gated on an **active `driver_assignments` row** (else 403 `driver_not_assigned`):

| Method | Path | Notes |
|--------|------|-------|
| GET | `/drivers/vehicles/:vehicleId/plan-items` | `publicPlan` rows for the assigned vehicle |
| POST | `/drivers/vehicles/:vehicleId/plan-items` | Client UUID, `{name, interval_days?, interval_distance?, notes?}`; 422 if neither interval; idempotent by id (201 on replay); due dates via `dueFrom()` |
| GET | `/drivers/vehicles/:vehicleId/suggested-plan-items` | Empty `items` when no template assigned; else the assigned template's **set** (below) |

### Template = a set, not a single row

`maintenance_template_id` stores an **anchor row**, but what it represents is the derived set: all enabled rows (global + this org's copies) whose `vehicle_class` matches the vehicle, whose optional `lifecycle_template` is NULL or equals the link's, and whose `fuel_types` include the vehicle's fuel — deduplicated by case-insensitive name with the **org copy winning** over the global row it was cloned from (`lib/catalog.ts` → `templateSetRows()`). Both generate and the driver suggested list use this same derivation; the anchor only stores lifecycle narrowing (rows are class/fuel filtered live).

### Modified endpoints

- `GET /vehicles/:vehicleId/suggested-plan-items` (`owner.ts`) — now filters by the vehicle's `vehicle_class` **and `org_id IS NULL`** (personal/owner-accessible vehicles never see org copies); response gains `vehicle_class`. Org vehicles can't reach this route anyway (`getAccessibleVehicle` 404s them) — drivers use `/drivers/*` above.
- `POST /vehicles/:vehicleId/plan-items` (`owner.ts`) — **unchanged** (owner-only); driver writes go through `POST /drivers/vehicles/:vehicleId/plan-items`.
- `POST/PATCH /organizations/:id/vehicles` (`fleet.ts`) — accept `vehicle_class` (default `'car'`); PATCH may correct a vehicle's class.
- CSV import — `vehicle_class` optional column, default `'car'`.
- Admin CRUD (`admin.ts`) — accept/return `vehicle_class`, `lifecycle_template`; list scoped to `org_id IS NULL`; PATCH/DELETE of an org copy → 403 `org_copy_readonly` (admin never manages org copies); list accepts `?vehicle_class=` and `?fuel_type=` filters and sorts class → lifecycle → sort_order → name (mirrors the fleet list).
- `publicVehicle` (`lib/serialize.ts`) — gains `vehicle_class`.

### Audience

Fleet template management uses `requireFleetPortal` (strict `dco-fleet`); generate additionally allows `org_mechanic`. Driver `/drivers/*` routes use `requireFleetClient` (owner **or** fleet surface — drivers hold owner-surface tokens) plus the active-assignment check.

### Backend tests

`backend/test/fleet.test.ts` + catalog tests:

- Org copy isolation (PATCH global row as org → 403)
- Delete-when-assigned → 409
- Assignment validation (wrong class → 400)
- Generate snapshot (duplicate-name skip, due computation)
- Suggested-items template filtering (assigned vs unassigned vehicle)
- Driver plan-item write allowed (active assignment) / denied (no assignment)
- `vehicle_class` default `'car'` on create, CSV import default

---

## Fleet Portal implementation plan

1. **Page `/maintenance-templates`** (sidebar label **"Maintenance Catalog"**, `org_admin` / `org_manager`):
   - Table: name (catalog_key stacked beneath), class, lifecycle (friendly labels), fuel (badges), interval (merged `365 d · 15,000 km`), source badge (`Global` / `Org copy`), status (`Active` / `Disabled`).
   - Filters: class, fuel (lifecycle filter removed — third grilling).
   - Actions: **Edit** on every row — global rows use **copy-on-write** (org copy exists → edit it; else prefilled create cloning via `source_template_id`), org rows edit + standalone Delete. Header action **"Add item"**; modal titles "Add catalog item" / "Edit catalog item". Copy button removed.
   - Form mirrors the admin form: Name (max 80), Vehicle class, Lifecycle, Interval (time) + Day/Month/Year unit, Interval (km), Fuel Types (min 1), Enabled — no sort order.
2. **Vehicle detail `/vehicles/[id]`:**
   - Template select (options pre-filtered by vehicle class + lifecycle + fuel; shows name + intervals) → PUT assign / clear.
   - **"Generate maintenance plan"** button (confirm modal showing item count) → POST generate → toast `{created, skipped}`; button remains (endpoint is skip-based idempotent).
3. **Vehicles create modal** (`vehicles/page.tsx`): add `vehicle_class` Select (car / motorcycle / truck / van / bus, default car).
4. **Hooks/types:** `useMaintenanceTemplates`, `useAssignTemplate`, `useGeneratePlan`, `VehicleCreateInput.vehicle_class` in `lib/api/{types,hooks}.ts` after `npm run gen:api`.

---

## Admin Portal (web/) — small

`src/app/(admin)/catalog/page.tsx` + hooks: columns/inputs `vehicle_class` (select), `lifecycle_template` (select, optional). Standardized per locked decision 12: Name cell stacks `catalog_key` beneath the name (no separate Key column), Time + Distance merged into one **Interval** column, **Sort Order column and form field removed** (hidden — `sort_order` stays in API/DB), filters = class + `?fuel_type=`, list sorted class → lifecycle → sort_order → name. Global-only (backend enforces `org_id = NULL`).

---

## Mobile driver plan (phase 2 — shipped; completion logging added 16 Oct 2026)

Scope **as shipped**: view plan + add from suggested, no edits of portal-generated items. **Amended (second grilling):** completion logging is now in scope — the driver Maintenance tab gains a **Register service** form with **Report | Do myself** branches (locked decision 11); plan-linked logs advance due dates, free-text logs never touch a plan. Driver mode itself was realigned to personal-mode parity (four tabs, quick actions) — see `fleet-management.md` Driver Surface Decisions 16–24. The screens below remain the plan-view/suggested-add foundation.

- `DriverMyVehicleScreen` (`driver_my_vehicle_screen.dart:100`): add FleetTile **"Maintenance plan"** → push new `DriverMaintenancePlanScreen`.
- New screens in `features/fleet/presentation/screens/` (online-first, Dio — per AGENTS.md rules 4/6, NOT Drift/outbox, not management features):
  - `DriverMaintenancePlanScreen` — list plan items (**GET `/drivers/vehicles/:id/plan-items`**) grouped Overdue / Due soon / Scheduled using design-system status tokens.
  - "Add suggested" bottom sheet — GET `/drivers/vehicles/:id/suggested-plan-items` → POST `/drivers/vehicles/:id/plan-items` with client UUID.
- `features/fleet/domain`: `DriverPlanItem` + `SuggestedPlanItem` entities; repository methods in `fleet_repository.dart` / `fleet_repository_impl.dart`.
- Fleet mode only; personal/owner maintenance flows untouched.
- Tests: repository mapping + provider tests; `flutter analyze` clean; `flutter test` (baseline 296/296 → more).

---

## Contracts & docs (same change)

- `architecture/openapi.yaml` — new paths + extend `MaintenanceCatalogItem(Write)`, `suggested-plan-items` response, vehicle create/update; run `npm run gen:api` in `fleet-portal/` **and** `web/`.
- Amend: `product/frd/maintenance.md` (vehicle-class templates, driver add), `product/frd/fleet-management.md` (templates page, assignment, snapshot flow), `architecture/data-model.md` (three schema changes), `docs/mvp-as-built.md` if it lists catalog fields.

---

## Sequencing & verification

| Phase | Work | Verify | Status |
|-------|------|--------|--------|
| 1 | Migration 0013 + schema + seeds | migrate runs clean | **Done** (61/61 tests, tsc clean, double-migrate idempotent) |
| 2 | Backend endpoints + modified routes + tests | `npm test`, `tsc` | **Done** (61/61 tests, tsc clean) |
| 3 | OpenAPI + `gen:api` (fleet-portal, web) | generated types diff reviewed | **Done** (new paths + VehicleClass/LifecycleTemplate/MaintenanceTemplate schemas; tsc clean, lint 0 errors in both apps) |
| 4 | Fleet Portal UI (templates page, assignment, generate, vehicle_class) | lint / tsc / build + local render | **Done** (`/maintenance-templates` page with filters/copy/edit/delete; vehicle detail template card with assign/clear + generate confirm; vehicle_class in create modal; sidebar now h-screen with sticky top/bottom and scrollable middle nav per user request; `maintenance_template_id` added to org vehicle serializer) |
| 5 | Admin catalog page fields | lint / tsc / build | **Done** (`web/` catalog page: Class + Lifecycle columns, vehicle-class filter wired to `?vehicle_class=`, create/edit form selects for `vehicle_class` + optional `lifecycle_template`; number-input spinners/steppers removed globally in `web/` + `fleet-portal/` per user request) |
| 6 | **Mobile driver** (after deploy) | `flutter analyze`, `flutter test` | **Done** (`features/fleet/`: `DriverPlanItem`/`DriverSuggestedPlanItem` entities, 3 repo methods on `/drivers/vehicles/{id}/*`, plan screen with overdue chips + suggested multi-select add via client UUID, My Vehicle entry tile, en+l10n strings, 302/302 tests) |
| 7 | Docs / FRD updates | — | **Done** (amended `frd/maintenance.md`, `frd/fleet-management.md`, `architecture/data-model.md`, `docs/mvp-as-built.md` per Contracts & docs; plus `docs/app-shell.md` driver screens, `mobile/AGENTS.md` driver surface, `CLAUDE.md` FRD list + portal pages, `architecture/api.md` audiences) |
| 8 | **Driver maintenance logging + portal loop** (second grilling: driver service records, WO completion cost/auto-SR/plan advance, org service-record GET, portal Service-history + Plan cards, personal-garage ban, shift retirement) | `npm test`, `tsc`, `flutter analyze`, `flutter test`, portal lint/build | **Planned** (`fleet-management.md` Driver Surface Decisions 15–24; work packages WP1–WP4) |
| 9 | **Cross-portal standardization** (third grilling — locked decision 12: shared naming/columns/filters/labels, admin `?fuel_type=` + class-first sort, sort-order UI removal, fleet copy-on-write Edit, fleet form mirrors admin) | `npm test` (backend), lint + build (web, fleet-portal) | **Done** (67/67 backend tests incl. fuel filter + class-order assertions; both portals lint clean and build) |

## Risks

1. No `diesel` fuel type — trucks/buses may need it later (separate decision).
2. No cost fields on templates — deliberately cut: market prices change too often and seeded costs would go stale and inconsistent (decided 14 Oct 2026).
3. Depends on uncommitted workstream-3 state being committed first to keep diffs reviewable.
4. `organization_vehicles.maintenance_template_id` is `ON DELETE set null` — deleting a template (when allowed) clears assignment but never touches generated plans (snapshot semantics).
