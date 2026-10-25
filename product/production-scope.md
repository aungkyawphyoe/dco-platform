# Production Scope

**Product:** AutoX Platform

**Version:** 1.0

**Status:** Active — source of truth for what ships now

**Last Updated:** October 2026

MVP is closed. [`product/mvp-scope.md`](mvp-scope.md) is the historical Phase 1 contract (what shipped); it no longer gates new work. This file is the source of truth for the production app. `docs/product-roadmap.md` and `product/frd/` must not contradict it.

## Subscription administration — 24 October 2026

[Subscription Management and Admin Pricing](frd/subscription-management.md) is approved for implementation across API, Admin, mobile, Fleet Portal, and public pricing. It supersedes older exclusions of admin subscription management and immutable catalog prices. Direct-paid personal/Fleet terms have seven-day grace; complimentary grants have none. Fleet terms belong to organizations. Existing organizations retain access pending explicit migration; new organizations require terms. Managed personal downgrades preserve records/shares and restrict editing to one locked vehicle. Existing promotional gift expiry retains its previous contract. Store prices/lifecycle remain provider-controlled. iOS checkout and local gateway integration remain future work.

## Approved mobile realignment — 18 October 2026

The approved target is [Personal / Driver mobile realignment](frd/mobile-personal-driver-realignment-plan.md). It supersedes the earlier restricted Driver definition: shared mobile screens, full assigned-vehicle history and costs, all existing expense categories, account-isolated offline synchronization, admin-owned plans, and author-owned record corrections with admin locks/review. Separate accounts and logical organization isolation remain. This is an implementation target, not a claim that all capabilities have shipped.

Assignment foundations now permit multiple vehicles per Driver and multiple Drivers per vehicle, with one active link per pair. The remaining delivery phases are tracked in the approved plan.

---

## Relationship to MVP

Everything in MVP scope shipped and remains in the product, with **one replacement**: the MVP **Family Sharing** module was superseded by **Vehicle Sharing** (per-vehicle shares, no household/group entity) — see `product/frd/vehicle-sharing.md`. The family tables and endpoints were removed by `backend/drizzle/0008_vehicle_sharing.sql`, which converted existing grants into shares. Production scope otherwise **adds** to the MVP baseline; it does not remove MVP features. Rules that still apply from MVP unless this file overrides them:

- Domain rules (plate/VIN uniqueness, archive-not-delete, mileage monotonic, fuel type enum) — see `architecture/data-model.md`.
- Offline-first + sync outbox for server-backed entities.
- Light and dark themes (default: system) on mobile, web admin, and fleet portal; Garage Minimal tokens only — see `docs/design-system.md`.
- Autozis deferred modules stay out (trips, insurance policies, OCR, assistant/PDF export, admin routes). Fuel-efficiency KPIs ship only in the Stats module (`product/frd/stats.md`).

---

## In Scope (Production)

### Inherited from MVP (shipped)

Auth, app shell, Drift/SQLite, sync outbox, dashboard, garage, maintenance, documents, expenses, parts, refuel/charge logs, local reminder notifications, vehicle sharing (Family Sharing replaced — see `product/frd/vehicle-sharing.md`), web admin portal, REST API.

### Added in production

| Feature | Description | Sync |
|---------|-------------|------|
| **Notes** | Personal notebook: title + plain-text body, CRUD, 2-column uniform grid (Google Keep–style layout, clamped 3-line preview), sorted `updated_at DESC`. Global per-user (not vehicle-scoped). Entry point: Dashboard Quick Actions (replaces Parts tile; Parts remains reachable from the hamburger menu). Routes `/notes`, `/notes/new`, `/notes/:id`. | **Local-only** — Drift table `notes`, **no outbox**, no server API. Scoped by `user_id` like other tables so a different account on the same device does not see another account's notes. No extra wipe on logout or uninstall (SQLite lives in the app container; logout behavior matches the rest of the local DB). |
| **Reminder thresholds** | Settings → Reminders (`/settings/reminders`): sliders for the upcoming window (7–60 days, default 30) and the mileage due-soon distance (100–1000 km in 100 km steps, default **500 km** — raised from the MVP 100 km) plus Reset to defaults. Shared by the OS reminder schedule and the in-app Upcoming grouping (`DueThresholds`). | **Local-only** — stored on `user_profiles` (`soon_days`, `soon_distance_km`), no outbox, no API (same treatment as language/currency/length unit). |
| **Email reminders** | Settings → Reminders → Email reminders: opt-in server-side email for the same maintenance plan items, with a per-account lead time (7–60 days, default 30). Requires a verified email; the switch is disabled with a verification link otherwise. One upstream/due email per plan-item cycle, retried on mail failure (1 h backoff, max 3). Owner vehicles only; organization/fleet vehicles excluded. `GET`/`PUT /v1/me/reminder-emails`; scheduler `REMINDER_EMAIL_SCAN_MINUTES` (default 15, 0 disables). Contract: [`product/frd/notifications.md`](frd/notifications.md). | **Server-side** — preferences on `users`; deliveries logged in `reminder_email_deliveries`. No mobile local table or outbox. |
| **Theme (Light / Dark / System)** | Mobile: Settings → Appearance (`/settings/appearance`), three choices, default System; OS status/navigation bars follow the theme. Web admin + fleet portal: 3-way toggle in the shell (sidebar footer; top bar on the owner surface), default System, persisted in the `dco_theme` cookie with a pre-paint script (no flash). Tokens: `docs/theme/garage-minimal-{dark,light}.json` generated by `tools/generate-theme.mjs`. | **Local-only** — stored on `user_profiles` (`theme_mode`), no outbox, no API (same treatment as language/currency/length unit). Web choice is a client cookie (not account data). |
| **Stats** | Hamburger → Stats: Fuel Stats (adaptive charge/refuel KPIs), Maintenance Stats, Expense Stats for the active vehicle. Year/Month filters, KPI cards, 2 charts per screen (fl_chart), definitions modal. Local Drift aggregation — no stats API. Adds optional `odometer` to fuel logs (syncs normally; `openapi.yaml` + `data-model.md` amended). Contract: [`product/frd/stats.md`](frd/stats.md). | **Sync** — stats are computed locally; only the new fuel-log `odometer` field travels through the existing outbox/change log. |

### Onboarding and authentication — implemented, external acceptance pending

The approved release adds Burmese/English language choice before login (device-preselected, switchable from the app bar), three skippable illustrated introduction screens, minimal signup, Google and Apple on both Android and iOS, six-digit email verification with skip/correction/resend, authenticated identity linking, and complete code-based password recovery. First vehicle setup remains optional. Unverified owners retain personal access and existing shares; creating shares and accepting invitations require verification. Social-only accounts cannot acquire their first password through recovery.

Behavior: [Auth FRD](frd/auth.md). Delivery phases, setup dependencies, compatibility, and acceptance: [implementation specification](../docs/onboarding-auth-implementation.md). Existing backend and account identities are retained. Provider registrations, callback domain, and production email sender setup are outstanding. The implementation is in the repository; production provider/email setup and real-device acceptance remain pending. See [setup and rollout](../docs/auth-provider-setup.md).

### Account and feature entitlements

- **Free (`users.plan=free`)**: basic personal garage, maintenance, expenses, documents, and fuel features, plus Vehicle Sharing capped at **1 active share** (per vehicle and total) and **1 vehicle** (create enforced server-side: 403 `LIMIT_EXCEEDED`, `architecture/feature-gating.md` §9). Fleet entry points are hidden unless the user has an active membership.
- **Paid tiers (`users.plan=lite|standard|fleet`)** per `docs/pricing.md`: vehicles 3 / 10 / unlimited, sharing 3 / unlimited / unlimited, storage 150 MB / 500 MB / 5 GB. Base plans remain AutoX-admin-managed. The approved pricing/gifts slice adds personal plan comparison and time-limited Lite/Standard gift grants, managed through AutoX Admin; Android Google Play subscriptions are approved as of 22 October 2026: Lite/Standard monthly/annual auto-renewing base plans, verified backend entitlement, restore/manage, RTDN and reconciliation. iOS checkout, trial offers and in-app plan replacement remain out of scope. See `docs/google-play-subscriptions.md`. See [Mobile pricing and promotions](frd/mobile-pricing-promotions.md). Offline local gating design: `architecture/feature-gating.md`.
- **Enterprise (`organizations.plan=enterprise`)**: organization-level Fleet access for active members of an active organization, with actions restricted by organization role. AutoX Admin provisions the organization and explicitly activates it. Enterprise does not change a member's personal `users.plan`.
- **Fleet account alignment (Oct 2026 — implemented)** — details in `product/frd/fleet-management.md`:
  - Fleet Admin (`org_admin`) accounts are created by AutoX Admin with email + temporary password (forced change on first login); invite-email provisioning retires for new organizations.
  - Drivers are created/deactivated **only on the Fleet Portal Members page by email + role `org_driver` + temporary password**; creation rejects emails belonging to existing personal accounts (409 `personal_account_exists`). The username-only driver endpoint and Web Admin driver management are removed. Driver deactivation is a soft delete: assignment cascaded, history retained, username reserved. Login accepts email or username (customer signup stays email-only).
  - Fleet Portal sidebar is role-gated: full nav for `org_admin`, reduced nav for `org_manager`/`org_mechanic`, no portal login for `org_driver`. Mobile has no fleet management surface; management routes require the `dco-fleet` audience.
  - Driver login forces Driver mode (implemented); drivers may edit only their own profile/password and cannot create/edit/delete vehicles or other users (**server-enforced — includes 403 `personal_garage_forbidden` on all personal-garage routes** while `org_driver` role or an active assignment exists).
- **Driver surface realignment (Oct 2026 — implemented; second grilling; details in `product/frd/fleet-management.md` Driver Surface Decisions 15–24):**
  - Driver mode uses the **same four tabs and screens as personal mode** (Garage / Maintenance / Expenses / Settings); driver repositories map to org endpoints, online-first (no Drift/outbox for org data). The 3-tab My Vehicle / My Reports shell is removed.
  - Garage tab shows the assigned vehicle **read-only** (single My Garage row, "+" hidden, no edit/share; spend cards hidden). Expenses tab is **fuel logs only**.
  - Dashboard Quick Actions for drivers: **Report Issue · Start Inspection · Refuel · Notes** (personal set unchanged: Log Service · History · Refuel · Notes). Report Issue stays standalone; Reports is a pushed screen (own inspections + Report-Issue work orders).
  - **Maintenance logging** (Maintenance tab → Register service): segmented **Report | Do myself** — Report creates a work order (Reported in history until the fleet completes it); Do myself writes a service record (Completed immediately). Cost is always required; plan-linked logs advance the plan item; free-text logs never touch a plan.
  - **Work-order completion** (portal, Admin/Manager) requires cost → auto service record at report-time odometer (+ notes, free-text parts); plan-linked WOs advance the plan item. The auto record is portal-only — the driver's history shows the WO row's status (refresh-driven).
  - **Shift mileage retired**: `shift_mileage` table/routes deleted; mileage is log-driven only (service/fuel logs bump `vehicles.mileage`); odometer fields auto-fill from `vehicles.mileage`.
  - **Fleet Portal visibility**: `GET /organizations/:id/vehicles/:vehicleId/service-records` plus read-only **Service history** and **Maintenance plan** cards on vehicle detail — every driver log is checkable.
- Sharing works on every plan: a sharee never needs a paid plan to hold or use a share. Downgrading the owner revokes shares above the new plan's caps (oldest kept) and blocks new ones while over the cap; vehicles are never revoked or hidden.
- Backend authorization is authoritative. Hiding unavailable feature entry points in the mobile/web clients is a separate client requirement.

Notes rules:

- `id` UUID v4, `title` (optional — untitled allowed; max 500 chars), `body` (plain text), `created_at`, `updated_at`, `user_id`.
- Strictly title + body — no colors, pins, labels, or search in this slice.
- Delete uses Keep-style SnackBar with **Undo** (no confirmation dialog).
- Title-only or body-only empty drafts are allowed only when at least one of title/body has non-whitespace content (discard fully empty notes).

---

## Out of Scope (Production, still deferred)

Same deferrals as MVP out-of-scope, plus not in this slice:

- Note sync / server backup / cross-device notes
- Note search, colors, pins, labels, checklists, attachments
- Trash folder / soft-delete beyond snackbar undo

---

## Scope governance

1. To ship a feature: add it here (and update FRD / `mobile/AGENTS.md` if behavior or navigation changes).
2. MVP scope does not block production features. Do not reopen `product/mvp-scope.md` to add work — add it here.
3. HTTP shapes still win in `architecture/openapi.yaml`; local-only features have no OpenAPI entry.


## Document storage expansion — approved 20 October 2026

The approved [Documents and Storage specification](frd/documents.md) extends production scope with account/organization storage quotas, service and fuel multi-attachments, personal license visibility in Documents, and restricted platform/fleet administration. Its permission and ownership decisions supersede earlier document rules. Implementation is in progress; specification approval is not completion.
