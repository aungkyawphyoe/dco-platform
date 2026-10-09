# Identity and Access — Vehicle Sharing Extension

**Status:** Accepted — extends `architecture/iam.md`
**Contract:** `product/frd/vehicle-sharing.md`, `architecture/data-model-vehicle-sharing.md`
**Principle:** Additive. MVP IAM (`owner` | `admin`) is unchanged. Share authority lives in
`vehicle_shares.access_level`, never in `users.role`.
**Replaces:** `architecture/iam-family.md`

---

## Extended IAM Taxonomy

### Principal Types

| Principal | Surface | JWT `aud` | `users.role` | Share | What they can do |
|-----------|---------|-----------|--------------|-------|------------------|
| Vehicle owner | Flutter + Web | `dco-owner` | `owner` | — (they hold `vehicles.user_id`) | Own garage + share management on their vehicles + web shares page |
| Vehicle sharee (`add_edit_own`) | Flutter | `dco-owner` | `owner` | `vehicle_shares.access_level = add_edit_own` | Read the shared vehicle; create service/expense/part/document/fuel rows and edit or delete only rows they created; no plan, vehicle identity, or share management |
| Vehicle sharee (`view`) | Flutter | `dco-owner` | `owner` | `vehicle_shares.access_level = view` | Read the shared vehicle (read-only — every write is rejected) |
| Platform Admin | Web admin | `dco-admin` | `admin` | — | `/v1/admin/*` only (unchanged) |

There is no "primary owner", "member", "driver", or household role. Every participant is an
`owner` account; the only thing that differs is which `vehicle_shares` rows point at them.

### Key Design Decisions

1. **`users.role` stays `owner`** for everyone. Sharing is a row on a vehicle, not a role.
2. **Same JWT audience (`dco-owner`)** — no share claims in the token. Access is resolved from
   the database on every request, so revocation is immediate and needs no token refresh.
3. **No group entity.** A user can hold shares from many owners and own vehicles at the same
   time; there is nothing to create before sharing and nothing to dissolve after.
4. **Share limits are entitlements, not permissions.** `users.plan` only sizes
   `shareLimits` (`backend/src/lib/plans.ts`: free 1, lite 3, standard/fleet unlimited — one
   cap for both per-vehicle and total). All plans can share and accept; downgrading revokes
   shares above the new caps (oldest kept).
5. **Owner-only management.** Creating, editing, revoking, resending, and cancelling shares
   requires `vehicle.userId === caller`. Sharees never see another sharee's identity beyond
   what the shared vehicle itself exposes.
6. **Fleet vehicles are excluded.** `getVehicleAccessLevel` returns `null` for any vehicle
   linked through `organization_vehicles`, so Fleet inventory cannot be shared through the
   personal path.
7. **Email invitations are addressed; codes are not.** `vehicle_share_invitations.invited_email`
   is `null` for Code/QR invites, which is why the invite ledger is separate from the access
   ledger.

---

## Authorization Model

### Vehicle Access Check (Runtime)

```typescript
// backend/src/modules/vehicle-shares.ts
export async function getVehicleAccessLevel(
  db: Db, userId: string, vehicleId: string,
): Promise<"owner" | "view" | "add_edit_own" | null> {
  const [vehicle] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle) return null;
  const [organizationLink] = await db.select().from(organizationVehicles)
    .where(eq(organizationVehicles.vehicleId, vehicleId)).limit(1);
  if (organizationLink) return null;               // Fleet vehicles are not shareable here
  if (vehicle.userId === userId) return "owner";
  const [share] = await db.select().from(vehicleShares).where(and(
    eq(vehicleShares.vehicleId, vehicleId),
    eq(vehicleShares.userId, userId),
    eq(vehicleShares.status, "active"),
  )).limit(1);
  return share?.accessLevel ?? null;
}
```

`requireVehicleAccess(db, userId, vehicleId, requiredLevel)` wraps it and throws
`403 no_vehicle_access` / `403 insufficient_permission`.

Route guards normally go through
`getAccessibleVehicle(db, caller, vehicleId, "full" | "drive_only", includeArchived?)`, which
maps `"full"` → `add_edit_own` and `"drive_only"` → `view`, and 404s when the vehicle does not
exist, is archived (unless allowed), or is linked to an organization.

### Permission Gates

| Endpoint category | Required | Check |
|-------------------|----------|-------|
| `GET /v1/vehicles` | own rows only | `vehicles.userId === caller` |
| `GET /v1/vehicles/shared` | any active share | self |
| `GET /v1/vehicles/:id`, `/dashboard`, `/warranty` | any access | `getAccessibleVehicle(..., "drive_only")` |
| `GET /v1/vehicles/:id/detail` | any access | `getVehicleSharesDetail` (share roster stays owner-only) |
| `PATCH /v1/vehicles/:id`, `/archive` | `owner` | `getOwnedVehicle` |
| `POST /v1/vehicles/:id/activate` | any access | `getVehicleAccessLevel` |
| Reads of plan items, suggested items, service records, parts, expenses + summary, fuel logs, documents | `view` | `getAccessibleVehicle(..., "drive_only")` |
| Create service records, parts, expenses, fuel logs, documents | `add_edit_own` | `getAccessibleVehicle(..., "full")` |
| Edit / delete plan items | `owner` | `getOwnedVehicle` (create) / `loadPlanItemFor(..., "write")` |
| Edit / delete service records, parts, expenses, documents | owner or row author | `loadServiceRecordFor` / `loadPartFor` / `loadExpenseFor` / `loadDocumentFor` (`... "write"`) |
| Edit / delete fuel logs | owner or row author (`fuel_logs.user_id`) | `loadFuelLogFor(..., "write")` — denied outright at `view` |
| Advance mileage (service or fuel odometer) | owner or `add_edit_own`, monotonic only | body `odometer > vehicle.mileage` checked in the write path |
| `POST/PATCH/DELETE /v1/vehicles/:id/shares…`, `/invitations…` | `owner` | inline `vehicles.userId === caller` → `403 not_vehicle_owner` |
| `POST /v1/vehicles/shares/accept|join|decline` | any authenticated owner | self; owner-of-vehicle → `409 owner_cannot_join` |
| `GET /v1/users/:userId/license` | share overlap | `sharesVehicleWith` → `403 not_shared` |
| `GET /v1/users/:userId/detail` | share overlap | `getUserDetail` → `403 not_shared` |
| `/v1/admin/*` | `role=admin` + `dco-admin` | `requireAdmin` (unchanged) |

### Share Management Errors

| Code | Status | Meaning |
|------|--------|---------|
| `not_vehicle_owner` | 403 | Caller does not own the vehicle |
| `share_not_found` / `invitation_not_found` | 404 | Wrong id or wrong vehicle |
| `already_shared` | 409 | Invitee already holds a share on this vehicle |
| `already_accepted` / `already_responded` | 409 | Invitation consumed |
| `share_limit_reached` | 403 | Over `SHARE_LIMITS` per-vehicle or total cap |
| `owner_cannot_join` | 409 | You already own this vehicle |
| `email_mismatch` | 403 | Signed-in account is not the invited email |
| `share_code_not_found` | 404 | Unknown code |
| `share_code_expired` / `invitation_expired` | 410 | Past `expires_at` |

---

## JWT Claims

### Access Token (dco-owner)

```json
{
  "sub": "user-uuid",
  "role": "owner",
  "plan": "free|lite|standard|fleet",
  "aud": "dco-owner",
  "iat": 1234567890,
  "exp": 1234567890
}
```

No `family_id`, no `family_role`, no share claims. `plan` is a hint for UI; limits are
re-computed server-side. Revoking a share takes effect on the next request because
`getVehicleAccessLevel` reads the database.

### Refresh Token

Unchanged — `refresh_tokens.family_id` remains, but only as the **refresh-token family** used for
revoke-all-on-reset. It no longer references a user-facing family (made nullable in `0008` so
existing sessions survive).

---

## Web Route Guards

| Route | Guard | Notes |
|-------|-------|-------|
| `/login` | Public | Accepts admin + owner credentials; redirects by role |
| `/` , `/users/*`, `/partners/*`, `/organizations/*`, `/catalog` | `role=admin` | Admin JWT only |
| `/vehicles` | `role=owner` | Owned + shared vehicle tables |
| `/vehicles/[id]/shares` | `role=owner` | Share management; server-side re-checks `vehicle.userId` |

Middleware maps owner paths (`/vehicles`, legacy `/family` redirect) to the owner surface; the
BFF `/api/auth/session` route returns `role` and the client redirects non-owners away.

---

## Mobile Route Guards

```dart
// All authenticated routes require role == owner.
// Sharing is data, not a route: no FamilyFeature-style capability enum.
enum ShareScreen { shareVehicle, manageShares, acceptInvite, joinByCode, sharedWithMe }

// Vehicle access for the UI is read from the local share/vehicle rows, which the
// change log keeps current; the server still re-checks on every request.
final access = ref.watch(vehicleAccessProvider(vehicleId)); // owner | view | add_edit_own | null
```

GoRouter paths (no native deep-link plugin — approved decision):

| Path | Screen |
|------|--------|
| `/shares/shared-with-me` | Shared with Me list |
| `/shares/join` (`?code=`) | Join by code, with preview |
| `/shares/accept` (`?token=`) | Accept / decline email invitation |
| `/vehicles/:id/shares` | Owner share management |
| `/vehicles/:id/shares/new` | Invite by email or show Code/QR |

Deep links emitted by the backend: `dco://vehicle/share/join?code=…` and
`dco://vehicle/share/accept?token=…`.

---

## Share Lifecycle & Token Updates

| Event | Effect on access |
|-------|------------------|
| Owner creates email invite | `vehicle_share_invitations` row; no access yet |
| Owner creates code/QR invite | Outstanding code invite replaced; no access yet |
| Invitee accepts / joins | `vehicle_shares.status=active`, `accepted_at` set, history seeded into their change log |
| Owner changes `access_level` | `vehicle_shares.access_level` updated; `vehicle_share` upsert written for the owner |
| Owner revokes | Share + pending invite deleted; `vehicle_share` delete written to both parties |
| Owner cancels an invitation | Invitation + placeholder `pending` share deleted |
| Invitee declines | Invitation deleted; their `pending` share deleted |
| User deactivated by admin | Shares where they are the grantee **and** on their own vehicles are deleted; their vehicles archived |
| Owner downgraded to free | No access change; new shares refused while over the caps |

No token rotation is needed anywhere in this table.

---

## Admin Support View (Read-Only)

- `GET /v1/admin/users/:userId` returns `vehicle_sharing.active_shares` — the number of active
  shares **on the user's own vehicles** (people they shared with).
- `POST /v1/admin/users/:userId/delete` deletes shares where `user_id = <target>` (access they
  held on other people's vehicles) and, per owned vehicle, shares where `vehicle_id = <their
  vehicle>`; archives their vehicles; deactivates the account; revokes refresh tokens.
- There is no `/v1/admin/families` route and no family list to expose.

---

## Security Considerations

1. **Share code entropy**: 8-char alphanumeric (62⁸ ≈ 2.18 × 10¹⁴); 7-day expiry; codes are
   rotated on regenerate so an old QR stops working.
2. **QR payload**: `{ code, vehicle_id, expires_at }` — no secrets, no tokens.
3. **Invite tokens**: `randomToken()`, unique, 7-day expiry; rotated on resend so the previous
   link is dead.
4. **Access is server-side**: no client-side trust; every vehicle-scoped route resolves
   `getVehicleAccessLevel` or `getOwnedVehicle`.
5. **License images** ride the existing media pipeline (signed download URLs, no public blob).
6. **No share claims in JWT**: revocation cannot be outlived by a stale token.
7. **One row per (vehicle, user)**: enforced by `unique_vehicle_user`, so accepting twice or
   joining twice cannot double-grant.
8. **Placeholders are `status='pending'`**: an email invited but not yet accepted has no access;
   `getVehicleAccessLevel` only matches `active`.
9. **Limits re-checked on accept/join**: the caps cannot be bypassed by accepting an old invite
   after the owner fell under the limit.
10. **Org-linked vehicles are invisible to this path**: `getVehicleAccessLevel` returns `null`.

---

## Migration from the Family Model

| Family (removed) | Vehicle Sharing (current) |
|------------------|---------------------------|
| `families` | — (no group entity) |
| `family_memberships.role` | `vehicle_shares.access_level` |
| `vehicle_grants.permission` (`full`/`drive_only`) | `vehicle_shares.access_level` (`add_edit_own`/`view`) |
| `users.family_id` | dropped |
| `family_status` / `family_role` / `grant_permission` enums | `share_status` / `share_access` |
| `primary_owner` → owns the family | is simply `vehicles.user_id` |
| `member` → `add_edit_own` on family vehicles | `member` → `add_edit_own` |
| `driver` → `view` + fuel | `view` (now read-only; fuel writes moved to `add_edit_own`) |
| Share code on `families.share_code` | Share code on `vehicle_share_invitations.share_code` |
| Family-scoped sync entities | `vehicle_share` entity; audience = owner ∪ active shares |

Conversion lives in `backend/drizzle/0008_vehicle_sharing.sql` and is verified by
`backend/test/family-migration.test.ts`.

---

## Fleet/Org Relationship

| Concept | Vehicle Sharing | Fleet |
|---------|-----------------|-------|
| Root entity | `vehicles.user_id` (no group) | `organizations` |
| Membership | `vehicle_shares` | `organization_members` |
| Roles | `view` / `add_edit_own` | `org_admin` / `org_manager` / `org_mechanic` / `org_driver` |
| Vehicle link | same `vehicles` row | `organization_vehicles` |
| JWT audience | `dco-owner` | `dco-fleet` (portal) |

A vehicle is in **exactly one** world: once linked through `organization_vehicles` it drops out
of personal sharing (`getVehicleAccessLevel` → `null`, `getOwnedVehicle` → 404). Do not migrate
organizations into shares or vice versa.
