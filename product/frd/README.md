# Feature Requirement Documents (FRDs)

This directory contains the functional specifications for every feature of the AutoX Platform.

Each FRD is self-contained and serves as the primary source of truth for:

- Product Managers
- Designers
- Engineers
- QA Engineers
- AI Development Agents

Scope contract: `product/production-scope.md` (active) and `product/mvp-scope.md` (closed Phase 1 record). If an FRD disagrees with those files, the scope file wins and the FRD must be updated.

Superseded FRDs move to [`archive/`](archive/).

**As-built** (what the code does today) lives in [`docs/mvp-as-built.md`](../../docs/mvp-as-built.md). The status column below is that snapshot against each FRD. Do not re-implement a **Done** module. Do not treat Autozis sidebar items as backlog.

**As of:** 17 October 2026.

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
| Dashboard | [dashboard.md](dashboard.md) | Mobile (default after login) | **Done** | Spend is expenses-only. No Insurance/Documents quick actions — Insurance is deferred Autozis; Documents is reached from Expenses and vehicle flows. |
| Garage | [garage.md](garage.md) | Mobile + API | **Done** | Un-archive is not in the UI. One-vehicle free cap enforced server-side (403 `LIMIT_EXCEEDED`) and locally: the license gate hides the Garage "+" / add-card at cap (upsell copy) and denies create at the form save. |
| Auth | [auth.md](auth.md) | Mobile + API | **Partial** | Email/password baseline exists. October code implemented: onboarding, Google/Apple on both platforms, code verification, linking, and recovery. Live setup/device acceptance pending. See [implementation plan](../../docs/onboarding-auth-implementation.md). |
| Maintenance | [maintenance.md](maintenance.md) | Mobile + API | **Done** | Plan, suggested catalog, register service, history. OS local reminders are owned by [notifications.md](notifications.md). |
| Documents | [documents.md](documents.md) | Mobile + API | **Done** | Full vault: Drift table, CRUD, upload/viewer, sync outbox. |
| Expenses | [expenses.md](expenses.md) | Mobile + API | **Done** | Categories, summaries, receipt photo, assign parts. |
| Sync | [sync.md](sync.md) | Mobile + API | **Done** (core) | Outbox → push → media → pull. Documents sync outbox wired. Live status in drawer → Sync status (bound to `SyncEngine`); no Settings sync row. |
| Notifications | [notifications.md](notifications.md) | Mobile + API | **Done** (local + email) | OS local reminders (`flutter_local_notifications`), user-configurable thresholds (default 30 days / 500 km), and opt-in server-side maintenance emails (verified email, lead time, dedupe). In-app feed. No remote FCM/APNs. Device-token register exists on the API. |
| Parts | [parts.md](parts.md) | Mobile + API | **Done** | Per-vehicle catalog; assign on service and expense. |
| Fuel | [fuel.md](fuel.md) | Mobile + API | **Done** | Logs + Fuel Types. `petrol` / `hybrid_plugin` → Refuel only; `electric` → Charge. Optional odometer + economy KPIs live in [stats.md](stats.md). |
| Stats | [stats.md](stats.md) | Mobile | **Done** | KPIs, charts, period filters (local Drift aggregation, no stats API); optional fuel-log odometer feeds distance/consumption KPIs. |
| Admin | [admin.md](admin.md) | Web portal + API | **Done** | Login BFF, users, partners. `sync_errors_24h` is always `0`. No web test suite. |
| Vehicle Sharing | [vehicle-sharing.md](vehicle-sharing.md) | Mobile + API + Web | **Done** | Per-vehicle shares via Code/QR or email, `view` \| `add_edit_own`, plan limits, share management screen, Shared with Me, owner shares page. Replaces Family Sharing (archived in [archive/family-sharing.md](archive/family-sharing.md)). Billing out of scope. |
| User Profile & Account Management | [user-profile.md](user-profile.md) | Mobile + API + Web Admin | **Done** | Profile fields + photo, Dashboard completion banner, Settings profile edit, account deletion (vehicles archived, shares revoked), admin create with temp password, admin deactivate/reactivate, admin user detail with phone/address. Gap: admin create accepts only display name — phone/address are edited on user detail. |
| Fleet Management | [fleet-management.md](fleet-management.md) | Mobile + Fleet Dashboard + Web Admin + API | **Partial** | Backend implemented: org provisioning/activation, roles, inventory + CSV, driver assignments, work orders, inspections, analytics, warranty templates, transfer, approved workshops, workshop accounts (`dco-workshop`), workshop warranty service. Fleet Dashboard implemented as separate Next.js app in `fleet-portal/` (`dco-fleet` BFF session). Surfaces still missing: Workshop Portal. Mobile Fleet/Driver modes are implemented in `mobile/`. Web Admin (`admin.yourdomain.com`) handles user management, org provisioning, partner records, and read-only fleet support. **Oct 2026 alignment (email-based driver accounts via Members, role-gated portal sidebar, temp-password Fleet Admin provisioning, driver soft delete, forced Driver mode) is implemented — see its "Requirement alignment" note.** |

There is **no Settings FRD**. Localization (English/Myanmar — the UI renders in either, a few strings untranslated) and units (USD/MMK, mi/km) live in the owner app Settings tab. See [`docs/mvp-as-built.md`](../../docs/mvp-as-built.md) §4.10.

Dashboard consumes Garage, Maintenance, Expenses, and Documents. Navigation: `docs/app-shell.md`. API: `architecture/openapi.yaml`.

---

## Next implementation

### Planned subscription and pricing administration — 24 October 2026

[Subscription Management and Admin Pricing](subscription-management.md) records the agreed requirements for subscription visibility, direct-paid terms, complimentary grants, expiry and renewal, per-organization migration, and editable catalog prices. **Implemented locally; deployment pending.** See its linked rollout notes for validation and deployment requirements. Google Play checkout already has a separate implementation described in [its release guide](../../docs/google-play-subscriptions.md); the older next-step summary below predates that work.

MVP core functionality is shipped. Fleet backend (organizations, inventory, warranty, transfer, approved workshops, workshop accounts), the Fleet Portal (`fleet-portal/`), mobile Fleet/Driver modes, User Profile & Account Management, and the Stats module are implemented; the Workshop Portal remains a planned surface. The **Oct 2026 Fleet alignment** (email-based driver accounts via Members, role-gated portal sidebar, temp-password Fleet Admin provisioning, driver soft delete, forced Driver mode) is implemented — see `fleet-management.md` § Requirement alignment.

**Next:** billing/payment slice (`product/production-scope.md` — plans are admin-managed today, no in-app purchase) and the auth live rollout (real Google/Apple providers, email delivery, device acceptance — `docs/auth-provider-setup.md`).

**Phase 3 (Year 2):** Workshop Portal (`fleet-management.md`) — the last missing Fleet surface; workshop accounts and the `dco-workshop` audience already exist on the API.

Do not pull Autozis modules (trips, insurance policies, OCR, assistant, PDF) into these FRDs. Fuel *efficiency* KPIs belong only in [stats.md](stats.md) — never on Dashboard, Garage, or the Fuel module itself.

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
