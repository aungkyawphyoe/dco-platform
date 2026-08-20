# MVP Scope

**Product:** Digital Car Ownership Platform (DCO)

**Version:** 1.0

**Status:** Aligned (Phase 1 contract)

**Last Updated:** August 2026

This file is the source of truth for what ships in MVP. `docs/product-roadmap.md` and `product/frd/` must not contradict it. Fuel *efficiency* (MPG / kWh economy) and insurance *policy* management are Autozis-style modules deferred to v1.1. Insurance remains a document category and an expense category. Refuel / charge *logs* (date, type, amount, cost) are in MVP.

---

# Overview

The MVP delivers the core "digital home for your vehicle" experience. A car owner can create an account, add their vehicle to a Garage, track maintenance and service history, store important documents, and log expenses — all offline-first, synced automatically, and backed by a REST API.

The MVP spans three surfaces:

- **Mobile App (Flutter)** — the primary surface, used by car owners.
- **Backend (REST API + DB)** — serves mobile clients and the web portal.
- **Web Portal (Admin)** — user management and partner onboarding for the business side.

Freemium gating (free vs premium vehicle limits) is designed into the data model but full monetization is not activated in the MVP.

---

# MVP Goals

1. Let a user create an account and add at least one vehicle to their Garage.
2. Enable complete maintenance, document, and expense tracking for a vehicle.
3. Never lose user data — offline-first with automatic synchronization.
4. Provide the business side a minimal admin surface for user management and partner onboarding.

---

# In Scope

## Mobile App

### Foundation

| Feature | Description |
|---------|-------------|
| Authentication | Email + password signup, login, logout, email verification, password reset, session persistence |
| App Shell & Navigation | Bottom navigation, GoRouter routing, authenticated route guards |
| Offline Data Layer | Drift/SQLite local database, offline writes, queued sync |
| Sync Engine | Bidirectional sync with the backend, conflict handling, automatic retry |
| Notifications | Local reminders; push-ready infrastructure |

### Dashboard
| Feature | Description |
|---------|-------------|
| Default Selected Car and Toggle | Show the active vehicle; switching opens Garage Home (My Garage) |
| Vehicle Detail | Show the vehicle overall information |
| Ownership Summary | Total spent, this month spent. No fuel volume or MPG. |
| Quick Actions | 3-column bento: Services (full history), Documents, Insurance (placeholder), Refuel/Charge, Parts |
| Recent Activity | Show 3 records of maintenance history |
| Next Maintenance | Show the most due maintenance |

### Garage Home

| Feature | Description |
|---------|-------------|
| Garage Home | List of the user's vehicles as cards (photo, nickname, make/model, plate, mileage, next maintenance) |
| Add Vehicle | Required: name, year, make, model, license plate, mileage, **fuel type (petrol / electric / hybrid plugin)**. Optional: VIN, color, nickname, purchase date |
| Edit Vehicle | Update vehicle details including fuel type |
| Archive Vehicle | Soft-delete; records are archived, never permanently removed |
| Active Vehicle | User always has one active vehicle selected; switching persists |
| Vehicle Detail | Overview section + entry points to maintenance, expenses, documents, and Refuel/Charge from Dashboard Quick Actions. |

### Maintenance

| Feature | Description |
|---------|-------------|
| Service Records | Log date, type, odometer, cost, notes, workshop |
| Service Reminders | Scheduled by time interval and/or distance threshold |
| Reminder Notifications | Local notification when a reminder is due; mark as done or dismiss |
| Service History | Chronological list of service history |
| Empty State | Upcoming, Scheduled, and Service History each have their own empty view |
| Register Service | Add a service record with service items and total cost |
| Attach Receipt | Open camera or photo picker and store the image with the service record. No OCR or auto-fill in MVP. |
| Maintenance Plan | List of user-added maintenance items for the active vehicle |
| Add Maintenance Item | Custom user-defined plan item (name, time and/or distance interval) |
| Add Suggested Item | Predefined plan items filtered by the vehicle's fuel type |
| Assign parts | Pick catalog parts when logging a service |

### Parts

| Feature | Description |
|---------|-------------|
| Parts catalog | Per-vehicle list of parts (name, optional brand, part number, notes) |
| Add / edit part | Owner-defined parts for the active vehicle |
| Assign on service | Attach parts when registering a service |
| Assign on expense | Attach parts when logging an expense (with the expenses slice) |

### Fuel

| Feature | Description |
|---------|-------------|
| Refuel / Charge logs | Date, fuel type, amount, cost for the active vehicle |
| Vehicle split | Petrol and hybrid plugin → Refuel. Electric → Charge |
| Fuel Types catalog | Owner-defined types (liquid vs electric, unit) on a Fuel Types screen |
| Filters | List filters by fuel type and this month / all dates |

### Documents

| Feature | Description |
|---------|-------------|
| Document Vault | Secure per-vehicle list of stored documents |
| Upload | Photo/PDF upload with image compression |
| Categories | e.g. insurance, registration, invoice, warranty, receipt |
| View | Open and view stored documents |

### Expenses

| Feature | Description |
|---------|-------------|
| Expense Log | Add expense entries (category, amount, date, vehicle, notes, receipt photo) |
| Summaries | Monthly and total spend per vehicle |
| Categories | e.g. fuel, maintenance, insurance, parking, tolls, parts. A fuel *expense* is not a fuel-tracking log. |

## Backend

| Service | Description |
|---------|-------------|
| Auth | JWT issuance/refresh, email/password, email verification, password reset |
| Users | Profile CRUD, account status |
| Vehicles | CRUD with plate-uniqueness and VIN-uniqueness rules, archive support, active-vehicle state |
| Maintenance | Service records CRUD, reminder definitions and scheduling |
| Documents | Upload metadata, media storage (compressed images, PDFs) |
| Expenses | Expense CRUD, per-vehicle aggregation |
| Notifications | Notification delivery queue, in-app notification feed |
| Sync | Change-log API for offline-first bidirectional sync |
| Partners | Workshop and insurer account records with onboarding status |

## Web Portal (Admin)

| Feature | Description |
|---------|-------------|
| Admin Login | Email + password, admin-only role |
| Dashboard | Overview of users, vehicles, and recent activity |
| User Management | List, search, view profile, deactivate/reactivate, support actions |
| Partner Onboarding | Create and manage workshop and insurer accounts (name, contact, status, verification) |

---

# Out of Scope (MVP)

The following are explicitly deferred:

- Fuel efficiency (MPG, L/100km, kWh/100km). Refuel/charge *logs* are in MVP; economy KPIs are not.
- Insurance module (policy management, renewals, previous policies). Insurance remains a document category and an expense category.
- Receipt OCR / auto-fill from a captured image
- Cloud backup beyond the core sync engine
- Family sharing / multi-driver access
- Marketplace (parts, accessories, services)
- Workshop booking
- Dealer and insurance portals
- Vehicle financing
- Connected car / OBD-II / telematics
- Predictive or AI maintenance
- Fleet management
- Push campaigns / marketing automation
- Digital Vehicle Passport / verified service history
- Trips / mileage logbook, vehicle sharing, import/export, PDF reports (Autozis features not in this slice)

---

# Business Rules That Shape the Build

These rules come from the vision and FRD documentation and must be honored by the data model:

- License plate is unique per account.
- VIN cannot belong to multiple vehicles.
- A user must always have one active vehicle selected.
- Deleting a vehicle archives its records rather than permanently removing them.
- Mileage is required when adding a vehicle.
- Odometer/mileage cannot decrease (admin correction workflow may come later).
- Fuel type is required and must be one of: petrol, electric, hybrid plugin.
- Vehicle year is between 1900 and current year + 1.
- VIN is exactly 17 characters when supplied.
- License plate max length is 20 characters.
- Free users are limited to one vehicle; premium users may manage unlimited vehicles. (Monetization not activated in MVP, but the plan field must exist.)

---

# Product Principles

The MVP must follow these principles (from `docs/product-principles.md`):

1. Solve a real ownership problem.
2. Reduce user effort.
3. Work offline whenever possible.
4. Build trust through transparency.
5. Protect user privacy.
6. Be accessible to all users.
7. Prefer automation over manual work.
8. Design for long-term ownership (archiving, not deleting).
9. Keep workflows consistent.
10. Optimize for reliability before novelty.

---

# Non-Functional Requirements

- **Offline-first:** All core write operations must work without a connection and sync later.
- **Load time:** < 2 seconds for core screens on a mid-range device.
- **Security:** JWT auth, encrypted tokens, secure local storage, minimal data exposure on APIs.
- **Data integrity:** Server-side validation on all business rules; mileage monotonicity enforced.
- **Image handling:** Uploads compressed before upload; large images supported.
- **Accessibility:** Accessible UI per platform conventions.
- **Testability:** Clean Architecture, dependency injection, automated tests for domain rules.

---

# Analytics Events (MVP)

Minimal instrumentation on the critical path:

- `auth_signed_up`, `auth_signed_in`
- `garage_opened`, `vehicle_added`, `vehicle_deleted`, `vehicle_switched`, `vehicle_updated`
- `maintenance_record_added`, `maintenance_reminder_completed`
- `document_uploaded`
- `expense_added`
- `sync_completed`, `sync_failed`

---

# Success Metrics

## User

- Accounts created / activated
- Vehicles added per user
- Active garages (DAU/MAU)
- Reminder completion rate
- Retention (week-1, week-4)

## Product

- Maintenance records per vehicle
- Documents uploaded
- Expense entries logged

## Business (signals for later monetization)

- Multiple-vehicle adoption (premium trigger)
- Partner accounts onboarded

---

# Dependencies

- Backend live API with versioned endpoints
- Email provider for verification/reset emails
- Media storage for document uploads
- (Optional) Local notification scheduling on mobile

---

# Future Roadmap (Post-MVP)

Refer to `docs/product-roadmap.md` for the full phased plan. Immediately after MVP:

- **v1.1:** Fuel efficiency KPIs, Insurance module, Cloud backup, receipt OCR
- **Phase 2:** Workshop booking, Marketplace, Family sharing, Vehicle health dashboard
- **Phase 3 (Year 2):** OBD/connected cars, predictive maintenance, fleet, dealer/insurance portals