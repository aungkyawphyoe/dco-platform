# Notifications Module

## Overview

Notifications tell the owner that a maintenance plan item is due. MVP delivery is **local** on the device (scheduled from the plan). An optional **server-side email reminder** for the same plan items is available when the account has a verified email. The backend also keeps an in-app notification feed and a delivery queue so the product is push-ready. There are no marketing campaigns, no broadcast pushes, and no insurance-renewal product notifications.

Source of truth for scope: `product/production-scope.md`.

**As built (28 Aug 2026): Done (local).** OS local reminders via `flutter_local_notifications`. No remote FCM/APNs. Extended 28 Sep 2026: two reminder phases (upcoming + due) with localized banner copy, and user-configurable soon thresholds (Settings → Reminders) shared with the in-app Upcoming grouping. Extended Oct 2026: opt-in, server-side email reminders for the same plan items (Settings → Reminders → Email reminders), with per-account lead time and delivery logging. Status index: `product/frd/README.md`.

---

# Objectives

Enable users to:

- Be alerted when a plan item is upcoming, or due by date and/or mileage
- Mark the reminder done or dismiss it
- See recent alerts in an in-app feed
- Receive an optional email reminder when the device did not deliver one

Enable the platform to:

- Store notification records
- Ship with push infrastructure unused by campaigns
- Record email reminder deliveries per plan-item cycle for auditing and dedupe

---

# In Scope

- Local scheduled notifications for upcoming and due plan items
- Notification permission request (OS)
- Mark done / dismiss from the notification or in-app
- In-app notification feed (list)
- Backend notification records and delivery queue
- Push-ready wiring (device token registration) without sending campaign pushes
- Optional server-side email reminders for maintenance plan items (opt-in, verified email required)

---

# Out of Scope

- Push campaigns / marketing automation
- Insurance policy expiry product (v1.1)
- Document expiry extracted from files
- SMS reminders
- Email reminders outside maintenance plan items (insurance expiry, document expiry, workshop booking) and marketing email
- Workshop booking alerts
- Reminder fan-out to users who hold a share on the vehicle
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

- Two reminder phases per due cycle: **upcoming** and **due**.
- **Upcoming** — when a plan item's next due date is known, schedule a local notification at local 09:00, `soonDays` before the due date (default 30; or show it immediately if already inside that window).
- **Due (date)** — schedule a second local notification at local 09:00 on the due date itself (or show it immediately when overdue).
- **Due (mileage)** — evaluate on app start and after mileage updates; if remaining distance is at or below `soonDistance` (default 500 km), fire once. The threshold is stored in km regardless of the owner's display unit.
- When both date and mileage exist, the due reminder fires on whichever condition hits first.
- Each phase fires at most once per due cycle; when the due reminder fires inside the upcoming window, the upcoming banner for that cycle is suppressed (no double banner).
- Banner copy is localized (en/my): phase-specific title, body carries the plan item name plus its due date and/or due mileage (e.g. `Oil Change — due Mar 15, 2026`, `Oil Change — due at 120,000 km`).
- Reschedule when the plan item, vehicle mileage, last service, owner length unit, locale, or the reminder thresholds change
- Cancel local notifications for disabled or archived items

## Configurable thresholds (Settings → Reminders)

- Two sliders, one profile row summarizing both values:
  - **Days before due** (`soonDays`): 7–60 days, step 1, default **30**.
  - **Distance before due** (`soonDistance`): 100–1000 km, step 100 km, default **500 km**. Displayed in the owner's length unit (mi users see 62/124/…/621 mi on the same km grid).
- The thresholds are **shared**: they drive the OS reminder schedule (upcoming fires at due date − `soonDays`; the mileage reminder fires at remaining ≤ `soonDistance`) *and* the in-app Upcoming grouping in `DueCalculator` (see `maintenance.md`).
- Values are clamped to the supported ranges on read (`soonDays` 7–60, `soonDistance` snapped to the 100 km grid between 100 and 1000).
- Stored on the local `user_profiles` row only — local preference, no outbox, no API (same treatment as language/currency/length unit).
- Changing a value re-syncs local reminders immediately (reschedules pending OS alarms, cancels an upcoming alarm that is no longer in the window).
- **Behavior change vs MVP:** the mileage reminder used to fire at 100 km remaining; the default is now 500 km.
- Screen also offers **Reset to defaults** (30 days / 500 km).

## Email reminders (server-side)

Settings → Reminders → **Email reminders** is a separate, opt-in channel. It does not replace or suppress local OS notifications.

- **Availability** — enabling requires a verified email on the account. Until then the switch is disabled and the screen explains why ("Verify your email to turn on email reminders") with a link to verification. Accounts with no email show that email reminders are unavailable.
- **Preference** — one per account: `enabled` (default off) and `lead_days` (7–60, step 1, default 30). Stored server-side (`users.email_reminders_enabled`, `users.email_reminder_lead_days`), not in local preferences, so the same account behaves consistently across devices.
- **Scheduling** — the backend scans every `REMINDER_EMAIL_SCAN_MINUTES` (default 15; 0 disables). A scan sends at most one email per plan item per due cycle per phase:
  - **Upcoming** — once the item's due date enters the `lead_days` window (due date − `lead_days`).
  - **Due** — once the due date is reached or the vehicle mileage reaches the item's next due mileage. Mileage is compared in canonical storage units (miles), so the result is unit-independent.
  - Upcoming is suppressed when the due condition is already true; the first scan after the window opens sends upcoming, and the due email follows in a later scan.
- **Recipients** — the vehicle owner's email only. Organization/fleet vehicles are excluded; owner vehicles shared with other accounts send only to the owner.
- **Cycle identity** — `next_due_on` + `next_due_mileage`. Logging a service or editing the plan item's next due values starts a new cycle and allows new emails.
- **Dedupe and retry** — every send attempt is recorded in `reminder_email_deliveries`, uniquely keyed by `(plan_item_id, cycle_key, kind)`. Failed sends retry on later scans (1 h backoff, max 3 attempts). Successful sends are never repeated for the same cycle and phase.
- **Exclusions** — archived vehicles, disabled plan items, inactive accounts, unverified emails, and plan items with neither a due date nor a due mileage are skipped.
- **Email content** — vehicle nickname (or name), plan item name, due date and/or due mileage, current mileage, phase-specific subject. Copy is English-only today because the account has no stored locale; app UI copy remains en/my.
- **Failure handling** — a mail failure is logged on the delivery row (`last_error`); it does not block other rows or other plan items.
- **Opt-out** — turning the switch off stops future scans for that account. Already-queued emails are not recalled.

## Permission

- Request notification permission on the first reminder sync when an enabled plan item has a due date or mileage, if not yet determined
- If denied, still show in-app feed and Upcoming tab; do not spam the OS prompt

## Actions

- **Done** — completes the reminder, offers Register Service (see `maintenance.md`), writes a feed item as completed
- **Dismiss** — clears the notification, leaves the plan item active, may re-fire on the next interval after a new service or after a cooldown of 7 days if still overdue
- Tapping the notification opens the Maintenance tab for the notification's vehicle (the active vehicle is switched when it differs)

## In-app feed

Display newest first

- Title (phase-specific: upcoming / due)
- Plan item name and due date / due mileage (body)
- Vehicle name / nickname
- Due reason (date, mileage, or both)
- Status: unread, done, dismissed
- Time received

Both phases write a feed row (upcoming and due dedupe independently). Mark as read on open. Empty state: "Nothing due soon."

## Backend

- Persist a notification record when a reminder becomes due (created locally and synced, or created server-side if due date is reached while online)
- Delivery queue exists for future push; MVP does not send FCM/APNs campaign or remote alerts required for the core loop
- Register device push token on login so v1.1 can enable remote delivery without a schema break
- Admin and partners do not receive owner reminders

## Copy

- No promotional text
- Localized in en/my; titles distinguish the phases: "Upcoming maintenance" / "Maintenance due"
- Body example: "Oil Change — due Mar 15, 2026" / "Oil Change — due at 120,000 km"

---

# Business Rules

- A reminder is always tied to one plan item and one vehicle, and to one phase (upcoming or due)
- Switching active vehicle does not cancel other vehicles' local schedules
- Archived vehicles: cancel their scheduled locals and hide feed items
- Each phase fires at most once per due cycle until a service is logged or the item is updated
- The soon thresholds are per-device preferences; changing them reschedules but never re-fires an already delivered phase
- Email reminders are per-account and independent from local thresholds: `lead_days` sets only the upcoming email window; due email timing follows the due date/mileage
- Changing email reminder preferences never re-sends an email already delivered for the current cycle
- Email reminders are owner-only; shared vehicle recipients are never emailed
- Feed retains 90 days in MVP then may prune locally

---

# User Flow

Plan item becomes upcoming or due

↓

Local notification + feed row

↓

User taps

↓

Maintenance tab (notification's vehicle active)

↓

Done (optional Register Service) or Dismiss

---

# Validation Rules

- Title maximum 80 characters
- Body maximum 140 characters
- Cannot schedule for a disabled plan item
- Device token, when present, is an opaque string stored per user-device
- Email `lead_days` must be an integer 7–60
- Enabling email reminders requires `email_verified = true`; otherwise the API returns 409 `email_verification_required`
- A plan item with neither `next_due_on` nor `next_due_mileage` produces no email

---

# Error States

- Permission denied (in-app only; not a crash)
- Notification plugin unavailable on the platform (feed still works)
- Offline: local schedule still works; feed rows sync later
- Duplicate fire for the same phase and due cycle (dedupe by plan item + phase + cycle id)
- Email settings unavailable (network): the Email reminders card shows a retry action; local notifications are unaffected
- Email verification required / no email on account (explained in Settings; switch disabled)
- Mail provider failure: delivery recorded with `last_error`, retried with backoff up to 3 attempts

---

# Non-Functional Requirements

- Local scheduling must work offline
- Feed is offline-first and synced
- Accessible notification content (OS + in-app)
- No PII in notification bodies beyond vehicle nickname and item name
- Tests for date-due, mileage-due, upcoming-window, and first-of-either logic
- Tests for threshold clamping/snapping and for the schedule reacting to a threshold change
- Email scans are idempotent: repeated scans, restarts, and multiple app instances never duplicate an email for the same cycle and phase
- Email settings reads/writes are owner-scoped; reminder scans are bounded and must not block request handling

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
- Backend Mailer + `REMINDER_EMAIL_SCAN_MINUTES` scheduler (`backend/src/lib/reminder-email.ts`)
- Email verification (`auth.md`)

---

# Future Enhancements

- Remote push for due items when the app is not opened
- First-class reminders entity (arbitrary remind-on date/mileage, recurrence, notes) if insurance or documents enter scope
- Localized email copy using a stored account locale
- Per-reminder delivery channel (email vs local only)
- Insurance renewal reminders (with Insurance module)
- Document expiry reminders
- Quiet hours in-app
- Pushing reminders to other accounts that share the vehicle
- Push campaigns (explicitly still a product non-goal until Phase 2)
