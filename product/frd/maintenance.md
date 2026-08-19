# Maintenance Module

## Overview

Maintenance is how the owner keeps the active vehicle on schedule and keeps a history of work done. It has two records: a **plan** (what should happen next) and a **service record** (what already happened). Reminders fire from the plan using time and/or distance. Receipt photos can be attached; they are not OCR'd in MVP.

Suggested plan items depend on the vehicle's fuel type (petrol / electric / hybrid plugin), as defined with the Garage vehicle profile.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable users to:

- See upcoming, scheduled, and completed work for the active vehicle
- Add custom and suggested plan items
- Log a service visit with line items and total cost
- Attach a receipt image without auto-fill
- Get a local reminder when an item is due
- Keep chronological service history

---

# In Scope

- Maintenance plan list
- Add custom plan item
- Add suggested plan item (filtered by fuel type)
- Register service (service record)
- Service items and total cost
- Attach receipt (camera or photo picker)
- Upcoming / Scheduled / Service History tabs and empty states
- Time and/or distance reminders
- Local reminder notification: mark done or dismiss
- Service history chronological list

---

# Out of Scope

- Receipt OCR / auto-fill from the image
- Fuel tracking and efficiency
- Insurance policy renewals as plan items (store insurance files in Documents)
- Workshop booking
- Verified / dealer-uploaded service history
- Predictive or AI maintenance
- Push marketing about services

---

# User Personas

- Everyday Owner
- Car Enthusiast
- Family Manager (own vehicles only)

---

# User Stories

### US-MNT-001

As a user,

I want a maintenance plan for my active vehicle

So that I know what is due next.

---

### US-MNT-002

As a user,

I want to add a suggested item for my fuel type

So that I do not invent intervals from memory.

---

### US-MNT-003

As a user,

I want to log a service with items and cost

So that I have a history that helps resale and planning.

---

### US-MNT-004

As a user,

I want to attach a photo of the receipt

So that the paper is not the only copy.

---

### US-MNT-005

As a user,

I want a reminder when a plan item is due by date or mileage

So that I do not miss service.

---

# Functional Requirements

## Tabs

Three lists on the Maintenance surface, each with its own empty view:

- **Upcoming** — plan items past due or due soon (by date and/or remaining distance)
- **Scheduled** — plan items with a future date or mileage target that are not yet upcoming
- **Service History** — completed service records, newest first

## Maintenance plan item

Fields

- Name (required)
- Time interval (optional if distance is set): days / months / years
- Distance interval (optional if time is set): miles or km matching the vehicle's display unit
- Notes (optional)
- Enabled / disabled

Behavior

- Next due date and/or next due mileage are computed from the last completed service of that item, or from the vehicle's current mileage and an optional tracking-start override
- Suggested catalog is filtered by the active vehicle's fuel type (see Suggested items below)
- Disable hides the item from Upcoming/Scheduled without deleting history
- Completing a reminder offers to open Register Service with the item pre-selected

## Register service

Required

- Date
- Odometer
- At least one service item
- Total cost (may be the sum of item costs)

Optional

- Workshop / location name
- Notes
- Receipt image (camera or library)

Behavior

- Service items have a name and optional line cost
- Total cost defaults to the sum of line costs and can be overridden
- If odometer is higher than the vehicle's stored mileage, update vehicle mileage
- If odometer is lower, reject (see Garage mileage rule)
- Saving a service can complete matching plan reminders
- Works offline; queues sync

## Attach receipt

- Opens camera or photo picker
- Stores the compressed image with the service record
- Does not extract date, vendor, lines, or cost

## Reminders

- A plan item with a due date and/or due mileage creates a local notification when due
- User can mark done (opens or completes toward a service record) or dismiss
- Dismiss does not delete the plan item
- See `notifications.md` for delivery

---

# Suggested items

Copied from the Garage catalog so this FRD stays implementable without opening another file.
Suggested items are templates with the same shape as a custom plan item (name, recurring, time interval and/or distance interval). Once added they are user-owned copies.

A new maintenance plan also seeds two defaults: **Mileage Update** (every 30 days) and **Routine** (every 1 year or 10,000 mi).

Engine-only items (oil, belts, fuel filter) are hidden for electric vehicles.

| Item | Recurring | Time | Distance |
|------|-----------|------|----------|
| Oil Change | yes | 1 year | 15,000 mi |
| Air Filter (Cabin) | yes | 1 year | 15,000 mi |
| New Tires | yes | 5 years | 50,000 mi |
| Brake Change | yes | — | 30,000 mi |
| Brake Fluid | yes | 3 years | 30,000 mi |
| Belts | yes | 5 years | 80,000 mi |
| Fuel Filter | yes | — | 30,000 mi |
| Wash | yes | 14 days | — |
| Battery | yes | 3 years | 36,000 mi |
| Air Conditioning | yes | 1 year | — |
| Rotate Tires | yes | 1 year | 6,000 mi |

---

# Business Rules

- All records belong to one vehicle; the working vehicle is the active vehicle
- A plan item must have a time interval, a distance interval, or both
- Mileage on a service record cannot be lower than the vehicle's current mileage
- Archiving a vehicle archives its plan and service records; they are not hard-deleted
- Suggested items are templates; once added they are user-owned copies and may be edited

---

# User Flow

Maintenance tab (active vehicle)

↓

Upcoming / Scheduled / History

↓

Add plan item (custom or suggested)

or

Register service → optional attach receipt → save

↓

Reminder due → local notification → done or dismiss

---

# Validation Rules

Date

- Required
- Not in the far future beyond current year + 1 for a completed service (plan due dates may be in the future)

Odometer

- Required on service records
- Non-negative
- Must not decrease vehicle mileage

Total cost

- Required
- >= 0
- Currency is the user's locale default; no multi-currency in MVP

Plan item name

- Required
- Maximum 80 characters

---

# Error States

- No active vehicle
- Plan item missing both time and distance interval
- Odometer decrease rejected
- Receipt capture cancelled or camera permission denied (save record without image)
- Offline save queued (not an error)
- Sync conflict on the same record (see `sync.md`)
- Empty tab (dedicated empty view, not a generic error)

---

# Non-Functional Requirements

- Offline-first writes
- Automatic sync
- < 2-second load for the three tabs on a mid-range device
- Accessible lists, forms, and empty states
- Images compressed before upload
- Domain tests for due-date / due-mileage calculation and mileage monotonicity

---

# Analytics

Events

maintenance_record_added

maintenance_plan_item_added

maintenance_reminder_completed

maintenance_reminder_dismissed

---

# Success Metrics

- Maintenance records per vehicle
- Plan items per vehicle
- Reminder completion rate
- Share of records with a receipt attached

---

# Dependencies

- Authentication
- Garage (active vehicle, fuel type, mileage)
- Local Database
- Sync Engine
- Notifications
- Media Storage

---

# Future Enhancements

- Receipt OCR and line-item extraction
- Workshop booking from a due item
- Verified service history / digital passport
- Manufacturer schedule import
- Predictive due dates
