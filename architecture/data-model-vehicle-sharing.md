# Vehicle Sharing Data Model Extension

**Status:** Binding — merged into `architecture/data-model.md`; this file is the detailed schema reference.
**Contract:** `product/frd/vehicle-sharing-plan.md`, `product/frd/vehicle-sharing.md`
**Migration:** `backend/drizzle/0008_vehicle_sharing.sql` (idempotent; runs on every boot)
**Replaces:** `architecture/data-model-family.md`

There is **no family/group entity**. Access is granted per vehicle. A user may hold shares on
many vehicles owned by many different people, and may simultaneously be an owner and a sharee.

---

## New Tables

### vehicle_shares

The access ledger: one row per `(vehicle_id, user_id)`.

```sql
CREATE TYPE share_access AS ENUM ('view', 'add_edit_own');
CREATE TYPE share_status AS ENUM ('pending', 'active', 'revoked');

CREATE TABLE vehicle_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  granted_by uuid NOT NULL REFERENCES users(id),
  access_level share_access NOT NULL,
  status share_status NOT NULL DEFAULT 'active',
  invited_email text,
  share_code text UNIQUE,
  qr_code_data jsonb,          -- { code, vehicle_id, expires_at }
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_vehicle_user UNIQUE (vehicle_id, user_id)
);
```

### vehicle_share_invitations

The invite ledger. Separate from `vehicle_shares` because a Code/QR invite has **no addressee**
— there is no user to hang the row on until somebody scans or types the code.

```sql
CREATE TABLE vehicle_share_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  invited_email text,          -- null for code/QR invitations
  invited_by uuid NOT NULL REFERENCES users(id),
  access_level share_access NOT NULL DEFAULT 'view',
  token text NOT NULL UNIQUE,  -- random, 7-day expiry, used by the email deep link
  share_code text UNIQUE,      -- 8-char alphanumeric, 7-day expiry, used by Code/QR
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  accepted_by uuid REFERENCES users(id)
);
```

### driving_licenses (unchanged, but no longer family-adjacent)

Standalone per-user module (`backend/src/modules/licenses.ts`). It survived the family removal:
`GET /v1/users/:userId/license` authorises on "we hold a share on at least one vehicle in
common", not on a family relationship.

---

## Lifecycle

```
method: code_qr ─┐                                  ┌── POST /v1/vehicles/shares/join  {code}
                 ├─► vehicle_share_invitations ──────┤
method: email  ──┘      (accepted_at IS NULL)        └── POST /v1/vehicles/shares/accept {token}
                                     │
                                     ▼
                          vehicle_shares.status = active
                                     │
        owner DELETE /v1/vehicles/:id/shares/:shareId
                                     │
                                     ▼
                       row deleted + change_log "delete" fanned out
```

- **Create** (`POST /v1/vehicles/:id/shares`): `method: "email"` requires `email`, stores a
  `token`, mails `dco://vehicle/share/accept?token=…`; if the invitee already has an account a
  placeholder `vehicle_shares` row is inserted with `status='pending'`. `method: "code_qr"`
  deletes any outstanding code invite (rotating the code) and stores `share_code`.
- **Accept / Join**: sets `status='active'`, `accepted_at`, stamps `invited_email`; marks the
  invitation `accepted_at`/`accepted_by`; records the `vehicle` and `vehicle_share` upserts plus
  `seedVehicleHistory()` in the joiner's change log.
- **Resend** (`POST /v1/vehicles/:id/invitations/:inviteId/resend`): rotates `token` and
  `expires_at`, re-mails. The old link stops working.
- **Cancel** (`DELETE /v1/vehicles/:id/invitations/:inviteId`): deletes the invitation and any
  `status='pending'` placeholder share for the same email.
- **Revoke** (`DELETE /v1/vehicles/:id/shares/:shareId`): deletes the share, deletes pending
  invitations for the same email, writes a `vehicle_share` delete change to both parties.

`status='revoked'` exists in the enum but is never written — revocation deletes the row, so
`active_shares` counts stay simple.

---

## Plan Limits

`SHARE_LIMITS` in `backend/src/modules/vehicle-shares.ts` (mirrored in `backend/src/lib/me.ts`
and `backend/src/lib/entitlements.ts`):

| Plan | Active shares per vehicle | Active shares total |
|------|---------------------------|---------------------|
| `free` | 1 | 3 |
| `premium` | 5 | 20 |

`checkShareLimits(db, ownerId, vehicleId)` runs on **create** and on **accept/join** (never on
resend/cancel/revoke). Errors are `403 share_limit_reached`.

---

## Access Control Matrix

Runtime resolver: `getVehicleAccessLevel(db, userId, vehicleId)` →
`'owner' | 'view' | 'add_edit_own' | null`. Vehicles linked to `organization_vehicles` always
return `null` (Fleet vehicles are not shareable through this path).

| Action | Owner | `add_edit_own` | `view` | No access |
|--------|:-----:|:--------------:|:------:|:---------:|
| `GET /v1/vehicles` (own garage) | ✓ | — | — | — |
| `GET /v1/vehicles/shared` | — | ✓ | ✓ | ✗ |
| `GET /v1/vehicles/:id` | ✓ | ✓ | ✓ | ✗ |
| `GET /v1/vehicles/:id/detail` | ✓ | ✓ | ✓ | ✗ |
| `GET /v1/vehicles/:id/dashboard` | ✓ | ✓ | ✓ | ✗ |
| `PATCH /v1/vehicles/:id`, `/archive` | ✓ | ✗ | ✗ | ✗ |
| `POST /v1/vehicles/:id/activate` (set active) | ✓ | ✓ | ✓ | ✗ |
| View plan items, suggested items | ✓ | ✓ | ✓ | ✗ |
| Create / edit / delete plan items | ✓ | ✗ | ✗ | ✗ |
| View service records, parts, expenses + summary, fuel logs, documents | ✓ | ✓ | ✓ | ✗ |
| Create service records, parts, expenses, fuel logs, documents | ✓ | ✓ | ✗ | ✗ |
| Edit / delete a row you created | ✓ | ✓ | ✗ | ✗ |
| Edit / delete a row someone else created | ✓ | ✗ | ✗ | ✗ |
| Advance mileage (service or fuel odometer, monotonic) | ✓ | ✓ | ✗ | ✗ |
| Manage shares (list/create/patch/revoke/resend/cancel) | ✓ | ✗ | ✗ | ✗ |
| View another user's driving license | ✓ | ✓ | ✓ | ✗ |
| Fuel types / notifications / profile / sync | own rows only, regardless of sharing | | | |

Route guards funnel through `getAccessibleVehicle(db, caller, vehicleId, "full" | "drive_only")`
(`backend/src/modules/vehicles.ts`), which maps `"full"` → `add_edit_own` and `"drive_only"` →
`view`. Reads of vehicles, detail, dashboard, and every record type use `"drive_only"`; writes use
`"full"`, except plan-item and share management routes which call `getOwnedVehicle` (owner only).

Record writes by id go through the author-scoped loaders (`loadServiceRecordFor`, `loadExpenseFor`,
`loadPartFor`, `loadDocumentFor`, `loadPlanItemFor`, `loadFuelLogFor` …`"write"`): the caller must
be the row's `created_by` (`fuel_logs.user_id` for fuel logs) or the vehicle owner. A `view` sharee
fails every write, and an `add_edit_own` sharee can only write rows they authored. Mileage advances
additionally require the posted odometer to exceed the vehicle's current mileage, so shared writes
can never move it backwards.

---

## Sync Entities (Mobile Offline)

| Entity type | Local table | Server source | Notes |
|-------------|-------------|---------------|-------|
| `vehicle_share` | `vehicle_shares_local` | `change_log` upsert/delete | Server-authoritative; never pushed |
| `vehicle` | `vehicles_local` | `change_log` upsert | Same row the owner has; mobile marks `source='shared'` |
| `vehicle_share_invitations` | — | not synced | Owner-only surface, fetched over REST |
| `driving_license` | local | REST | Own license only |

`mobile/lib/core/sync/change_applier.dart` `_applyVehicleShare`:

- `op: delete` → drop the share row, and if the change is for **me**, drop the local vehicle row
  too — but only when `vehicles.source == 'shared'`, so a vehicle I own is never deleted by a
  revoke.
- `op: upsert` → upsert the share row; when `status='active'` and it is my share, stamp the
  vehicle row `source='shared'` and `permission=<access_level>`.

`OutboxEntityType.vehicleShare` exists only so the applier can route pulled changes; the mobile
never enqueues a share for push (`/v1/sync/push` accepts no share entity types).

**Change audience / history seeding.** `getVehicleChangeAudience` = owner ∪ users with an active
share. `fanOutVehicleChange` writes a change under each of them (used by `owner.ts` and
`vehicles.ts` writes). `seedVehicleHistory` replays `plan_item`, `service_record`, `part`,
`fuel_log`, `document`, and `expense` into the joiner's log at accept/join time so a shared
vehicle arrives with its full history.

---

## Query Patterns

### My shares on a vehicle (owner's management screen)

```sql
SELECT s.*, u.display_name, u.email
FROM vehicle_shares s
JOIN users u ON u.id = s.user_id
WHERE s.vehicle_id = $1
ORDER BY s.created_at;
```

### Outstanding invitations for a vehicle

```sql
SELECT * FROM vehicle_share_invitations
WHERE vehicle_id = $1 AND accepted_at IS NULL
ORDER BY created_at;
```

### The current code/QR invite (read back on a later visit)

```sql
SELECT share_code, expires_at FROM vehicle_share_invitations
WHERE vehicle_id = $1 AND accepted_at IS NULL AND share_code IS NOT NULL
LIMIT 1;
```

### Access level for an authorization check

```sql
SELECT CASE
  WHEN v.user_id = $1 THEN 'owner'
  ELSE s.access_level
END AS access_level
FROM vehicles v
LEFT JOIN vehicle_shares s
       ON s.vehicle_id = v.id AND s.user_id = $1 AND s.status = 'active'
WHERE v.id = $2
  AND NOT EXISTS (SELECT 1 FROM organization_vehicles ov WHERE ov.vehicle_id = v.id);
```

### Limit check (per vehicle, then total)

```sql
SELECT count(*) FROM vehicle_shares s JOIN vehicles v ON v.id = s.vehicle_id
WHERE v.user_id = $1 AND s.vehicle_id = $2 AND s.status = 'active';

SELECT count(*) FROM vehicle_shares s JOIN vehicles v ON v.id = s.vehicle_id
WHERE v.user_id = $1 AND s.status = 'active';
```

### Vehicles shared with me

```sql
SELECT v.*, s.access_level, v.user_id AS owner_id
FROM vehicle_shares s
JOIN vehicles v ON v.id = s.vehicle_id
WHERE s.user_id = $1 AND s.status = 'active' AND v.archived = false;
```

---

## Migration (`0008_vehicle_sharing.sql`)

Every statement is idempotent because `applyInitSql()` replays all files on each boot:

1. `CREATE TYPE` wrapped in `DO … EXCEPTION WHEN duplicate_object` blocks.
2. `CREATE TABLE IF NOT EXISTS` for both tables.
3. Legacy `vehicle_grants` → `vehicle_shares`, mapping `permission: 'full'` → `add_edit_own`,
   anything else → `view`; `accepted_at = created_at`.
4. Legacy `family_vehicles ⨝ family_memberships` → `vehicle_shares`, skipping the vehicle owner
   (`fm.user_id <> v.user_id`), mapping `driver` → `view` and `member`/`primary_owner` →
   `add_edit_own`; `accepted_at = fm.joined_at`.
5. `DROP TABLE IF EXISTS` on `vehicle_grants`, `family_vehicles`, `family_memberships`,
   `families`; `ALTER TABLE users DROP COLUMN IF EXISTS family_id`;
   `ALTER TABLE refresh_tokens ALTER COLUMN family_id DROP NOT NULL` (existing sessions survive);
   `DROP TYPE IF EXISTS` on the old enums.
6. `driving_licenses` is **not** dropped.

Guards: `backend/test/migrations.test.ts` replays the whole chain twice on one database;
`backend/test/family-migration.test.ts` seeds legacy family/grant rows before step 4 and asserts
the converted shares, the dropped tables/columns, and the nullable `refresh_tokens.family_id`.

Rollback: the pre-migration tables are gone by then — restore from backup rather than reversing
the file.
