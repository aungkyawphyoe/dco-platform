# Vehicle Sharing — Migration Plan from Family Sharing

**Status:** Planning  
**Source FRD:** `product/frd/family-sharing.md` (archived → `product/frd/archive/family-sharing.md`)  
**Result FRD:** `product/frd/vehicle-sharing.md`  
**Reference:** [Autozis Vehicle Sharing](https://autozis.com/vehicle-sharing)  
**Target:** Replace Family Sharing with Vehicle Sharing (per-vehicle, Code/QR + email invitations, no family group)

---

## 1. Executive Summary

### Current State (Family Sharing)
- **Model:** Family group with share code/QR; Primary Owner creates family, invites Members/Drivers
- **Scope:** One family per user; Premium required for Primary Owner
- **Sharing:** All vehicles in family shared with all members via `family_vehicles` + `vehicle_grants`
- **Roles:** `primary_owner`, `member`, `driver` (family-scoped)
- **Web:** Read-only family dashboard for Primary Owner

### Target State (Vehicle Sharing)
- **Model:** Per-vehicle sharing with **Code/QR and email invitations**; no family group entity
- **Scope:** Vehicle owner shares individual vehicles with any user (friend, family, caregiver, team)
- **Sharing:** Granular per-vehicle grants; owner controls permissions per share
- **Roles:** `owner` (implicit), `shared_user` (granted) — permissions: `view`, `add_edit_own`
- **Privacy:** Owner records private; shared user records private; AI chats private
- **Limits:** Plan-based active share limits (free 1, lite 3, standard/fleet unlimited)
- **Management Screen:** Per-vehicle share management screen for owner (view active/pending shares, change access, revoke)

---

## 2. Conceptual Shifts

| Aspect | Family Sharing (Current) | Vehicle Sharing (Target) |
|--------|--------------------------|--------------------------|
| **Core Entity** | `families` (group) | None — vehicle-centric |
| **Invitation** | Share code/QR (family-level) | **Code/QR + Email (vehicle-level)** |
| **Acceptance** | Join family → auto-grant all family vehicles | Accept invite (code/link/email) → grant for specific vehicle |
| **Permissions** | Role-based (family-scoped) | Grant-based (vehicle-scoped) |
| **Ownership** | Family owns vehicles | Vehicle owner retains full control |
| **Records** | Shared history per vehicle | Shared history per vehicle (owner records protected) |
| **Insurance/Maintenance** | Family-scoped | Owner-only management |
| **AI Chats** | Not specified | Private per user |
| **Plan Gating** | Premium for Primary Owner | Plan-based share limits |
| **Management UI** | Family Management screen | **Per-vehicle Share Management screen** |

---

## 3. Database Schema Changes

### Tables to Remove
```sql
DROP TABLE family_vehicles;       -- Vehicle-to-family link
DROP TABLE family_memberships;    -- User-to-family membership
DROP TABLE families;              -- Family group entity
DROP TABLE driving_licenses;      -- Replaced by user profile or removed (out of scope for sharing)
```

### Tables to Modify
```sql
-- vehicle_grants: rename and extend
ALTER TABLE vehicle_grants RENAME TO vehicle_shares;
ALTER TABLE vehicle_shares 
  RENAME COLUMN permission TO access_level;  -- 'view' | 'add_edit_own'
ALTER TABLE vehicle_shares 
  ADD COLUMN status share_status_enum DEFAULT 'pending';  -- 'pending' | 'active' | 'revoked'
ALTER TABLE vehicle_shares 
  ADD COLUMN invited_email text;  -- for pending email invites
ALTER TABLE vehicle_shares 
  ADD COLUMN share_code text UNIQUE;  -- 8-char alphanumeric for code/QR sharing
ALTER TABLE vehicle_shares 
  ADD COLUMN qr_code_data jsonb;  -- { code, vehicle_id, expires_at }
ALTER TABLE vehicle_shares 
  ADD COLUMN accepted_at timestamp with time zone;
```

### New Enum
```sql
CREATE TYPE share_status_enum AS ENUM ('pending', 'active', 'revoked');
CREATE TYPE share_access_enum AS ENUM ('view', 'add_edit_own');
```

### Users Table
```sql
-- Remove family_id (no longer needed)
ALTER TABLE users DROP COLUMN family_id;
```

### New: Share Invitations (for email-based flow)
```sql
CREATE TABLE vehicle_share_invitations (
  id uuid PRIMARY KEY,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  invited_email text,  -- nullable for code/QR shares
  invited_by uuid NOT NULL REFERENCES users(id),
  access_level share_access_enum NOT NULL DEFAULT 'view',
  token text NOT NULL UNIQUE,  -- secure token for acceptance (email flow)
  share_code text UNIQUE,  -- 8-char code for code/QR flow
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  accepted_at timestamp with time zone,
  accepted_by uuid REFERENCES users(id)
);
```

**Note:** For Code/QR sharing, `invited_email` is null and `share_code` is used. For email invitations, `invited_email` is set and `token` is used for acceptance.

---

## 4. API Endpoint Changes (v1)

### Remove (Family Endpoints)
| Method | Path | Replacement |
|--------|------|-------------|
| POST | `/v1/families` | — |
| GET | `/v1/families/me` | GET `/v1/vehicles/:id/shares` |
| GET | `/v1/families/:code` | — |
| POST | `/v1/families/:id/join` | POST `/v1/vehicles/:id/shares/accept` |
| PATCH | `/v1/families/:id` | — |
| DELETE | `/v1/families/:id` | — |
| GET | `/v1/families/:id/members` | GET `/v1/vehicles/:id/shares` |
| PATCH | `/v1/families/:id/members/:userId` | PATCH `/v1/vehicles/:id/shares/:shareId` |
| DELETE | `/v1/families/:id/members/:userId` | DELETE `/v1/vehicles/:id/shares/:shareId` |
| POST | `/v1/families/:id/vehicle-grants` | POST `/v1/vehicles/:id/shares` |
| DELETE | `/v1/families/:id/vehicle-grants/:grantId` | DELETE `/v1/vehicles/:id/shares/:shareId` |
| GET | `/v1/families/me/vehicles` | GET `/v1/vehicles?shared=true` |
| POST | `/v1/families/me/vehicles` | POST `/v1/vehicles/:id/shares` (invite) |
| DELETE | `/v1/families/me/vehicles/:vehicleId` | DELETE `/v1/vehicles/:id/shares/:shareId` (revoke) |

### New Vehicle Share Endpoints
| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/vehicles/:id/shares` | `dco-owner` | Create share (email invite OR generate code/QR) |
| GET | `/v1/vehicles/:id/shares` | `dco-owner` | List active/pending shares for vehicle (owner only) |
| PATCH | `/v1/vehicles/:id/shares/:shareId` | `dco-owner` | Update access level, regenerate code/QR, or resend invite (owner only) |
| DELETE | `/v1/vehicles/:id/shares/:shareId` | `dco-owner` | Revoke share (owner only) |
| GET | `/v1/vehicles/shared` | `dco-owner` | List vehicles shared with me (accepted) |
| POST | `/v1/vehicles/shares/accept` | `dco-owner` | Accept share invitation by token (email) |
| POST | `/v1/vehicles/shares/join` | `dco-owner` | Join vehicle share by code (Code/QR flow) |
| POST | `/v1/vehicles/shares/decline` | `dco-owner` | Decline share invitation by token |

### License Endpoints (simplify or remove)
| Method | Path | Decision |
|--------|------|----------|
| GET | `/v1/users/me/license` | Remove or move to profile |
| PUT | `/v1/users/me/license` | Remove or move to profile |
| POST | `/v1/users/me/license/media` | Remove or move to profile |
| GET | `/v1/users/:id/license` | Remove (not needed for vehicle sharing) |

---

## 5. Backend Implementation Changes

### 5.1 New Module: `vehicle-shares.ts`

```typescript
// Core functions
async function createShare(db, vehicleId, ownerId, options: { email?: string; accessLevel: 'view' | 'add_edit_own'; method: 'email' | 'code_qr' })
async function listShares(db, vehicleId, ownerId)
async function updateShare(db, vehicleId, shareId, ownerId, updates: { accessLevel?; regenerateCode?: boolean; resendInvite?: boolean })
async function revokeShare(db, vehicleId, shareId, ownerId)
async function acceptShareByToken(db, userId, token)  // email flow
async function joinShareByCode(db, userId, code)      // code/QR flow
async function declineShare(db, userId, token)
async function getSharedVehicles(db, userId)
async function getVehicleAccessLevel(db, userId, vehicleId)  // returns 'owner' | 'view' | 'add_edit_own' | null
async function requireVehicleAccess(db, userId, vehicleId, requiredLevel)
async function regenerateShareCode(db, vehicleId, shareId, ownerId)
```

### 5.2 Authorization Rules

| Action | Required |
|--------|----------|
| Create share | Vehicle owner + plan allows shares |
| List shares | Vehicle owner |
| Update share | Vehicle owner |
| Revoke share | Vehicle owner |
| Accept invite | Valid token + user not already shared |
| View shared vehicle | Active share with `view` or `add_edit_own` |
| Add/edit own records | Active share with `add_edit_own` |
| Delete vehicle | Owner only |
| Manage insurance/maintenance | Owner only |
| View AI chats | Never shared |

### 5.3 Plan-Based Limits
- **Free:** 1 active share per vehicle, 3 total active shares
- **Premium:** 5 active shares per vehicle, 20 total active shares
- **Enterprise:** Unlimited (handled via organization)

### 5.4 Sync & Change Log
- Share creation/acceptance/revocation → fan-out to relevant users
- `seedVehicleHistory` on share acceptance (replay existing records to new user)
- Fan-out vehicle changes to: owner + all active shares

### 5.5 Record Ownership
- Every record (service, fuel, expense, document, part) has `created_by` (user_id)
- Shared users can only edit/delete their own records
- Owner can edit/delete any record on their vehicle
- Mileage updates: `max(local, remote)` wins (existing rule)

---

## 6. Mobile App Changes (Flutter)

### 6.1 Navigation & Entry Points
| Current | New |
|---------|-----|
| Hamburger → Family | Garage → Vehicle Card → "Share" action |
| Family Management screen | Vehicle Share Management (per vehicle) |
| Family Setup screen | Share Invite screen (per vehicle) |
| Car Detail → Assigned Drivers | Car Detail → Shared Users |

### 6.2 New Screens

#### Share Vehicle Screen (from Vehicle Card menu)
- Entry: Garage → Vehicle card menu → "Share Vehicle"
- **Two tabs/modes: "Invite by Email" and "Share via Code/QR"**
- **Email tab:** Input email address, access level (View / Add & Edit Own), send invitation
- **Code/QR tab:** Display share code (copy button), QR code (share sheet), "Regenerate Code" button
- Both methods create a pending share with selected access level

#### Share Management Screen (per vehicle) — **Owner's sharing information screen**
- Entry: Car Detail → "Shared Users" section → "Manage Shares" (owner only)
- **Tabs: Active Shares / Pending Invites / Code & QR**
- **Active Shares:** List shared users with name, email, access level badge, joined date, actions: "Change Access" / "Revoke"
- **Pending Invites:** List pending email invites with email, access level, expires date, actions: "Resend" / "Cancel"
- **Code & QR:** Display current share code, QR code, "Regenerate Code" (invalidates old code), "Share" sheet
- Header shows: Vehicle nickname, plate, total active shares / plan limit

#### Accept Invite Screen (Email Flow)
- Deep link: `dco://vehicle/share/accept?token=xxx`
- Shows: Vehicle nickname, plate, owner name, access level
- Actions: Accept / Decline

#### Join by Code Screen (Code/QR Flow)
- Deep link: `dco://vehicle/share/join?code=XXXXXXXX` or manual entry
- Entry: Hamburger menu → "Join Vehicle Share" (if no active vehicle shares) or Garage → "Shared with Me" → "Join with Code"
- Input: 8-character share code (auto-uppercase)
- Shows: Vehicle nickname, plate, owner name, access level
- Actions: Join / Cancel

#### Shared Vehicles List
- Entry: Garage → "Shared with Me" filter/chip
- Shows: Vehicles shared with current user, owner name, access level

### 6.3 Modified Screens

#### Garage Home
- Add "Shared with Me" filter/chip alongside "My Vehicles"
- Vehicle card shows share indicator (icon) if shared
- Vehicle card menu: "Share Vehicle" (owner only)

#### Car Detail
- Replace "Assigned Drivers" section with "Shared Users"
- Show: Shared user name, access level badge, license status (optional)
- Owner: "Manage Shares" button → Share Management Screen
- Shared user: No management actions

#### Dashboard
- Active vehicle picker includes shared vehicles
- Quick actions respect access level (e.g., "Log Service" only for `add_edit_own`)

#### Settings
- Remove "Family" section
- Add "Vehicle Sharing" section (plan limits, shared vehicles count)

### 6.4 Offline-First Considerations
- Pending shares stored locally, synced when online
- Accepted shares → local vehicle cache + history seed
- Revoked shares → local vehicle marked as no-longer-accessible
- Outbox for: create share, accept share, revoke share

### 6.5 Entitlements
```dart
// New entitlements shape
class VehicleShareEntitlements {
  final bool canShareVehicles;
  final int maxSharesPerVehicle;
  final int maxTotalShares;
  final int activeSharesCount;
}
```

---

## 7. Web Admin Changes (Next.js)

### 7.1 Family Dashboard → Vehicle Shares Dashboard
- **Remove:** `/family` read-only route
- **Add:** Vehicle shares management per vehicle (owner only)

### 7.2 New Route: `/vehicles/:id/shares`
- List active/pending shares for vehicle
- **Two sections: "Invite by Email" and "Share via Code/QR"**
- **Email:** Invite new user by email, access level, resend/cancel pending
- **Code/QR:** Display share code, QR code, regenerate code, copy/share
- Change access level for active shares
- Revoke share

### 7.3 Auth
- No change to BFF flow (`dco-owner` audience)
- Route guard: vehicle owner only

---

## 8. Migration Strategy

### Phase 1: Backend Schema & API (Week 1-2)
1. Create migration: drop family tables, create `vehicle_shares`, `vehicle_share_invitations`
2. Implement `vehicle-shares.ts` module with all endpoints
3. Update `getVehicleAccessLevel` and `requireVehicleAccess`
4. Update sync fan-out logic
5. Add plan-based limit checks
6. Write integration tests for all share flows

### Phase 2: Mobile App (Week 2-3)
1. Remove Family feature folder (`features/family/`)
2. Add Vehicle Sharing feature folder (`features/vehicle_sharing/`)
3. Implement Share Vehicle screen
4. Implement Share Management screen
5. Implement Accept Invite screen (deep link handling)
6. Update Garage, Car Detail, Dashboard, Settings
7. Update local Drift schema (drop family tables, add share tables)
8. Update sync engine for share entities
9. Update entitlements provider
10. Update localizations (replace "Family" with "Vehicle Sharing")

### Phase 3: Web Admin (Week 3)
1. Remove `/family` route
2. Add `/vehicles/:id/shares` route
3. Update BFF to include share data in vehicle detail
4. Test owner workflows

### Phase 4: Data Migration (Week 3-4)
1. Migration script: convert existing families → vehicle shares
   - For each family: for each family_vehicle → create shares for all members
   - Preserve access levels: `primary_owner` → owner, `member` → `add_edit_own`, `driver` → `view`
   - Mark shares as `active` with `accepted_at = joined_at`
2. Notify existing Primary Owners of migration
3. Verify data integrity

### Phase 5: Cleanup & Polish (Week 4)
1. Remove unused code (family-related)
2. Update FRD: create `vehicle-sharing.md`, archive `family-sharing.md`
3. Update `production-scope.md`
4. Update `mobile/AGENTS.md`
5. Update `architecture/openapi.yaml`
6. Update `architecture/data-model.md`
7. Update `architecture/iam.md`
8. E2E testing

---

## 9. Breaking Changes & Mitigations

| Breaking Change | Mitigation |
|-----------------|------------|
| Family group removed | Migrate existing families to per-vehicle shares |
| Family membership removed | Users can have multiple vehicle shares across owners |
| Driving license removed | Move to user profile or remove (not core to sharing) |
| Web family dashboard removed | Replace with vehicle share management |
| Premium gating: family creation → share limits | Communicate plan changes to users |

---

## 10. Open Questions

1. **Email delivery:** Use existing email service or new provider?
2. **Code/QR expiration:** 7 days (like current QR) or longer? Regeneration invalidates old code.
3. **Invite expiration (email):** 7 days or longer?
4. **Share limits enforcement:** Hard block or soft warning?
5. **Notification on share acceptance:** Push/local notification?
6. **Shared vehicle indicator:** Icon on Garage card? Badge?
7. **Bulk invite:** Allow inviting multiple emails at once?
8. **Shared user sees owner's documents?** Autozis says yes (view), but owner's private records protected
9. **Expense splitting?** Out of scope per Autozis, but consider for future
10. **Migration of driving licenses:** Keep in user profile or drop?
11. **Web admin family view for support:** Admin needs to see shares for support — add to admin API?
12. **Code collision handling:** 8-char alphanumeric = 2.8T combos; regenerate on collision?
13. **Offline code/QR generation:** Can owner generate code offline?

---

## 11. Success Metrics (Post-Launch)

- Vehicles shared per week
- Invite acceptance rate
- Active shares per vehicle (distribution)
- Shared user retention (30/90 days)
- Records added by shared users vs owner
- Support tickets related to sharing

---

## 12. File Changes Summary

### Backend
- `backend/src/db/schema.ts` — Drop family tables, add share tables
- `backend/src/db/migrate.ts` — Add migration
- `backend/src/modules/family.ts` → `backend/src/modules/vehicle-shares.ts` (rewrite)
- `backend/src/modules/auth.ts` — Remove family_id from JWT payload
- `backend/src/modules/me.ts` — Remove family from entitlements
- `backend/src/modules/profile.ts` — Remove family deletion logic
- `backend/src/lib/entitlements.ts` — Remove family archival logic
- `backend/src/app.ts` — Register vehicle-shares plugin
- `backend/test/family-sync.test.ts` → `backend/test/vehicle-shares.test.ts`

### Mobile
- `mobile/lib/features/family/` → **delete entire folder**
- `mobile/lib/features/vehicle_sharing/` — new feature folder
- `mobile/lib/features/garage/` — update vehicle card, garage home
- `mobile/lib/features/dashboard/` — update active vehicle picker
- `mobile/lib/features/car_detail/` — replace drivers with shared users
- `mobile/lib/features/settings/` — update entitlements, remove family
- `mobile/lib/core/database/` — Drift schema migration
- `mobile/lib/core/sync/` — Add share entities to sync
- `mobile/lib/generated/app_localizations_*.dart` — Regenerate

### Web
- `web/src/app/(family)/` → **delete**
- `web/src/app/(dashboard)/vehicles/[id]/shares/` — new route
- `web/src/lib/api/client.ts` — Add share endpoints

### Architecture
- `architecture/openapi.yaml` — Update endpoints
- `architecture/data-model.md` — Update entities
- `architecture/iam.md` — Update roles/permissions
- `architecture/system.md` — Update sync description

### Product
- `product/frd/family-sharing.md` → **archive**
- `product/frd/vehicle-sharing.md` — new FRD
- `product/production-scope.md` — Update family → vehicle sharing

---

## 13. Rollback Plan

If critical issues found post-deployment:
1. Feature flag: `vehicle_sharing_enabled` (default false during migration)
2. Keep family tables for 1 release cycle (soft delete)
3. Re-enable family endpoints behind flag if needed
4. Communicate to users: "Vehicle Sharing is rolling out gradually"

---

## 14. Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Backend Schema & API | 2 weeks | — |
| Mobile App | 2 weeks | Backend API ready |
| Web Admin | 1 week | Backend API ready |
| Data Migration | 1 week | Backend + Mobile ready |
| Cleanup & Polish | 1 week | All above complete |
| **Total** | **~7 weeks** | Parallelizable after Phase 1 |

---

## 15. Appendix: Autozis Reference Mapping

| Autozis Feature | DCO Implementation |
|-----------------|-------------------|
| Email-based invitation | `POST /v1/vehicles/:id/shares` with email |
| **Code/QR sharing (DCO enhancement)** | `POST /v1/vehicles/:id/shares` with method=code_qr; `GET /v1/vehicles/:id/shares` returns code/QR |
| Pending/active share management | `vehicle_share_invitations` + `vehicle_shares.status` |
| Owner-controlled permissions | `access_level`: `view` | `add_edit_own` |
| Shared vehicle record access | Sync fan-out + `seedVehicleHistory` |
| Owner records protected | `created_by` on all records; edit/delete own only |
| Insurance/maintenance plan owner-only | `requireVehicleAccess` with owner check |
| Private AI assistant chats | Not implemented yet; design for privacy |
| Plan-based share limits | Entitlements check on create share |
| Multi-vehicle garage | Existing Garage + "Shared with Me" filter |
| Digital vehicle logbook | Existing Car Detail + shared records |
| Document organizer | Existing Documents + share access |
| **Per-vehicle share management screen** | Share Management Screen (Active/Pending/Code&QR tabs) |

---

*End of Plan Document*