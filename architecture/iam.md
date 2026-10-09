# Identity and access (MVP + extension map)

**Status:** Binding for the shipped owner/Admin IAM baseline; backend Vehicle Sharing, Enterprise Fleet, and verified-workshop access gates are implemented. Fleet/Workshop Portal and mobile Fleet UI remain pending.
**Contract:** `product/mvp-scope.md`.

This file is the IAM taxonomy. `users.role` remains `owner` | `admin`; Enterprise privileges come from organization membership and role. Personal `vehicles.user_id` remains the owner of record. Partner rows remain non-login records until a dedicated partner account flow is built.

Vehicle sharing grants access **per vehicle** through `vehicle_shares.access_level` (`view` | `add_edit_own`), not a new `users.role` value and not a household/group entity. Everyone involved — sharer and sharee — uses the same `dco-owner` JWT audience. Detail: `architecture/iam-vehicle-sharing.md`.

---

## MVP (implement now)

| Principal | Surface | JWT `aud` | `role` | What they can do |
|-----------|---------|-----------|--------|------------------|
| Vehicle owner | Flutter + Web | `dco-owner` | `owner` | Own garage: vehicles, plan, services, parts, fuel logs, documents, expenses, media, sync, notification feed. Shares their vehicles (owner surface) |
| Platform admin | Web admin (later UI) | `dco-admin` | `admin` | `/v1/admin/*` only: users, partners as records, audit. No owner garage screens |
| Vehicle sharee | Flutter | `dco-owner` | `owner` | Access to someone else's vehicle at `view` (read, plus fuel logs) or `add_edit_own` (read + write, records attributed to the writer). Sees "Shared with Me". See `architecture/iam-vehicle-sharing.md` |

Rules:

- Owner signup always creates `role=owner`. Admins are seeded out of band (`BOOTSTRAP_ADMIN_*`), never via `/v1/auth/signup`.
- An owner JWT must not call `/v1/admin/*`. An admin JWT must not call owner garage routes.
- User `plan` (`free` \| `lite` \| `standard` \| `fleet`, per `docs/pricing.md`) lives on the **user** and sizes Vehicle Sharing limits (free 1, lite 3, standard/fleet unlimited — one cap for per-vehicle and total) plus the advisory `vehicle_limit`. Sharing and accepting are open to all plans; downgrading revokes shares above the new caps (oldest kept) and never touches vehicles. Billing lands with the payment flow; offline local gating design: `architecture/feature-gating.md`.
- Partner rows (`workshop` \| `insurer`) are CRM records. `verified` does not issue tokens or unlock booking/claims.
- Vehicle authorization uses `getVehicleAccessLevel` → `owner` | `view` | `add_edit_own` | `null`, resolved from `vehicles.user_id` plus an active `vehicle_shares` row on every request. See `architecture/iam-vehicle-sharing.md`.
- Sync outbox and `change_log` are bound to `user_id`. After logout, another account on the same device must not push the previous outbox.

Audiences in env: `JWT_OWNER_AUD=dco-owner`, `JWT_FLEET_AUD=dco-fleet`, `JWT_WORKSHOP_AUD=dco-workshop`, `JWT_ADMIN_AUD=dco-admin`. See `docs/environment-secrets.md`.

---

## B2B extension

These personas exist in `docs/vision.md` and `docs/personas.md`. They are **not** Phase 1 products. When they land, introduce organizations as a **new** root — do not migrate every owner into a 1-person org as a prerequisite for the first vehicle share.

| Persona | Tenant | JWT `aud` | App | Status |
|---------|---------------|------------------|-----|--------|
| Fleet operator | org (`taxi_fleet`, `rental`, `commercial`) | `dco-fleet` on portal; `dco-owner` in Flutter | Fleet Portal + Flutter | Backend foundation implemented. Roles: `org_admin`, `org_manager`, `org_mechanic`, `org_driver`. Oct 2026 alignment (username drivers, role-gated portal sidebar, temp-password admin provisioning) specified, pending implementation. |
| Dealership | org `type=dealership` or `showroom` | Same audiences as Fleet | Fleet-shaped portal + Flutter | Same access model as fleet, not a separate product. |
| Workshop staff | verified workshop partner | `dco-workshop` | Web Workshop Portal | Backend account link and active-warranty service logging implemented; portal and booking remain pending. |
| Insurance agent | partner tenant | `dco-insurer` | Web Insurance Portal | Not implemented. Policy/claims modules still out. |

Fleet and verified-workshop REST/auth/schema foundations are implemented. Fleet/Workshop Portal and Flutter Fleet surfaces, workshop booking, and insurer portals remain follow-up work.

### Fleet backend contract

1. `organizations` and `organization_members` are the Enterprise access root. Enterprise is `organizations.plan=enterprise`, not a user plan or `users.role`.
2. Keep `vehicle_shares` scoped to a single owner's vehicles. Fleet inventory is linked through `organization_vehicles`; `vehicles.user_id` remains the owner of record and changes to the buyer on transfer. A vehicle linked to an organization is excluded from personal-owner routes and cannot be shared.
3. Mobile continues to use `dco-owner`; Fleet Dashboard uses `dco-fleet`; verified workshop accounts use `dco-workshop`. Insurers get a separate partner audience when claims are implemented. Do not reuse `dco-admin` for partners.
4. Change-log cursor stays per acting `user_id`; full offline Fleet sync remains to be completed.
5. Entra External ID remains an option for B2B tenants; current backend uses the existing password JWT flow (email **or username** identifier after the Oct 2026 alignment).

### Identity alignment (Oct 2026 — specified, pending implementation)

- `users.username`: globally unique, NOT NULL after backfill (derived from email local part; collisions suffixed). `users.email` becomes nullable — Postgres UNIQUE already permits multiple NULLs, so customer signup (email required at the API) and email login are unchanged.
- Login accepts **email or username** in a single identifier field; forgot-password remains email-only, so email-less drivers are reset by the Fleet Admin from the portal.
- Driver accounts (`org_driver`) are created only by the Fleet Admin with username + display name + initial password and no email; `users.must_change_password=true` blocks fleet/driver API calls (except profile/password routes) with 403 `password_change_required` until changed.
- Driver deactivation = `users.status=deactivated` (soft delete): login blocked, active `driver_assignments` cascaded to completed, history retained, reactivation allowed, username reserved permanently.
- Fleet Portal login rejects `org_driver` (403 `portal_access_restricted`); portal sidebar visibility is role-gated (admin full, manager/mechanic reduced, driver none). Mobile remains `dco-owner` for all org members, including drivers.
- Fleet Admin (`org_admin`) accounts are provisioned by DCO Admin with email + temporary password (forced change); exactly one admin per org, created only by DCO Admin.

### Implemented Backend Entitlements (Vehicle Sharing + Fleet)

- Keep `users.plan` as `free` / `lite` / `standard` / `fleet` (four-tier, `docs/pricing.md`); plan changes remain DCO-admin-managed until billing is explicitly added.
- Resolve Vehicle Sharing and Fleet as separate entitlements. Enterprise membership does not set or imply a user's plan.
- Fleet access requires an Enterprise organization, organization `status=active`, and active membership; organization role authorizes the requested operation.
- All plans can share and accept shares. `shareLimits` (`backend/src/lib/plans.ts` — single source, mirrored by `plans` table rows) caps free at 1 and lite at 3 active shares (per vehicle and total); standard/fleet are unlimited (`null`). Caps are re-checked server-side on every share create and accept/join.
- Downgrading revokes shares above the target plan's caps (oldest kept); upgrades and unlimited targets never revoke. Vehicles are never revoked — over-limit rows stay readable and editable, only new creates are blocked.
- `POST /v1/vehicles` enforces `vehicleLimit` (active/non-archived count): at cap it returns 403 `LIMIT_EXCEEDED` with `details { metric, current, limit, upgrade_url }` (`docs/pricing.md` §Limit Check Response). Idempotent replays and edits of existing rows are unaffected; sync pushes apply the same path and surface as `rejected` operations.
- `GET /v1/me/entitlements` returns `vehicle_sharing.{available,can_share,limits,active_shares}` (limit `null` = unlimited) and `features.vehicle_sharing` as navigation hints. Every protected API operation re-checks plan, membership, org status, and role server-side; mobile/portal navigation wiring remains pending.
- `GET /v1/me/license` (owner audience) issues the offline entitlement license: EdDSA compact JWT, `kid` header, self-contained tier claims, `LICENSE_TTL_DAYS` rolling expiry until billing lands (`architecture/feature-gating.md` §5). The Ed25519 private key is server-only (Key Vault/env); mobile verifies against the bundled public keyring.
- DCO Admin creates Enterprise organizations in `pending` and explicitly activates them after provisioning. A user's login does not activate an organization.
- Fleet Dashboard receives `dco-fleet`; Flutter remains on `dco-owner`. Shared Fleet APIs authorize by organization membership/role independently of audience.

---

## User-level app management (MVP)

| Concern | Owner | Admin |
|---------|-------|-------|
| Account | Signup, verify, reset, logout, deactivate (via support) | List, search, view, deactivate/reactivate, send reset |
| Plan | Field on `GET /v1/me`; charges off | Support plan change on admin user PATCH |
| Active vehicle | Required after first vehicle | Not applicable |
| Devices | Register device tokens (push send later) | Not applicable |
| Partners | Cannot see partner records | CRUD onboarding records |
