# Stats Module

## Overview

Stats is the read-only analytics section for the **active vehicle**. It renders KPI cards and charts over data the owner already logged — no new record types, no stats API. Three screens, all reached from the **hamburger menu → Stats** section:

- **Fuel Stats** (`/refuel-stats`) — adaptive: electric vehicle → charge KPIs, petrol / hybrid plugin → refuel KPIs
- **Maintenance Stats** (`/maintenance-stats`)
- **Expense Stats** (`/expense-stats`)

Shape reference (demo, logged in): `https://autozis.com/app/charge-stats`, `/app/refuel-stats`, `/app/maintenance-stats`, `/app/expense-stats`. Adopt the shape only — Autozis extras we deliberately skip are listed in Out of Scope.

Aggregation runs **locally** (Drift/SQLite). There are no `/v1/stats` endpoints.

**The odometer dependency:** distance and efficiency KPIs need an odometer reading on fuel logs, which MVP deliberately excluded. This FRD therefore **carries the contract amendment**: an optional `odometer` field is added to refuel/charge logs, and the "no odometer / no efficiency KPIs" prohibitions in `product/frd/fuel.md`, `architecture/data-model.md`, `product/production-scope.md`, and `product/frd/README.md` are updated to match. Stats itself owns the efficiency KPIs; the Fuel module only captures the field.

**Status (30 Sep 2026): Placeholder.** Routes, drawer entries, and three placeholder screens exist (`refuel_stats_screen.dart`, `maintenance_stats_screen.dart`, `expense_stats_screen.dart`). No KPIs, charts, filters, or odometer field are built. Status index: `product/frd/README.md`.

---

# Objectives

- Let the owner see what the active vehicle costs to run — fuel, maintenance, other spend — without building spreadsheets
- Turn raw logs into trends: monthly cost, consumption, cost per distance
- Keep the feature honest on sparse data: derived KPIs show `—` instead of a confident wrong number
- Stay offline-first: every number is computed on-device from local data

---

# In Scope

- Drawer section **Stats**: Fuel Stats, Maintenance Stats, Expense Stats (existing entries; "Refuel Stats" renamed to **Fuel Stats**)
- Year / Month filters (default **All / All**), data-driven option lists
- KPI card grids per screen (exact lists below)
- Two charts per screen, rendered with **fl_chart** (new pubspec dependency)
- **What do these stats mean?** definitions modal, one per screen
- **Optional odometer** on the refuel/charge log form (add + edit), feeding distance/consumption KPIs
- Local Drift aggregation over `fuel_logs`, `service_records` + `service_record_items`, `expenses`
- Analytics events for screen open, period change, definitions open

---

# Out of Scope

- **Table view** (Autozis Charts/Table toggle) — charts only in this slice
- **Compare By** dimensions (location, fuel type, category) — no location field exists; category split is deferred
- **Charge form extension**: home vs away, AC/DC, duration, temperature, battery %, estimated range — none are collected; all related Autozis KPIs (incl. Temperature Insights) are out
- **Insights / cross-screen** view (combined cost per 100 km across fuel + maintenance + expenses)
- Server-side aggregation endpoints; stats on web admin / family dashboard / fleet portal
- PDF / CSV export
- Cost-per-unit trend chart, monthly volume/distance charts, monthly count charts
- Odometer on maintenance or expense forms (service records already have one)
- Making odometer required, or backfilling odometer on existing logs
- Premium gating (stats is free — see Business Rules)
- Tapping charts/cards to drill into filtered record lists

---

# User Personas

- Everyday Owner
- Family Manager (own vehicles only)
- Car Enthusiast

---

# User Stories

### US-STAT-001

As a user,

I want to see my monthly fuel/charging cost trend for the active vehicle

So that I know how my running costs change over time.

### US-STAT-002

As a user,

I want to see fuel consumption (l/100 km) and cost per 100 km when my logs have odometer readings

So that I can spot inefficiency instead of guessing.

### US-STAT-003

As a user,

I want to see maintenance spend, top service type, and the most expensive job

So that I understand where repair money goes.

### US-STAT-004

As a user,

I want to see expense totals by category with a monthly trend

So that I can review non-fuel, non-maintenance spending patterns.

### US-STAT-005

As a user,

I want every KPI explained in plain language

So that "avg consumption" or "cost per 100 km" never leaves me guessing.

### US-STAT-006

As a user,

I want an optional odometer field when I log a refuel or charge

So that distance-based stats become available without making every quick entry heavier.

---

# Functional Requirements

## Common shell (all three screens)

- App bar title: **Fuel Stats** / **Maintenance Stats** / **Expense Stats**
- Header line shows the active vehicle nickname; switching vehicle (elsewhere) recomputes on next open
- Filter row: **Year** dropdown, **Month** dropdown (see Filter semantics)
- **What do these stats mean?** action in the header opens the definitions modal
- KPI card grid (2 columns), then the two charts
- Screens are read-only: no editing, no drill-through navigation in this slice
- Entitlement: **free** — no plan gate, no client or server check

## Filter semantics

- Period match is by the section's date field, device-local calendar: fuel → `logged_on`, maintenance → `serviced_on`, expense → `incurred_on`
- Year options: `All` + distinct years present in that screen's records for the active vehicle, descending
- Month options: `All` + distinct months present within the selected year (Year = `All` → months present in any year)
- Default on open: **Year = All, Month = All** (lifetime view, Autozis parity)
- Month filter matches calendar month across years when Year = `All` (Year=All + Month=Jan → every January in history)
- Changing a filter recomputes locally and fires `stats_period_changed`

## Fuel Stats (adaptive)

Mode by active vehicle `fuel_type` (same split as the Fuel module):

| Vehicle `fuel_type` | Mode |
|---|---|
| `electric` | Charge |
| `petrol`, `hybrid_plugin` | Refuel |

### KPI cards — Refuel mode

| # | KPI | Value | Sub-value | Gate |
|---|-----|-------|-----------|------|
| 1 | Total refuels | count of logs in period | — | always |
| 2 | Total cost | Σ cost | avg cost per unit (total ÷ total volume) | always (sub needs volume > 0) |
| 3 | Total volume | Σ amount, per unit | — | always; mixed L/gal in period → one line per unit |
| 4 | Total distance | Σ segment deltas | — | ≥ 2 segments |
| 5 | Avg consumption | Σ segment amounts ÷ Σ segment deltas × 100 (l/100 km or mpg) | — | ≥ 2 segments; all segment amounts same unit |
| 6 | Cost per 100 distance | Σ segment costs ÷ Σ segment deltas × 100 | — | ≥ 2 segments |
| 7 | Most expensive refuel | max cost | its date | always (ties → most recent) |

### KPI cards — Charge mode

| # | KPI | Value | Sub-value | Gate |
|---|-----|-------|-----------|------|
| 1 | Total charges | count of logs in period | — | always |
| 2 | Total cost | Σ cost | avg cost per kWh (total ÷ total kWh) | always (sub needs kWh > 0) |
| 3 | Total kWh | Σ amount | — | always |
| 4 | Total distance | Σ segment deltas | — | ≥ 2 segments |
| 5 | Avg efficiency | Σ segment deltas ÷ Σ segment amounts (km/kWh or mi/kWh) | — | ≥ 2 segments |
| 6 | Cost per 100 distance | Σ segment costs ÷ Σ segment deltas × 100 | — | ≥ 2 segments |
| 7 | Most expensive charge | max cost | its date | always (ties → most recent) |

### Charts (2)

1. **Monthly cost** — bar; x = months in period chronological, y = Σ log cost in month
2. **Efficiency trend** — line; refuel mode: monthly avg consumption; charge mode: monthly efficiency; only months containing ≥ 1 segment contribute a point; months without one are **gaps** (no interpolation)

## Maintenance Stats

### KPI cards

| # | KPI | Value | Sub-value | Gate |
|---|-----|-------|-----------|------|
| 1 | Total jobs | count of service records in period | — | always |
| 2 | Total service items | count of `service_record_items` on those records | — | always |
| 3 | Total cost | Σ `total_cost` | avg job cost (total ÷ jobs) | always (sub needs jobs > 0) |
| 4 | Top service type | item name with max Σ `line_cost` | its summed cost | needs a type with cost > 0, else `—` (ties → most recent) |
| 5 | Most expensive job | max `total_cost` | its date (+ first item name as caption if present) | always (ties → most recent) |

### Charts (2)

1. **Monthly cost** — bar; Σ `total_cost` per month in period
2. **Cost by service type** — donut; Σ `line_cost` grouped by item name; > 5 types → top 4 + `Other`; total cost 0 → chart-area placeholder

## Expense Stats

### KPI cards

| # | KPI | Value | Sub-value | Gate |
|---|-----|-------|-----------|------|
| 1 | Total expenses | count in period | — | always |
| 2 | Total cost | Σ amount | avg per expense (total ÷ count) | always (sub needs count > 0) |
| 3 | Top category | category with max Σ amount | its summed amount | needs amount > 0, else `—` (ties → most recent) |
| 4 | Most expensive expense | max amount | its date (+ category) | always (ties → most recent) |

### Charts (2)

1. **Monthly cost** — bar; Σ amount per month in period
2. **Cost by category** — donut; Σ amount grouped by `expenses.category`, zero-amount categories omitted; > 5 slices → top 4 + `Other`; total 0 → chart-area placeholder

## Definitions modal (one per screen)

Opens from **What do these stats mean?**. Plain-language definition of every KPI on that screen, plus:

- What a *segment* is and why distance KPIs need ≥ 2 of them (shown as `—` otherwise)
- That consumption is computed between odometer readings and is approximate when a tank is not filled to full
- Unit rules in effect (from Settings)
- Month label rule (`MMM` for a selected year, `MMM YY` for All)

## Odometer field on the fuel log form (the contract change)

- Field: **Odometer**, optional, on add **and** edit of refuel/charge logs
- Input unit: the active vehicle's `mileage_unit` (same unit as the vehicle's mileage and service odometer)
- When provided: must be ≥ the vehicle's current mileage; if greater than the stored vehicle mileage, **bump `vehicles.mileage`** — identical to the existing service-odometer rule
- Existing logs keep `null`; no backfill, no migration rewrite
- Syncs through the existing fuel-log outbox / push / change-log path (nullable column; no new entity)
- The fuel list row does **not** display the odometer in this slice (form only)

---

# Business Rules

- Stats are read-only, free-plan, active-vehicle only; archived vehicles are unreachable (they cannot be active)
- Currency follows Settings (USD / MMK) with existing formatting helpers; derived KPIs use 2 decimals
- Distance display follows the Settings length unit, converting from the vehicle's `mileage_unit` when they differ
- Consumption format from Settings: length `km` → `l/100 km` (refuel) / `km/kWh` (charge); length `mi` → `mpg` (refuel, using the log's gal unit) / `mi/kWh` (charge). No in-screen unit toggle
- Volume totals group by the log's snapshotted unit; mixed units in one period → per-unit lines (volume) or `—` (consumption)
- **Segment math** (fuel): order the vehicle's fuel logs by `logged_on` (ties → `created_at`, then id). A *reading* is a log with `odometer` present. A *segment* is two **consecutive readings** where both fall inside the filtered period, later ≥ earlier, and delta ≤ outlier bound (10,000 when the vehicle's unit is km, 6,000 when mi). Invalid pairs are skipped individually; they do not break neighboring pairs
- Distance-derived KPIs render `—` unless the period has ≥ 2 valid segments; cost/count/volume KPIs always render
- A segment's amount and cost are the **later** reading's values (fuel added since the previous reading) — the accepted approximation for partial fills; the definitions modal says so
- Month buckets for charts use the later reading's month (fuel) or the record's date (maintenance / expense)
- Dashboard "total spent" remains expenses-only; stats never write back to Dashboard KPIs
- Odometer never decreases: monotonic via the existing vehicle-mileage rules (higher value wins on sync; `409` / validation error on lower writes)

---

# User Flow

Hamburger menu → **Stats** section

↓

**Fuel Stats** / **Maintenance Stats** / **Expense Stats**

↓

KPI cards + charts render for active vehicle, All / All

↓

Change Year or Month → local recompute (sub-200 ms)

↓

Tap **What do these stats mean?** → definitions modal → close

---

# Validation Rules

Only the new input in this feature is the odometer:

Odometer

- Optional (blank = no reading; KPIs degrade per gating rules)
- Numeric, ≥ 0
- When present: ≥ active vehicle's current mileage (validation error otherwise, same copy pattern as the service form)
- Unit fixed to the vehicle's `mileage_unit`
- Max 999,999 (generous ceiling; vehicle mileage rules still apply)

Filters

- Year and Month only accept options from their data-driven lists

---

# Error States

- **No active vehicle** — standard empty state (consistent with other drawer screens)
- **No records for the vehicle at all** — empty state with CTA into the matching log form (Add refuel/charge, Register service, Add expense)
- **Records exist, none in the filtered period** — "No records in this period" + **Clear filters** action
- **Sparse odometer data** — distance/consumption/cost cards show `—`; counts/totals still render; modal explains why
- **Mixed volume units in period** — consumption shows `—` (volume shows per-unit lines)
- **Local DB still hydrating** — skeleton placeholders, then render (no spinner deadlock)
- **Sync conflict on a fuel log** — existing `sync.md` behavior; stats recompute after resolution

---

# Non-Functional Requirements

- Offline-first: all aggregation local; no network dependency for any KPI
- No new API endpoints; `odometer` is the only wire change (`FuelLog` schemas)
- Filter change → recompute < 200 ms; screen load < 1 s for ≥ 1,000 logs in period
- Charts accessible: each chart exposes a semantic label with period + summary value; cards are readable by screen readers
- Unit tests for: segment pairing/gating, consumption and cost-per-100 math, month bucketing, mixed-unit handling, donut > 5 grouping, month label rules, unit/currency formatting
- Chart data bounded to the filtered period before render (no full-table scans in the UI layer)

---

# Analytics

Events (add to `mobile/lib/core/analytics/analytics.dart`)

- `stats_opened` — property: `screen` (`fuel` \| `maintenance` \| `expense`)
- `stats_period_changed` — properties: `screen`, `year`, `month`
- `stats_definitions_opened` — property: `screen`

---

# Success Metrics

- Share of users with ≥ 1 log who open any stats screen within 7 days of their first log
- Repeat usage: stats opens per active user per month
- Odometer adoption: share of new fuel logs submitted with an odometer value (leading indicator for distance-KPI quality)
- Definition-modal open rate (proxy for KPI comprehension)

---

# Dependencies

- Garage (active vehicle, `fuel_type`, `mileage`, `mileage_unit`)
- Fuel module (`fuel_logs` + form; odometer field lands there)
- Maintenance module (`service_records`, `service_record_items`)
- Expenses module (`expenses`)
- Local Database (Drift) — aggregation source
- Settings (currency, length unit, volume unit)
- Sync Engine (odometer field through existing outbox/change log)
- Analytics (new enum entries)
- fl_chart (new pubspec dependency)

**Contract documents amended with this FRD:** `product/frd/fuel.md`, `architecture/data-model.md`, `architecture/openapi.yaml`, `product/production-scope.md`, `product/frd/README.md`, `docs/app-shell.md`, `docs/glossary.md`.

---

# Future Enhancements

- Table view (Charts/Table toggle with month × metric rows)
- Compare By: fuel type, service type, expense category
- Insights screen: cross-section cost per 100 km (fuel + maintenance + expenses)
- Charge form extension (charging source, AC/DC, duration, battery %) → Home vs Away, AC vs DC, charge-speed KPIs
- Cost-per-unit trend chart; monthly volume / distance charts
- Server aggregation for web / family dashboard read-only stats
- Odometer backfill helper (prompt to set odometer from vehicle mileage on next log)
- PDF / CSV export of a period
- Per-card info tooltips instead of / alongside the modal
