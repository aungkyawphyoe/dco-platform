# Fleet Maintenance Templates

Plan doc locked via grilling session (14 Oct 2026). Status: **Planned — not implemented.**

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
- Driver-side plan-item completion logging (completion today is portal-side / owner-side only)
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
- Admin CRUD (`admin.ts`) — accept/return `vehicle_class`, `lifecycle_template`; list scoped to `org_id IS NULL`; PATCH/DELETE of an org copy → 403 `org_copy_readonly` (admin never manages org copies); list accepts `?vehicle_class=` filter.
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

1. **New page `/maintenance-templates`** (sidebar; `org_admin` / `org_manager`):
   - Table: name, class, lifecycle, fuel types, intervals, source badge (`Global` / `Org copy`), enabled.
   - Filters: class, lifecycle, fuel, source.
   - Actions: **Copy →** (clone global → editable org copy), Edit / Delete (org copies only), Create new.
2. **Vehicle detail `/vehicles/[id]`:**
   - Template select (options pre-filtered by vehicle class + lifecycle + fuel; shows name + intervals) → PUT assign / clear.
   - **"Generate maintenance plan"** button (confirm modal showing item count) → POST generate → toast `{created, skipped}`; button remains (endpoint is skip-based idempotent).
3. **Vehicles create modal** (`vehicles/page.tsx`): add `vehicle_class` Select (car / motorcycle / truck / van / bus, default car).
4. **Hooks/types:** `useMaintenanceTemplates`, `useAssignTemplate`, `useGeneratePlan`, `VehicleCreateInput.vehicle_class` in `lib/api/{types,hooks}.ts` after `npm run gen:api`.

---

## Admin Portal (web/) — small

`src/app/(admin)/catalog/page.tsx` + hooks: add columns/inputs `vehicle_class` (select), `lifecycle_template` (select, optional); filter by class. Global-only (backend enforces `org_id = NULL`).

---

## Mobile driver plan (phase 2 — after backend + portal ship)

Scope: **view plan + add from suggested. No completion logging, no edits of portal-generated items** (completion via work orders / service records is future work).

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
| 3 | OpenAPI + `gen:api` (fleet-portal, web) | generated types diff reviewed | — |
| 4 | Fleet Portal UI (templates page, assignment, generate, vehicle_class) | lint / tsc / build + local render | — |
| 5 | Admin catalog page fields | lint / tsc / build | — |
| 6 | **Mobile driver** (after deploy) | `flutter analyze`, `flutter test` | — |
| 7 | Docs / FRD updates | — | — |

## Risks

1. No `diesel` fuel type — trucks/buses may need it later (separate decision).
2. No cost fields on templates — deliberately cut: market prices change too often and seeded costs would go stale and inconsistent (decided 14 Oct 2026).
3. Depends on uncommitted workstream-3 state being committed first to keep diffs reviewable.
4. `organization_vehicles.maintenance_template_id` is `ON DELETE set null` — deleting a template (when allowed) clears assignment but never touches generated plans (snapshot semantics).
