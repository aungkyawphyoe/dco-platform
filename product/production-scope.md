# Production Scope

**Product:** Digital Car Ownership Platform (DCO)

**Version:** 1.0

**Status:** Active — source of truth for what ships now

**Last Updated:** September 2026

MVP is closed. [`product/mvp-scope.md`](mvp-scope.md) is the historical Phase 1 contract (what shipped); it no longer gates new work. This file is the source of truth for the production app. `docs/product-roadmap.md` and `product/frd/` must not contradict it.

---

## Relationship to MVP

Everything in MVP scope shipped and remains in the product. Production scope **adds** to that baseline; it does not remove MVP features. Rules that still apply from MVP unless this file overrides them:

- Domain rules (plate/VIN uniqueness, archive-not-delete, mileage monotonic, fuel type enum) — see `architecture/data-model.md`.
- Offline-first + sync outbox for server-backed entities.
- Dark theme only; Garage Minimal Dark tokens only.
- Autozis deferred modules stay out (trips, insurance policies, OCR, assistant/PDF export, fuel-efficiency KPIs, admin routes, light theme).

---

## In Scope (Production)

### Inherited from MVP (shipped)

Auth, app shell, Drift/SQLite, sync outbox, dashboard, garage, maintenance, documents, expenses, parts, refuel/charge logs, local reminder notifications, family sharing, web admin portal, REST API.

### Added in production

| Feature | Description | Sync |
|---------|-------------|------|
| **Notes** | Personal notebook: title + plain-text body, CRUD, 2-column uniform grid (Google Keep–style layout, clamped 3-line preview), sorted `updated_at DESC`. Global per-user (not vehicle-scoped). Entry point: Dashboard Quick Actions (replaces Parts tile; Parts remains reachable from the hamburger menu). Routes `/notes`, `/notes/new`, `/notes/:id`. | **Local-only** — Drift table `notes`, **no outbox**, no server API. Scoped by `user_id` like other tables so a different account on the same device does not see another account's notes. No extra wipe on logout or uninstall (SQLite lives in the app container; logout behavior matches the rest of the local DB). |

### Account and feature entitlements

- **Normal (`users.plan=free`)**: basic personal garage, maintenance, expenses, documents, and fuel features. Family and Fleet entry points are hidden unless the user has an active membership.
- **Premium (`users.plan=premium`)**: basic personal features plus Family creation/management for the Primary Owner. Premium is DCO-admin-managed for now; no in-app purchase or subscription billing flow.
- **Enterprise (`organizations.plan=enterprise`)**: organization-level Fleet access for active members of an active organization, with actions restricted by organization role. DCO Admin provisions the organization and explicitly activates it. Enterprise does not change a member's personal `users.plan`.
- Family invitees do not need Premium to use their active role/grant-scoped access. If the Primary Owner loses Premium, the family is archived and shared access is revoked.
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
