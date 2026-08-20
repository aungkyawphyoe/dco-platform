# Fuel Module

## Overview

Fuel is per-vehicle **refuel** and **charge** logging, plus an account **Fuel Types** catalog. Petrol and hybrid plugin vehicles use the Refuel form. Electric vehicles use the Charge form. This is not a fuel *expense* (money-only category) and it is not an efficiency / MPG module.

Source of truth for scope: `product/mvp-scope.md`. Shape reference: Autozis `https://autozis.com/app/refuel` and Catalog → Fuel Types. Do not copy Autozis extras (odometer on the log, partial/full tank, cost-per-unit, OCR, bulk edit, L/100km or kWh/100km KPIs).

---

# Objectives

- Let the owner log date, fuel type, amount, and cost
- Show those logs for the active vehicle with filters
- Keep reusable fuel type names in a catalog

---

# In Scope

- Quick Action **Refuel** (petrol / hybrid plugin) or **Charge** (electric), placed before Parts
- List of logs for the active vehicle, newest first
- Filters: fuel type, all dates / this month
- Refuel form (liquid types, amount in L or gal)
- Charge form (electric types, amount in kWh)
- Fuel Types catalog: add / edit name, kind (liquid / electric), unit
- Default catalog when empty: Petrol, Diesel, Electricity

# Out of Scope

- Efficiency / MPG / kWh per distance
- Odometer on the log, full vs partial tank, cost per litre/kWh
- Receipt OCR
- Auto-creating an expense from a fuel log
- Mixing fuel logs into Dashboard Recent Activity
- Deleting types or logs in this slice

---

# User Stories

### US-FUL-001

As a car owner, I want to track my fuel use and cost.

### US-FUL-002

As a car owner, I want to see the added list with filters.

### US-FUL-003

As a car owner, I want predefined fuel types I can reuse on logs.

---

# Functional Requirements

## Vehicle split

| Vehicle `fuel_type` | Form | Catalog kinds | Amount unit |
|---------------------|------|---------------|-------------|
| `petrol`, `hybrid_plugin` | Refuel | Liquid | L or gal (from the selected type) |
| `electric` | Charge | Electric | kWh |

## List

- Active vehicle only
- Title matches the form (Refuel or Charge)
- Row: date, fuel type name, amount + unit, cost
- Tap → edit
- Empty: add CTA
- Filters do not hide the add action
- App bar opens Fuel Types

## Add / edit log

Required: date (not in the future), fuel type (from matching catalog kinds), amount (> 0), cost (≥ 0).  
Type name and unit are snapshotted on the log so later catalog edits do not rewrite history.

## Fuel Types

- Account catalog (shared across the owner's vehicles)
- Unique name per account, case-insensitive
- Kind: Liquid (Refuel) or Electric (Charge)
- Unit: Liquid `L` or `gal`; Electric `kWh`

---

# Business Rules

- Hybrid plugin is treated as an engine car (Refuel only)
- A log's catalog type must match the form kind
- Dashboard totals still read **expenses only**, not fuel log costs
- Expense category `fuel` remains money-only and is not this module

---

# Validation Rules

- Fuel type name required, max 40
- Amount > 0, max 100000
- Cost ≥ 0
- Date required, not in the future

---

# Analytics

`fuel_type_added`, `fuel_type_updated`, `fuel_log_added`, `fuel_log_updated`

---

# Dependencies

Garage (active vehicle and vehicle fuel type)
