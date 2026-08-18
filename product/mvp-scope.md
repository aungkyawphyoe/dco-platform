# MVP Scope

**Product:** Digital Car Ownership Platform (DCO)

**Version:** 1.0

**Status:** Draft

**Last Updated:** August 2026

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
| Default Selected Car and Toggle | Show the default selected informations and user can switch another car which will lead to Garage Home(My Garage) Screen |
| Vehicle Detail | Show the vehicle overall information |
| Ownership Summary | Show total spent money, total used fuel, services count |
| Recent Activity | Show 3 records of maintenance history |
| Next Maintenance | Show the most due maintenance |

### Garage Home

| Feature | Description |
|---------|-------------|
| arage Home | List of the user's vehicles as cards (photo, nickname, make/model, plate, mileage, next maintenance) |
| Add Vehicle | Required: name, year, make, model, license plate, mileage, **fuel type (petrol/electric/hybrid plugin)**. Optional: VIN, color, nickname, purchase date |
| Edit Vehicle | Update vehicle details including car type |
| Archive Vehicle | Soft-delete; records are archived, never permanently removed |
| Active Vehicle | User always has one active vehicle selected; switching persists |
| Vehicle Detail | Overview section + entry points to maintenance, expenses, documents |

### Maintenance

| Feature | Description |
|---------|-------------|
| Service Records | Log date, type, odometer, cost, notes, workshop |
| Service Reminders | Scheduled by time interval and/or distance threshold |
| Reminder Notifications | Local notification when a reminder is due; mark as done or dismiss |
| Service History | Chronological list per vehicle |
| **EV-Specific Maintenance** | Separate maintenance schedules for EV vs Engine vehicles. EV: Tire rotation (5,000-7,500 mi), Brake inspection (annual), Brake fluid (3-5 years), Coolant - battery/power electronics (3-5 years), Cabin air filter (15,000-22,500 mi/2 years), 12V battery (6 months/4-6 years). Engine: Oil change, Tire rotation, Brake inspection, etc. |

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
| Categories | e.g. fuel, maintenance, insurance, parking, tolls, parts |

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

- Fuel tracking
- Insurance module (policy management)
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

---

# Business Rules That Shape the Build

These rules come from the vision and FRD documentation and must be honored by the data model:

- License plate is unique per account.
- VIN cannot belong to multiple vehicles.
- A user must always have one active vehicle selected.
- Deleting a vehicle archives its records rather than permanently removing them.
- Odometer/mileage cannot decrease (admin correction workflow may come later).
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

- **v1.1:** Fuel tracking, Insurance module, Cloud backup
- **Phase 2:** Workshop booking, Marketplace, Family sharing, Vehicle health dashboard
- **Phase 3 (Year 2):** OBD/connected cars, predictive maintenance, fleet, dealer/insurance portals