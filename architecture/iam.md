# Identity and access (MVP + extension map)

**Status:** Binding for the shipped owner/Admin IAM baseline; backend Family Premium, Enterprise Fleet, and verified-workshop access gates are implemented. Fleet/Workshop Portal and mobile Fleet UI remain pending.
**Contract:** `product/mvp-scope.md`.

This file is the IAM taxonomy. `users.role` remains `owner` | `admin`; Enterprise privileges come from organization membership and role. Personal `vehicles.user_id` remains the owner of record. Partner rows remain non-login records until a dedicated partner account flow is built.

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
- User `plan` (`free` \| `premium`) lives on the **user**. The shipped MVP did not enforce plan gates. The production backend now requires Premium for Family creation/Primary Owner management; invited family members retain their granted access without their own Premium plan. Billing remains out of scope.
- Partner rows (`workshop` \| `insurer`) are CRM records. `verified` does not issue tokens or unlock booking/claims.
- Family authorization uses `family_memberships.role` + `vehicle_grants`. See `architecture/iam-family.md`.
- Sync outbox and `change_log` are bound to `user_id`. After logout, another account on the same device must not push the previous outbox.

Audiences in env: `JWT_OWNER_AUD=dco-owner`, `JWT_FLEET_AUD=dco-fleet`, `JWT_WORKSHOP_AUD=dco-workshop`, `JWT_ADMIN_AUD=dco-admin`. See `docs/environment-secrets.md`.

---

## B2B extension

These personas exist in `docs/vision.md` and `docs/personas.md`. They are **not** Phase 1 products. When they land, introduce organizations as a **new** root — do not migrate every owner into a 1-person org as a prerequisite for the first family share.

| Persona | Tenant | JWT `aud` | App | Status |
|---------|---------------|------------------|-----|--------|
| Fleet operator | org (`taxi_fleet`, `rental`, `commercial`) | `dco-fleet` on portal; `dco-owner` in Flutter | Fleet Portal + Flutter | Backend foundation implemented. Roles: `org_admin`, `org_manager`, `org_mechanic`, `org_driver`. |
| Dealership | org `type=dealership` or `showroom` | Same audiences as Fleet | Fleet-shaped portal + Flutter | Same access model as fleet, not a separate product. |
| Workshop staff | verified workshop partner | `dco-workshop` | Web Workshop Portal | Backend account link and active-warranty service logging implemented; portal and booking remain pending. |
| Insurance agent | partner tenant | `dco-insurer` | Web Insurance Portal | Not implemented. Policy/claims modules still out. |

Fleet and verified-workshop REST/auth/schema foundations are implemented. Fleet/Workshop Portal and Flutter Fleet surfaces, workshop booking, and insurer portals remain follow-up work.

### Fleet backend contract

1. `organizations` and `organization_members` are the Enterprise access root. Enterprise is `organizations.plan=enterprise`, not a user plan or `users.role`.
2. Keep Family `vehicle_grants` family-scoped. Fleet inventory is linked through `organization_vehicles`; `vehicles.user_id` remains the owner of record and changes to the buyer on transfer.
3. Mobile continues to use `dco-owner`; Fleet Dashboard uses `dco-fleet`; verified workshop accounts use `dco-workshop`. Insurers get a separate partner audience when claims are implemented. Do not reuse `dco-admin` for partners.
4. Change-log cursor stays per acting `user_id`; full offline Fleet sync remains to be completed.
5. Entra External ID remains an option for B2B tenants; current backend uses the existing email/password JWT flow.

### Implemented Backend Entitlements (Family + Fleet)

- Keep `users.plan` as `free` or `premium`; Premium remains DCO-admin-managed until billing is explicitly added.
- Resolve Family and Fleet as separate entitlements. Enterprise membership does not set or imply a user's Premium plan.
- Fleet access requires an Enterprise organization, organization `status=active`, and active membership; organization role authorizes the requested operation.
- Family creation and Primary Owner management require Premium. An invited user does not need Premium to join or use role/grant-scoped access.
- If the Primary Owner is downgraded from Premium, archive the family and revoke member access; retain personal user/vehicle data.
- `GET /v1/me/entitlements` provides navigation hints. Every protected API operation re-checks plan, membership, org status, and role server-side; mobile/portal navigation wiring remains pending.
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
