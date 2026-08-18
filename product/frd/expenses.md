# Expenses Module

## Overview

Expenses is the ownership-cost log for a vehicle. The owner records category, amount, date, notes, and an optional receipt photo. Monthly and lifetime totals feed the dashboard ownership summary.

A **fuel expense** is money spent on fuel. It is not a refuel log: no volume, no price per liter, no MPG, no charging kWh. Those belong to v1.1 Fuel tracking. An **insurance expense** is a payment; it is not a policy record.

Maintenance **service record costs** stay on the Maintenance module. They do not auto-create an expense. Dashboard "total spent" and "this month" use this Expenses module only.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable users to:

- Log what they spent on the active vehicle
- Categorize the spend
- Attach a receipt photo
- See monthly and total spend

---

# In Scope

- Expense list for the active vehicle
- Add / edit / delete expense
- Categories: fuel, maintenance, insurance, parking, tolls, parts, other
- Amount, date, notes, optional receipt photo
- Monthly summary and lifetime total per vehicle
- Empty state

---

# Out of Scope

- Fuel tracking (volume, efficiency, charging)
- Insurance policy management
- Trip-linked costs
- Multi-currency conversion
- PDF cost reports
- Auto-creating an expense from a maintenance service record
- Receipt OCR

---

# User Personas

- Everyday Owner
- Family Manager (own vehicles only)
- Car Enthusiast

---

# User Stories

### US-EXP-001

As a user,

I want to log an expense against my vehicle

So that I know what ownership costs.

---

### US-EXP-002

As a user,

I want categories including fuel and insurance

So that I can group spend without a fuel or insurance module.

---

### US-EXP-003

As a user,

I want monthly and total spend

So that the dashboard ownership summary is truthful.

---

# Functional Requirements

## List

Display for the active vehicle, newest first

- Date
- Category
- Short description or notes preview
- Amount
- Receipt indicator if a photo exists

Filters in MVP: all vs a single category. No date-range picker beyond "this month" vs "all" on the summary.

## Add / edit

Required

- Category
- Amount
- Date
- Vehicle (defaults to active vehicle; must remain that vehicle in MVP)

Optional

- Notes
- Receipt photo (camera or library)

Behavior

- Works offline
- Receipt photo is stored and compressed; no OCR
- Editing amount or date recalculates summaries on next view
- Delete requires confirmation

## Summaries

- **This month** — sum of expenses whose date falls in the current calendar month for the vehicle
- **Total** — sum of all expenses for the vehicle (not archived-away; archived vehicles are hidden with the vehicle)
- Dashboard ownership summary reads these two figures plus services count and documents count from other modules
- Optional breakdown by category on the Expenses screen (percent of total)

---

# Business Rules

- Every expense belongs to exactly one vehicle
- Currency is the device locale; store amount as a decimal with 2 fraction digits
- Category `fuel` does not require liters, gallons, or station
- Category `maintenance` is optional extra spend (parts bought separately, etc.); it is not synced from service records
- Category `insurance` is a payment log only
- Archiving a vehicle archives its expenses

---

# User Flow

Expenses tab or vehicle detail

↓

List + this month / total

↓

Add expense → category, amount, date → optional receipt → save

↓

Dashboard ownership summary updates after sync/local recalc

---

# Validation Rules

Amount

- Required
- > 0
- Maximum 999,999.99

Date

- Required
- Not after today + 1 day (timezone)

Category

- Required
- One of: fuel, maintenance, insurance, parking, tolls, parts, other

Notes

- Optional
- Maximum 500 characters

---

# Error States

- No active vehicle
- Invalid amount
- Camera permission denied (save without photo)
- Offline queued save (not a blocking error)
- Sync conflict (see `sync.md`)
- Empty list (dedicated empty view)

---

# Non-Functional Requirements

- Offline-first
- Automatic sync
- < 2-second list and summary load
- Accessible forms and summaries
- Image compression for receipt photos
- Tests for monthly vs total aggregation (timezone: device local)

---

# Analytics

Events

expense_added

expense_updated

expense_deleted

---

# Success Metrics

- Expense entries logged per vehicle
- Share of users with at least one expense in week 1
- Share of expenses with a receipt photo

---

# Dependencies

- Authentication
- Garage (active vehicle)
- Local Database
- Sync Engine
- Media Storage (receipt photos)
- Dashboard (read-only consumer of summaries)

---

# Future Enhancements

- Fuel log fields (volume, unit price, odometer, efficiency)
- Link an expense to a trip
- Auto-create expense from a service record (opt-in)
- Receipt OCR
- Export CSV / PDF reports
- User-defined categories
