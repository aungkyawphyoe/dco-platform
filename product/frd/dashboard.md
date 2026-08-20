# Dashboard Module

## Overview

Dashboard is the first authenticated screen. It is the **active vehicle's home**, not a second garage product. In the bottom nav it is labeled **Garage** (tldraw screen **3**). Switching vehicles opens **My Garage** (screen 4) and returns here with a new active vehicle.

It composes Garage, Maintenance, Expenses, and Documents. It does not own those records.

Source of truth for scope: `product/mvp-scope.md`. Visual reference: tldraw `3. Dashboard (Default Vehicle Detail)` and Autozis `https://autozis.com/app/dashboard` (shape only — Autozis fuel *efficiency*, insurance policies, trips, and assistant metrics are out of scope).

---

# Objectives

Enable users to:

- See which vehicle they are working on
- Read a truthful ownership cost snapshot
- Open Services, Documents, Insurance, Refuel/Charge, and Parts from Quick Actions
- Jump to the next due service
- Scan the last three maintenance events
- Register a vehicle when the garage is empty

---

# In Scope

- Default selected (active) vehicle
- Vehicle switcher → Garage Home
- Vehicle identity block (photo, plate, year/make/model, mileage, VIN if present)
- Ownership summary: total spent, this month spent
- Quick Actions: Services (full history), Documents, Insurance (placeholder), Refuel/Charge, Parts
- Recent activity: **3** maintenance history rows
- Next maintenance: the most due plan item + Log Service
- Empty garage dashboard
- Header notification entry (feed; delivery rules in `notifications.md`)
- Local read; updates after local writes and after sync pull

---

# Out of Scope

- Fuel *efficiency* KPIs (€/L, L/100km, charging kWh/100km). Refuel/Charge *logs* are a Quick Action, not dashboard metrics.
- Insurance expiry as a dashboard module (Autozis Needs attention / Insurance)
- Trips, AI assistant, mileage-update "events" as a product type
- Mixing refuel rows into Recent Activity
- Auto-creating expenses from service costs (summary uses **Expenses** only)
- Fifth bottom-nav item

---

# User Personas

- Everyday Owner
- Family Manager (own vehicles only)
- Car Enthusiast

---

# User Stories

### US-DSH-001

As a returning owner,

I want to land on my active car after login

So that I do not hunt for it in a list.

---

### US-DSH-002

As an owner,

I want total and this-month spend

So that I know what ownership is costing without opening every module.

---

### US-DSH-003

As an owner,

I want the next due item and three recent services

So that I know what to do next and what was done last.

---

### US-DSH-004

As a new owner with no car,

I want a clear Register a Vehicle action

So that Dashboard is still usable as the home tab.

---

# Functional Requirements

## Header

- Vehicle chip shows nickname (fallback: name). Tap → My Garage (screen 4).
- Garage affordance (wireframe label `garage`) → same destination.
- `Noti` → in-app notification feed.
- Compact sync indicator may sit here or on Settings; it must not replace the chip.

## Vehicle identity (populated)

From the active vehicle:

- Photo or placeholder
- License plate
- Year make model
- Mileage with unit
- VIN if stored (hide the row if empty)

Tap on the identity block may open edit vehicle (screen 5) in MVP; if not implemented on first slice, keep tap = no-op except photo remaining decorative.

## Ownership summary

Two figures, active vehicle only:

| Metric | Source | Autozis analogue (do not copy extra) |
|--------|--------|--------------------------------------|
| Total spent | Sum of **expenses** for the vehicle | Autozis splits Refuel / Maintenance / Expense costs |
| This month | Expenses with `incurred_on` in the current local calendar month | Autozis "current year running costs" |

No fuel volume, no MPG, no insurance premium field.

## Quick Actions

3-column bento under Ownership Summary. Current tiles:

| Tile | Destination |
|------|-------------|
| Services | Service History — full service list for the active vehicle |
| Documents | Document vault (UI only until the documents slice) |
| Insurance | Insurance screen (placeholder; policy module is later) |
| Refuel / Charge | Fuel logs for the active vehicle. Label is **Charge** when the vehicle fuel type is electric; otherwise **Refuel**. Placed before Parts. |
| Parts | Parts catalog for the active vehicle |

Tiles are shortcuts, not KPI counts.

## Recent activity

- Exactly **3** rows from service history, newest first.
- Each row: date, service name (first line item or record title), cost.
- Tap a row → that service in Maintenance.
- Fewer than 3: show what exists. Zero: dedicated empty line ("No services yet"), not a generic error.

Do **not** show Autozis-style REFUEL timeline rows.

## Next maintenance

- The single most due plan item (overdue first, else soonest by date or remaining distance).
- Show name + due copy (e.g. `Due in 1,200 mi (Aug 20)` or `Overdue by 500 mi`).
- Primary action **Log Service** → Register Service with the item pre-selected when possible.
- If no plan items: empty copy + action to add a plan item (Maintenance).

## Empty dashboard (tldraw `3. Dashboard (Empty View)`)

- Title/CTA **Register A Vehicle**.
- Optional shimmer while the local DB is first read (wireframe: "shimmer loading").
- Bottom nav still present. Other tabs use their own empty states.

## Active vehicle

- Always one selected vehicle once any non-archived vehicle exists.
- Switching on screen 4 persists and rebuilds Dashboard from local rows for that id.
- Archived vehicles never appear as active.

---

# Business Rules

- Dashboard is a **read model**. It does not create expenses from services.
- Total / this month ignore archived vehicles (the active vehicle is never archived).
- Mileage displayed is `vehicles.mileage` after monotonic updates from services.
- Currency is the device locale.
- Fuel type is not a dashboard KPI; it only affects suggested plan items elsewhere.

---

# User Flow

Login / Garage tab

↓

Active vehicle? 

No → Empty dashboard → Register A Vehicle → Add Vehicle → Dashboard populated

Yes → Identity + Ownership Summary + Quick Actions + Recent Activity + Next Maintenance

↓

Chip / garage → My Garage → select vehicle → Dashboard

or

Log Service → Register Service → back to Dashboard (numbers refresh from local DB)

or

Noti → feed

---

# Validation Rules

None on this screen (no form). Child screens validate. Dashboard must tolerate missing photo, missing VIN, and zero expenses (show `$0` / `0`, not a crash).

---

# Error States

- No active vehicle — empty dashboard (not an error)
- Local DB not ready — shimmer, then content or empty
- Sync failed — banner/indicator; stale local numbers still show
- Image missing — placeholder, not a broken layout
- Overdue next item — danger/warning color from the design system, **not** brand gold

---

# Non-Functional Requirements

- First paint from local DB < 2 seconds on a mid-range device
- Offline: full Dashboard from last local state
- Accessible headings: vehicle name, Ownership Summary, Quick Actions, Recent Activity, Next Maintenance
- Tokens from `docs/design-system.md` only

---

# Analytics

Events

dashboard_opened

dashboard_vehicle_chip_tapped

dashboard_log_service_tapped

(Reuse `vehicle_switched`, `vehicle_added` from Garage.)

---

# Success Metrics

- Share of sessions that land on Dashboard and do not immediately bounce to Settings
- Tap-through from Next Maintenance to Register Service
- Empty-state conversion: first vehicle added

---

# Dependencies

- Auth (session)
- Garage (active vehicle, identity, mileage)
- Expenses (totals)
- Maintenance (counts, three rows, next plan item)
- Documents (count)
- Notifications (feed entry)
- Sync (pull refreshes figures)

---

# Future Enhancements

- Autozis-like "Needs attention" strip once Insurance / Documents expiry exist
- Fuel KPIs when Fuel tracking ships (v1.1)
- Year-to-date vs month toggle
- Activity mix (expenses + services) behind a filter
