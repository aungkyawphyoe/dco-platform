# Feature Requirement Documents (FRDs)

This directory contains the functional specifications for every feature of the Digital Car Ownership Platform.

Each FRD is self-contained and serves as the primary source of truth for:

- Product Managers
- Designers
- Engineers
- QA Engineers
- AI Development Agents

Scope contract: `product/mvp-scope.md`. If an FRD disagrees with that file, the MVP scope wins and the FRD must be updated.

**As-built** (what the code does today) lives in [`docs/mvp-as-built.md`](../../docs/mvp-as-built.md). The status column below is that snapshot against each FRD. Do not re-implement a **Done** module. Do not treat Autozis sidebar items as backlog.

**As of:** 17 September 2026.

---

## Status legend

| Status | Meaning |
|--------|---------|
| **Done** | Contract behavior is implemented on the required surfaces. Minor follow-ups may still be listed. |
| **Partial** | Core path works; named MVP items in this FRD are still missing. |
| **Placeholder** | Route or API exists; the owner flow is not built. |
| **Deferred** | Out of this MVP on purpose (usually v1.1+). Not a bug. |

---

## Index (MVP)

| Module | File | Surface | As built | Notes |
|--------|------|---------|----------|-------|
| Dashboard | [dashboard.md](dashboard.md) | Mobile (default after login) | **Done** | Spend is expenses-only. Insurance quick action is a placeholder. Documents quick action opens an empty screen. |
| Garage | [garage.md](garage.md) | Mobile + API | **Done** | Un-archive is not in the UI. Freemium one-vehicle cap is not enforced. |
| Auth | [auth.md](auth.md) | Mobile + API | **Done** | Email/password. Debug builds mock the API. No Google/Apple (out of scope). |
| Maintenance | [maintenance.md](maintenance.md) | Mobile + API | **Done** | Plan, suggested catalog, register service, history. OS local reminders are owned by [notifications.md](notifications.md). |
| Documents | [documents.md](documents.md) | Mobile + API | **Done** | Full vault: Drift table, CRUD, upload/viewer, sync outbox. |
| Expenses | [expenses.md](expenses.md) | Mobile + API | **Done** | Categories, summaries, receipt photo, assign parts. |
| Sync | [sync.md](sync.md) | Mobile + API | **Done** (core) | Outbox → push → media → pull. Documents sync outbox wired. Settings still shows a hardcoded idle line. |
| Notifications | [notifications.md](notifications.md) | Mobile + API | **Done** (local) | OS local reminders (`flutter_local_notifications`) at 7 days / 100 km / 60 mi. In-app feed. No remote FCM/APNs. Device-token register exists on the API. |
| Parts | [parts.md](parts.md) | Mobile + API | **Done** | Per-vehicle catalog; assign on service and expense. |
| Fuel | [fuel.md](fuel.md) | Mobile + API | **Done** | Logs + Fuel Types. `petrol` / `hybrid_plugin` → Refuel only; `electric` → Charge. No economy KPIs (deferred). |
| Admin | [admin.md](admin.md) | Web portal + API | **Done** | Login BFF, users, partners. `sync_errors_24h` is always `0`. No web test suite. |
| Family Sharing | [family-sharing.md](family-sharing.md) | Mobile + API + Web | **Partial** | Family flows and backend Premium checks are implemented. Mobile navigation gating remains; billing is out of scope. |
| User Profile & Account Management | [user-profile.md](user-profile.md) | Mobile + API + Web Admin | **Planned** | Post-signup profile completion (photo, name, phone, address), user-initiated account deletion, admin user creation with temp passwords, admin user deletion. |
| Fleet Management | [fleet-management.md](fleet-management.md) | Mobile + Fleet Dashboard + Web Admin + API | **Partial** | Backend implemented: org provisioning/activation, roles, inventory + CSV, driver assignments, work orders, inspections, analytics, warranty templates, transfer, approved workshops, workshop accounts (`dco-workshop`), workshop warranty service. Fleet Dashboard implemented as separate Next.js app in `fleet-portal/` (`dco-fleet` BFF session). Surfaces still missing: Workshop Portal, mobile Fleet mode. Web Admin (`admin.yourdomain.com`) handles user management, org provisioning, partner records, and read-only fleet support. |

There is **no Settings FRD**. Localization (English/Myanmar preference, UI still English) and units (USD/MMK, mi/km) live in the owner app Settings tab. See [`docs/mvp-as-built.md`](../../docs/mvp-as-built.md) §4.10.

Dashboard consumes Garage, Maintenance, Expenses, and Documents. Navigation: `docs/app-shell.md`. API: `architecture/openapi.yaml`.

---

## Next implementation

MVP core functionality is shipped. Current follow-ups include User Profile & Account Management and Family entitlement-driven mobile navigation. Fleet backend (organizations, inventory, warranty, transfer, approved workshops, workshop accounts) and the Fleet Portal (`fleet-portal/`) are implemented; Workshop Portal and mobile Fleet mode remain planned surfaces.

**Next:** User Profile & Account Management (`user-profile.md`) — Post-signup profile completion, account deletion, admin user creation.

**Phase 3 (Year 2):** Fleet Management (`fleet-management.md`) — Organizations, vehicle inventory, warranty, ownership transfer, workshops.

Do not pull Autozis modules (trips, insurance policies, OCR, assistant, PDF, fuel *efficiency*) into these FRDs.

---

## Purpose

Each FRD defines:

- Business objective
- User problems
- User stories
- Functional requirements
- Business rules
- Acceptance criteria
- Edge cases
- Non-functional requirements
- Dependencies
- Analytics
- Future enhancements

## FRD Template

Every feature follows the same structure:

1. Overview
2. Objectives
3. Scope
4. User Personas
5. User Stories
6. Functional Requirements
7. Business Rules
8. User Flow
9. Validation Rules
10. Error States
11. Non-Functional Requirements
12. Analytics Events
13. Success Metrics
14. Dependencies
15. Future Enhancements
