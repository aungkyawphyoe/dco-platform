# Maintenance Module

**Planned showroom handover — 10 November 2026:** [Plan](showroom-handover-plan.md) requires staff to review a nonempty per-vehicle maintenance plan before transfer. Copy configuration and true next-due targets into an independent buyer plan, not showroom service history or fabricated completions. Unknown baselines require explicit initial-service status; later fleet/catalog changes do not affect the buyer.

## Simplified reminders and flexible service logging — approved 4 November 2026

Status is approved for implementation. This section supersedes conflicting catalog, template, plan setup, and service logging requirements below and in `fleet-maintenance-templates.md`. Approval records the product contract. Implementation is ready for manual acceptance testing. The one-time development catalog reset and reminder-rule schema updates are applied to the local development database. The owner is handling manual testing.

### Catalog and scope

- Platform admins manage a shared names-only service catalog. Remove catalog mileage and time defaults from API schemas and admin forms.
- Show the full suggested catalog for every vehicle, without vehicle-class, lifecycle, or fuel filtering. Every item follows the same behavior, including Mileage Update.
- Seed Air Conditioning, Air Filter, Battery, Belts, Brake Fluid, Brake Pads, Car Wash, Fuel Filter, Lights, Mileage Update, New Tires, Oil Change, Oil Filter, Schedule Maintenance, Suspension/Shock Absorbers, Tires - Alignment/Balancing, Tires - Pressure, and Tire - Rotation.
- Remove reusable fleet interval templates, class assignment, and template-based plan generation. Fleet managers configure reminders per vehicle.
- Custom reminder names belong to the vehicle. Fleet admins/managers may separately add fleet-only catalog names for reuse across their fleet.
- Removing a catalog suggestion preserves existing reminders, their names, and service history. Existing reminders remain selectable during service logging.

### Reminder setup and permissions

- Offer Create Custom Service Item and Add Suggested Item. Selecting a suggestion opens a bottom sheet with its name filled in. Create and edit use the same bottom-sheet flow in mobile; Fleet Portal uses centered web dialogs. Both forms show Name, side-by-side next due date and odometer, Recurring, Note, then Active. Mobile uses flat controls with no grouping card or Next due section heading. New time repeats offer Months and Years; existing day-based schedules remain unchanged until explicitly edited. Only Save appears in the footer; close, Back, and sheet dismissal exit without saving. Suggested rows use compact padding and a Set up button.
- Require at least one explicit first due target, expressed as an odometer reading, a date, or both. Users select which suggested items to add.
- Support one-time reminders and optional repetition. A distance repeat requires a first due odometer reading. A time repeat requires a first due date.
- Store targets separately from repeat intervals. Both date and distance targets use whichever is reached first.
- Time repeats support days, calendar months, and calendar years. Clamp to the destination month's last valid day when needed.
- Mobile setup uses the global reminder settings, with no per-item warning inputs. Creating or saving an edited mobile reminder clears its overrides so later global setting changes apply. Fleet Portal preserves its existing warning thresholds without exposing warning fields in this form. Either warning can make a reminder upcoming.
- Allow at most one active reminder per catalog item per vehicle. Selecting an already active item during setup opens it for editing. Separately named custom reminders can have independent schedules.
- Personal owners manage their reminders and log services. Fleet managers manage fleet reminders. Fleet drivers can log planned, unplanned, and custom services.

### Completed-service logging

- Display the full suggested catalog, existing vehicle reminders, and custom-name entry in the registration sheet. Selecting a planned catalog item from either entry point resolves to the same reminder by catalog ID.
- Select existing custom reminders explicitly. A newly typed service name records a history-only item and does not match a reminder by text similarity.
- Support multiple completed items in one visit with one service date, odometer reading, and total cost. Update each selected matching reminder independently.
- Logging an item without a matching reminder creates service history without creating a reminder.
- Require the actual service odometer reading when any selected matching reminder repeats by distance. Date-only reminders and history-only services may be logged without mileage.
- Complete a matching one-time reminder. Recalculate a matching recurring reminder from the actual service date and odometer reading using its configured repeat intervals.
- Use the service date to determine the most recent matching service. Entering an older service must not replace a schedule established by a newer service.
- Corrections and deletions recalculate affected reminders from remaining matching history. If no matching history remains, restore the explicit setup baseline. Reopen a one-time reminder when its completing service is deleted and no remaining service completes it.
- Preserve manually edited next-due targets when older service records are corrected or deleted. A newly completed service resumes recurrence from its actual date and mileage.

### Data contract and development reset

The vehicle reminder contract must represent vehicle identity, catalog identity or a vehicle-local custom name, first due targets, current next due targets, optional distance repetition, optional time repetition with its calendar unit, per-reminder warning values, and completion state. Preserve the setup baseline and manual edits sufficiently to apply the recalculation rules above. Service visits must link their selected items to the appropriate catalog items and reminders.

Existing development maintenance catalog, template, reminder, and service-log data may be discarded and the new catalog seeded. There are no production users requiring migration of these records. Limit the reset to maintenance data and its dependent records.

### Acceptance criteria

- [ ] Admin catalog endpoints and forms contain service names without interval defaults.
- [ ] Every vehicle can access the complete seeded catalog with uniform item behavior.
- [ ] Suggested-item selection opens a prefilled bottom sheet requiring at least one manual due target.
- [ ] One-time and recurring reminders support distance, date, or both, with either target making them due.
- [ ] Repeat rules require corresponding first targets and preserve calendar units.
- [ ] Mobile reminders use global warning settings; Fleet Portal can set per-reminder overrides.
- [ ] Duplicate active catalog reminders open the existing reminder for editing.
- [ ] Fleet setup works per vehicle and permissions enforce manager setup and driver logging.
- [ ] A service visit supports multiple planned, unplanned, and custom items with a shared total cost.
- [ ] Catalog-ID matching updates planned items regardless of where they were selected.
- [ ] Recurring distance services require actual mileage and calculate from that reading.
- [ ] Older entries, corrections, deletions, one-time completion, and manual target edits follow the rules above.
- [ ] Removing catalog suggestions preserves existing reminders and history.
- [x] Development maintenance data is reset and the approved catalog seeded.

---

## Driver maintenance parity — approved 18 October 2026

Drivers use the shared completed-service form, with planned and unplanned logging. Only Fleet Admin manages plans. Planned-service corrections/deletions recalculate due dates from the remaining history and restore the admin baseline when none remains. Ordinary logging needs no approval. Report Issue is a separate workflow.

See [the approved realignment plan](mobile-personal-driver-realignment-plan.md) for the role matrix and acceptance criteria. This section supersedes earlier Driver-specific restrictions; the remaining baseline applies to Personal unless stated otherwise.

## Overview

Maintenance is how the owner keeps the active vehicle on schedule and keeps a history of work done. It has two records: a **plan** (what should happen next) and a **service record** (what already happened). Reminders fire from the plan using time and/or distance. Receipt photos can be attached; they are not OCR'd in MVP.

Suggested plan items depend on the vehicle's fuel type (petrol / electric / hybrid plugin), as defined with the Garage vehicle profile.

Source of truth for scope: `product/mvp-scope.md`.

**As built (28 Aug 2026): Done** (plan, register service, history). Status index: `product/frd/README.md`. OS local reminders are **Partial** — see `notifications.md`.

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

### US-MNT-006

As a user,

I want to view maintenance statistics and charts

So that I can understand my spending patterns and service frequency.

---

# Functional Requirements

## Navigation

The Maintenance Plan (Upcoming / Scheduled / History) is accessed via the **hamburger menu**, not directly from the Maintenance tab. The Maintenance tab focuses on quick actions and recent activity. The hamburger menu provides access to the full Maintenance Plan screen.

## Tabs

Three lists on the Maintenance surface, each with its own empty view:

- **Upcoming** — plan items past due or due soon (by date and/or remaining distance). "Due soon" uses the owner's reminder thresholds: within `soonDays` (default 30) of the due date, or remaining distance at or below `soonDistance` (default 500 km) — see Settings → Reminders and `notifications.md`.
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
- Suggested catalog is filtered by the active vehicle's fuel type and vehicle class (production: catalog rows are vehicle-class-aware with optional lifecycle narrowing — see [`fleet-maintenance-templates.md`](fleet-maintenance-templates.md))
- Suggested catalog caches are isolated by signed-in account and vehicle. Added suggestions are excluded using only that vehicle’s plan catalog keys; switching accounts or vehicles clears pending selections.
- Refresh suggestions after a successful sync so a newly created local vehicle can load its catalog after upload. Failed requests preserve that scope’s offline cache.
- Distinguish an unavailable catalog, a successfully loaded empty catalog, and a non-empty catalog whose items are all added. Each empty/error state supports retry; loading must not show “All suggested items added.”
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
- The upcoming window and the mileage "due soon" boundary come from the same thresholds as the Upcoming list (Settings → Reminders; default 30 days / 500 km)
- User can mark done (opens or completes toward a service record) or dismiss
- Dismiss does not delete the plan item
- See `notifications.md` for delivery

---

# Suggested items

Copied from the Garage catalog so this FRD stays implementable without opening another file.
Suggested items are templates with the same shape as a custom plan item (name, recurring, time interval and/or distance interval). Once added they are user-owned copies.

Production note: catalog rows are tagged with a `vehicle_class` (car/motorcycle/truck/van/bus) and an optional `lifecycle_template`; the owner's suggested list filters by the active vehicle's class and fuel type (org copies are Fleet-Portal-only — see [`fleet-maintenance-templates.md`](fleet-maintenance-templates.md)).

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
- Currency follows Settings (USD or MMK); no conversion in MVP. USD shows cents; MMK shows whole kyat with K / M for large amounts.

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

User-facing readings and reading inputs use **Odometer**. Repeat intervals use **Distance**. **Mileage** is reserved for efficiency and chart contexts; API field names stay unchanged.

Distance and odometer UI values use whole numbers with no decimal places in mobile and Fleet Portal. Keep canonical storage/conversion precision; costs, quantities, and efficiency ratios retain their existing precision.

When recurrence is enabled, each entered due target requires its matching repeat: date requires repeat time (at least 1 month for new schedules), odometer requires a positive repeat distance. A single due target does not require the other target or repeat. Show only the applicable repeat fields and place required-field errors beside missing inputs. One-time reminders need either due target and no repeats.
