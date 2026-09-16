# Identity and access (MVP + extension map)

**Status:** Binding for MVP. Family sharing is implemented; fleet, dealer, and partner logins are documentation only.  
**Contract:** `product/mvp-scope.md`.

This file is the IAM taxonomy. The runtime model stays as `architecture/data-model.md`: `users.role` is `owner` | `admin`, vehicles belong to `user_id`, partners cannot sign in.

Family sharing uses `family_memberships.role` (`primary_owner` | `member` | `driver`) for per-vehicle authorization, not a new `users.role` value. All family participants use the same `dco-owner` JWT audience.

---

## MVP (implement now)

| Principal | Surface | JWT `aud` | `role` | What they can do |
|-----------|---------|-----------|--------|------------------|
| Primary owner | Flutter | `dco-owner` | `owner` | Own garage: vehicles, plan, services, parts, fuel logs, documents, expenses, media, sync, notification feed |
| Platform admin | Web admin (later UI) | `dco-admin` | `admin` | `/v1/admin/*` only: users, partners as records, audit. No owner garage screens |
| Family member | Flutter | `dco-owner` | `owner` | Granted vehicle access: full (CRUD on services/expenses/fuel/docs) or drive_only (fuel + doc view). Family view. See `architecture/iam-family.md` |

Rules:

- Owner signup always creates `role=owner`. Admins are seeded out of band (`BOOTSTRAP_ADMIN_*`), never via `/v1/auth/signup`.
- An owner JWT must not call `/v1/admin/*`. An admin JWT must not call owner garage routes.
- Freemium `plan` (`free` \| `premium`) lives on the **user**. Gating is not enforced in MVP; the field must exist.
- Partner rows (`workshop` \| `insurer`) are CRM records. `verified` does not issue tokens or unlock booking/claims.
- Family authorization uses `family_memberships.role` + `vehicle_grants`. See `architecture/iam-family.md`.
- Sync outbox and `change_log` are bound to `user_id`. After logout, another account on the same device must not push the previous outbox.

Audiences in env: `JWT_OWNER_AUD=dco-owner`, `JWT_ADMIN_AUD=dco-admin`. See `docs/environment-secrets.md`.

---

## Future map (do not implement)

These personas exist in `docs/vision.md` and `docs/personas.md`. They are **not** Phase 1 products. When they land, introduce organizations as a **new** root — do not migrate every owner into a 1-person org as a prerequisite for the first family share.

| Persona | Future tenant | Future JWT `aud` | App | Notes |
|---------|---------------|------------------|-----|--------|
| Fleet operator | org `type=fleet` | `dco-fleet` | Web Fleet Portal | First B2B follow-on after Phase 1. Roles: org admin, dispatcher, driver. |
| Dealership | org `type=dealership` | `dco-fleet` (or `dco-dealer` if the portal forks) | Web (fleet-shaped) | Same access model as fleet, not a separate product. |
| Workshop staff | partner tenant | `dco-workshop` | Web Workshop Portal | Post-MVP SaaS. Booking is still out. |
| Insurance agent | partner tenant | `dco-insurer` | Web Insurance Portal | Post-MVP SaaS. Policy/claims modules still out. |

Insurance, Workshop, and Analytics portals remain B2B SaaS after MVP. Fleet Portal is the first documented B2B follow-on; it is not built in this slice.

### Extension plan (when fleet starts)

1. Add `organizations` (`id`, `type`, `name`, `status`) and `organization_members` (`org_id`, `user_id`, `org_role`).
2. Add `vehicle_grants` (`vehicle_id`, `user_id` or `org_id`, permission). Keep `vehicles.user_id` as the billing/owner of record for existing personal garages. (`vehicle_grants` already exists for family sharing; fleet grants would be org-scoped.)
3. Mint extra audiences only for new surfaces (`dco-fleet`, later workshop/insurer). Do not reuse `dco-admin` for partners.
4. Change-log cursor stays per acting `user_id` unless a later ADR introduces org-scoped sync.
5. Entra External ID is an option for B2B tenants; MVP stays custom email/password JWT.

---

## User-level app management (MVP)

| Concern | Owner | Admin |
|---------|-------|-------|
| Account | Signup, verify, reset, logout, deactivate (via support) | List, search, view, deactivate/reactivate, send reset |
| Plan | Field on `GET /v1/me`; charges off | Support plan change on admin user PATCH |
| Active vehicle | Required after first vehicle | Not applicable |
| Devices | Register device tokens (push send later) | Not applicable |
| Partners | Cannot see partner records | CRUD onboarding records |
