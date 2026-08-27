# DCO MVP — Product Guide (as built)

**Product:** Digital Car Ownership (DCO)  
**Audience:** Stakeholders, product, engineering  
**Status:** Working implementation, not yet production-hosted  
**As of:** August 2026  
**Scope contract:** [`product/mvp-scope.md`](../product/mvp-scope.md)

This guide describes **what the codebase actually does today**. It is not a restatement of the FRDs. Where the running software is thinner than the Phase 1 contract, that gap is called out explicitly.

---

## 1. What DCO is

DCO is a **digital garage** for a car owner: one place to keep vehicles, service history, spend, refuel/charge logs, and (when finished) documents. The owner product is a Flutter app that works **offline first**. A Fastify REST API is the durable source of truth. A Next.js **admin portal** is for staff only — user support and partner records, not owner workflows.

It is **not** Autozis. Fuel *efficiency* KPIs, insurance *policies*, trips, OCR, family sharing, marketplace, and dealer portals are out of MVP.

**Mission in this slice:** an owner can create an account, add a vehicle, track maintenance and expenses, log fuel, and have those writes survive offline and sync when the network returns. Staff can sign in, see counts, manage accounts, and record workshops/insurers.

---

## 2. Surfaces at a glance

| Surface | Who | Stack | Online? | Role today |
|---------|-----|-------|---------|------------|
| **Owner app** | Car owners | Flutter, Riverpod, GoRouter, Drift/SQLite, Dio | Offline-first after login | Primary product |
| **API** | Mobile + admin | Node 22, Fastify, Drizzle, PostgreSQL, Zod | Always online | `/v1` REST + JWT |
| **Admin portal** | Internal staff | Next.js 15 App Router, TanStack Query, Tailwind | Online-only | Users, partners, KPIs |

Visual language is **Garage Minimal Dark** (`docs/theme/garage-minimal-dark.json`): night-garage surfaces, brass accent `#EEB757`. Same tokens on mobile and web.

---

## 3. Implementation status

Honest snapshot against the Phase 1 contract.

| Area | Status | Notes |
|------|--------|-------|
| Auth (API) | **Done** | Signup, login, refresh, logout, verify, forgot/reset. Bootstrap admin from env. |
| Auth (mobile) | **Done** | Email/password screens, secure token store. Debug defaults to **mock auth**. |
| App shell | **Done** | Four tabs: Garage (Dashboard) / Maintenance / Expenses / Setting |
| Garage | **Done** | List, add/edit, archive, active vehicle, plate/VIN/mileage/fuel rules |
| Dashboard | **Done** | Active vehicle, spend, next service, recent history, quick actions |
| Maintenance | **Done** | Plan, suggested catalog by fuel type, register service, history, due calculator |
| Parts | **Done** | Per-vehicle catalog; assign on service and expense |
| Fuel logs | **Done** | Refuel vs charge by vehicle fuel type; owner-defined fuel types |
| Expenses | **Done** | Categories, summaries, receipts (local photo), assign parts |
| Documents (API) | **Done** | CRUD + media attach on the server |
| Documents (mobile) | **Placeholder** | Empty screen only — no Drift table, no upload UI |
| Insurance screen | **Placeholder** | Explicitly deferred; copy points to Documents |
| Sync engine | **Done (core)** | Outbox → push → media upload → pull. Mileage max-wins; archive wins |
| In-app notification feed | **Partial** | Local rows + status (done/dismiss). No OS local notifications package |
| Web admin | **Done** | Login BFF, dashboard, users, partners |
| Azure | **Deployable, not deployed** | `azure.yaml` + Bicep for the **API** only |
| Monetization | **Field only** | `plan` is `free`/`premium`; vehicle limits are **not** enforced |
| Analytics | **Debug only** | `debugPrint` in debug builds; several MVP events not yet tracked |

---

## 4. Owner app — how to use it

### 4.1 Accounts

Unauthenticated routes: Welcome, Login, Signup, Forgot password.

- Signup requires email + password (min 8 characters).
- After login the app lands on **Dashboard**.
- Debug builds mock the API unless `DCO_MOCK_AUTH=false`. Any valid email and 8-character password works in mock mode.
- Release builds never mock. Tokens live in Keychain/Keystore.
- Unverified email shows a banner on Dashboard with **Resend**.

Auth itself is **online-only**. After a session exists, garage/maintenance/expenses/fuel work without a network.

### 4.2 Navigation

Bottom tabs (labels match the wireframe):

| Tab | Path | What you see |
|-----|------|----------------|
| **Garage** | `/dashboard` | Active vehicle home |
| **Maintenance** | `/maintenance` | Upcoming / scheduled / history |
| **Expenses** | `/expenses` | Spend for the active vehicle |
| **Setting** | `/settings` | Account, localization, units, sign out |

Header on Dashboard: vehicle chip → **My Garage**; garage icon (same); bell → in-app notification feed.

Documents and Insurance are **not** tabs. They open from Dashboard quick actions (and Documents also from Expenses).

### 4.3 Dashboard

If the garage is empty: CTA **Register a vehicle**.

With an active vehicle:

- Nickname / display name, mileage (respects unit preference)
- Ownership spend: **total** and **this month**, from **expenses only** (not service-record costs or fuel-log costs)
- Next maintenance from the enabled plan
- Recent activity: last 3 service records
- Quick actions: Services, Documents, Insurance (placeholder), Refuel/Charge, Parts

### 4.4 Garage

- Cards: photo, nickname, make/model, plate, mileage, next maintenance
- **Add vehicle** required: name, year, make, model, plate, mileage, fuel type (`petrol` / `electric` / `hybrid_plugin`)
- Optional: VIN (17 chars), color, nickname, purchase date, photo
- Edit updates the same fields
- Archive is a soft-delete; child records stay attached
- Switching a card sets the active vehicle and returns to Dashboard
- One active vehicle is always selected once the garage is not empty

### 4.5 Maintenance

- **Plan:** custom items (name + time and/or distance interval) and **suggested** items filtered by fuel type (oil change is petrol/hybrid only, etc.)
- Due states: Overdue / Due soon / Scheduled (word + color; overdue is not gold)
- **Register service:** date, odometer, items, total cost, workshop, notes, optional receipt photo, optional parts
- Completing a plan item rolls the next due date/mileage
- Service history is chronological; detail screen shows line items and parts

### 4.6 Parts

Owner-defined catalog per vehicle (name, optional brand, part number, notes). Attach parts when logging a service or an expense.

### 4.7 Fuel

- **Logs:** date, type, amount, cost. Petrol and hybrid plugin → Refuel. Electric → Charge.
- **Fuel Types** catalog: name, kind (liquid vs electric), unit. Seeded on API signup (Petrol, Diesel, Electricity).
- List filters: fuel type, this month / all dates.
- Volume/kWh live here. A fuel *expense* is money only.

### 4.8 Expenses

- Category: fuel, maintenance, insurance, parking, tolls, parts, other
- Amount, date (not more than one day in the future), notes, optional receipt, optional parts
- Monthly and total summaries per vehicle
- Dashboard totals read this table only

### 4.9 Documents and insurance (current)

**Documents:** empty state only (“No documents yet”). Upload, categories, and viewer are not implemented on mobile even though the API supports them.

**Insurance:** placeholder (“Insurance coming later”). Store papers in Documents when that vault ships. No policy module in MVP by design.

### 4.10 Settings and notifications

- Email, hardcoded **Free Plan** label, mock vs live hint
- Localization: English / Myanmar (preference stored locally; UI strings are still English)
- Units: USD/MMK and mi/km
- Sign out discards tokens; outbox stays bound to `user_id`
- Notification feed: list, mark done, dismiss, restore. Rows arrive from sync/API; the app does **not** schedule OS local notifications yet (`flutter_local_notifications` is specified, not added)

### 4.11 Offline and sync (owner)

1. Widgets read **Drift only**.
2. A write: local row → outbox row → UI updates immediately.
3. Sync: cold start after auth, reconnect, ~1s debounce after write, manual retry from a sync-error dialog.
4. Push operations, then pending media bytes, then pull the change log.
5. Mileage conflict: `max(local, remote)`; never decrease. Archive wins over a later edit.
6. Sync status is informational and must not block navigation.
7. Client UUIDs make creates idempotent.

---

## 5. Admin portal — how to use it

Staff-only. Owner JWTs are rejected at login.

1. Open the web app → `/login`
2. Email + password → Next.js BFF (`POST /api/auth/login`) → Fastify `/v1/auth/login`
3. Refresh token is an **httpOnly** cookie; access token is also cookied and used as Bearer to `/v1/admin/*`
4. Middleware sends anyone without a refresh cookie to login

**Dashboard:** users total, active vehicles, partners, sync-errors-24h (currently always `0`), recent signups.

**Users:** search, filter by status, open profile (email, plan, vehicles, document count). Actions: change plan, deactivate (revokes refresh tokens), reactivate, send password-reset email.

**Partners:** workshops and insurers as CRM rows (`draft` / `pending_verification` / `verified` / `rejected`). Creating a partner does **not** issue a login. No booking or claims product.

Admin never streams owner document bytes in the default profile view.

---

## 6. Technical specifications

### 6.1 API (`/v1`)

Contract: [`architecture/openapi.yaml`](../architecture/openapi.yaml). Swagger UI at `http://localhost:8080/docs` when `APP_ENV` is not `prod`.

| Group | Examples |
|-------|----------|
| Health | `GET /health`, `GET /ready` |
| Auth | signup, login, refresh, logout, verify-email, forgot/reset password |
| Me | profile, device-token register |
| Vehicles | CRUD, archive, activate, dashboard aggregate |
| Maintenance | plan-items, suggested catalog, service records |
| Parts / Fuel | parts, fuel-types, fuel-logs |
| Documents / Expenses | CRUD, expense summary |
| Notifications | list + status patch |
| Media | multipart upload (15 MB), signed download |
| Sync | `POST /sync/push`, `GET /sync/changes?cursor=` |
| Admin | dashboard, users, partners; `role=admin` + `aud=dco-admin` |

JWT: short-lived access (`dco-owner` or `dco-admin`) + rotating refresh families. Password reset revokes all families for that user. First admin is seeded from `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD`, never via owner signup.

### 6.2 Data model (PostgreSQL)

Core tables: `users`, `vehicles`, `plan_items`, `service_records` (+ items/parts), `parts`, `fuel_types`, `fuel_logs`, `documents`, `expenses` (+ parts), `notification_feed`, `media_objects`, `change_log`, `partners`, `refresh_tokens`, `email_tokens`, `device_tokens`, `audit_events`.

Business rules the server enforces:

- Plate unique per account among non-archived vehicles
- VIN unique when set (exactly 17 characters)
- Year 1900 … current year + 1; plate max 20
- Mileage ≥ 0 and **monotonic**
- Fuel type required: petrol / electric / hybrid_plugin
- Archive, do not hard-delete, vehicles
- `users.plan` exists; **gating is off**

Mobile Drift mirrors owner entities **except documents** (no local documents table yet).

### 6.3 Media

- Cap 15 MB. Local driver on laptop; Azure Blob when `MEDIA_DRIVER=azure_blob`
- JSON stores `blob_key`, content type, size, sha256 — not a public vendor URL
- Download: authenticated GET or short-lived HMAC-signed URL
- Mobile: `image_picker` with `imageQuality: 85`; dedicated compression pipeline and PDF vault upload are not built

### 6.4 Hosting

- **Local API:** Docker Compose Postgres, `npm run db:migrate`, `npm run dev` → `http://localhost:8080/v1`
- **Azure (API):** Container Apps, PostgreSQL Flexible Server, Blob, ACS Email, Key Vault. IaC at repo root. First `azd up` has not been required yet.
- **Web:** second Container App in the ADR; **not** wired in `azure.yaml` yet. Run `npm run dev` in `web/` locally.
- Secrets: never in git. See [`docs/environment-secrets.md`](environment-secrets.md) (draft).

### 6.5 Tests

- **Mobile:** domain/repository tests (validators, due calculator, sync engine, vehicles, maintenance, parts, fuel, expenses, notifications). No integration_test suite filled out.
- **API:** Vitest for auth, vehicles, sync, admin.
- **Web:** no Vitest/MSW suite yet (ADR called for it).

---

## 7. What is explicitly out of this MVP

From [`product/mvp-scope.md`](../product/mvp-scope.md) — do not treat these as missing bugs:

- Fuel economy (MPG / L/100km / kWh/100km)
- Insurance policy management
- Receipt OCR
- Family sharing, fleet, dealer/workshop/insurer product portals
- Marketplace, booking, trips, PDF reports, AI assistant
- Push marketing campaigns
- Light theme

---

## 8. Related documentation

| Need | Document |
|------|----------|
| What *should* ship | `product/mvp-scope.md` |
| Feature behavior | `product/frd/*.md` |
| System / JWT / offline | `architecture/system.md` |
| ERD | `architecture/data-model.md` |
| HTTP shapes | `architecture/openapi.yaml` |
| Navigation | `docs/app-shell.md` |
| Flutter agent rules | `mobile/AGENTS.md` |
| Theme | `docs/design-system.md` |
| Roadmap after MVP | `docs/product-roadmap.md` |

---

## 9. Local runbook (developers)

**API**

```bash
cd backend
cp .env.example .env
docker compose up -d postgres
npm install
npm run db:migrate
npm run dev
npm test
```

**Owner app**

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run                                          # mock auth
flutter run --dart-define=DCO_MOCK_AUTH=false        # live API
flutter test
```

**Admin**

```bash
cd web
npm install
npm run dev   # http://localhost:3000
```

Point the BFF at the same API base URL as the mobile client (`/v1`). Sign in with the bootstrap admin, not an owner account.
