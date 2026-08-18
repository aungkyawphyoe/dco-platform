# Notifications Module

## Overview

Notifications tell the owner that a maintenance plan item is due. MVP delivery is **local** on the device (scheduled from the plan). The backend also keeps an in-app notification feed and a delivery queue so the product is push-ready. There are no marketing campaigns, no broadcast pushes, and no insurance-renewal product notifications.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable users to:

- Be alerted when a plan item is due by date and/or mileage
- Mark the reminder done or dismiss it
- See recent alerts in an in-app feed

Enable the platform to:

- Store notification records
- Ship with push infrastructure unused by campaigns

---

# In Scope

- Local scheduled notifications for due plan items
- Notification permission request (OS)
- Mark done / dismiss from the notification or in-app
- In-app notification feed (list)
- Backend notification records and delivery queue
- Push-ready wiring (device token registration) without sending campaign pushes

---

# Out of Scope

- Push campaigns / marketing automation
- Insurance policy expiry product (v1.1)
- Document expiry extracted from files
- Email or SMS reminders (except auth mail in `auth.md`)
- Workshop booking alerts
- Family-shared reminder fan-out
- Quiet hours customization beyond OS settings

---

# User Personas

- Everyday Owner
- Family Manager (own vehicles only)
- Car Enthusiast

---

# User Stories

### US-NTF-001

As a user,

I want a reminder when an oil change is due

So that I do not miss it.

---

### US-NTF-002

As a user,

I want to mark that reminder done or dismiss it

So that I can act or clear it.

---

### US-NTF-003

As a user,

I want an in-app list of recent alerts

So that I can catch what I missed if I ignored the banner.

---

# Functional Requirements

## Scheduling (local)

- When a plan item's next due date is known, schedule a local notification at local 09:00 on that date (or immediately if already overdue when the item is saved)
- When a plan item is due by mileage only, evaluate on app start and after mileage updates; if remaining distance <= 0, fire once
- When both date and mileage exist, fire on whichever condition hits first
- Reschedule when the plan item, vehicle mileage, or last service changes
- Cancel local notifications for disabled or archived items

## Permission

- Request notification permission on first plan item save if not yet determined
- If denied, still show in-app feed and Upcoming tab; do not spam the OS prompt

## Actions

- **Done** — completes the reminder, offers Register Service (see `maintenance.md`), writes a feed item as completed
- **Dismiss** — clears the notification, leaves the plan item active, may re-fire on the next interval after a new service or after a cooldown of 7 days if still overdue
- Tapping the notification opens Maintenance for the active vehicle and the relevant item

## In-app feed

Display newest first

- Title (plan item name)
- Vehicle name / nickname
- Due reason (date, mileage, or both)
- Status: unread, done, dismissed
- Time received

Mark as read on open. Empty state: "Nothing due soon."

## Backend

- Persist a notification record when a reminder becomes due (created locally and synced, or created server-side if due date is reached while online)
- Delivery queue exists for future push; MVP does not send FCM/APNs campaign or remote alerts required for the core loop
- Register device push token on login so v1.1 can enable remote delivery without a schema break
- Admin and partners do not receive owner reminders

## Copy

- No promotional text
- Example: "Oil Change is due" / "Oil Change is overdue by 500 mi"

---

# Business Rules

- A reminder is always tied to one plan item and one vehicle
- Switching active vehicle does not cancel other vehicles' local schedules
- Archived vehicles: cancel their scheduled locals and hide feed items
- Mileage-based fire at most once per due cycle until a service is logged or the item is updated
- Feed retains 90 days in MVP then may prune locally

---

# User Flow

Plan item becomes due

↓

Local notification + feed row

↓

User taps

↓

Maintenance item

↓

Done (optional Register Service) or Dismiss

---

# Validation Rules

- Title maximum 80 characters
- Body maximum 140 characters
- Cannot schedule for a disabled plan item
- Device token, when present, is an opaque string stored per user-device

---

# Error States

- Permission denied (in-app only; not a crash)
- Notification plugin unavailable on the platform (feed still works)
- Offline: local schedule still works; feed rows sync later
- Duplicate fire for the same due cycle (dedupe by plan item + cycle id)

---

# Non-Functional Requirements

- Local scheduling must work offline
- Feed is offline-first and synced
- Accessible notification content (OS + in-app)
- No PII in notification bodies beyond vehicle nickname and item name
- Tests for date-due, mileage-due, and first-of-either logic

---

# Analytics

Events

notification_shown

notification_opened

maintenance_reminder_completed

maintenance_reminder_dismissed

---

# Success Metrics

- Reminder completion rate
- Notification open rate
- Permission grant rate
- Share of due items that fired exactly once per cycle

---

# Dependencies

- Authentication
- Garage (active vehicle, nickname, mileage)
- Maintenance (plan items, due calculation)
- Local Database
- Sync Engine
- OS notification APIs
- Optional: push provider (registered, unused for campaigns)

---

# Future Enhancements

- Remote push for due items when the app is not opened
- Insurance renewal reminders (with Insurance module)
- Document expiry reminders
- Quiet hours in-app
- Family sharing of reminders
- Push campaigns (explicitly still a product non-goal until Phase 2)
