# Family Sharing Module

## Overview

Family Sharing is a **Premium-gated feature for the Primary Owner**: Premium is required to create and manage a family. Invited members do not need their own Premium plan; they can join and use access granted by an active family membership. Members get role-based access to vehicle information, maintenance, documents, and expenses. This module extends the existing single-owner model to support collaborative vehicle ownership within a family unit.

**Status:** Implemented; Premium entitlement enforcement is planned and is not currently enforced by the shipped app/API.
**Contract:** This FRD extends `product/mvp-scope.md` and `architecture/iam.md`.  
**Surfaces:** Mobile (Flutter), Backend (REST API), Web Admin (Next.js — read-only family view for Primary Owners).

---

## Objectives

Enable users to:

- Create a family group via share code/QR
- Invite family members as **Members** (Secondary Owners) or **Drivers**
- Assign multiple drivers per vehicle
- View family vehicles and member roles on mobile and web
- Manage driving licenses with expiry reminders
- Transfer Primary Ownership before leaving a family

---

## In Scope

### Backend
- Family group entity with share code
- Membership with roles: `primary_owner`, `member`, `driver`
- Vehicle grants linking members/drivers to vehicles with permissions
- Driving license storage (image + expiry date)
- API endpoints for family CRUD, membership, vehicle grants, licenses

### Mobile (Flutter)
- **Family Setup Screen**: Premium Primary Owner creates family and generates share code/QR; invited users can join without Premium
- **Family Management Screen**: View members, roles, invite via code/QR
- **Car Detail Screen**: Vehicle info, documents (reuse Documents vault), assigned drivers
- **User Detail Screen**: Profile, driving license (image + expiry), access level, family management actions
- **Navigation**: Accessed via **hamburger menu** → Family (moved from Settings)

### Web Admin (Next.js)
- **Normal User Login**: Primary Owners can sign in (email/password, `dco-owner` audience)
- **Family Dashboard (Read-Only)**: Family overview, vehicles, members, roles — no write actions
- Role-based route guards: `admin` → full admin; `primary_owner` → family read-only; `owner` (non-family) → not allowed

---

## Out of Scope (v1.1)

- Billing/subscription management for family plans
- Workshop booking sharing
- Insurance policy sharing
- Fleet-style management (dispatch, driver schedules)
- Cross-family vehicle sharing
- Family expense splitting / shared budgets
- Push notifications for family events (local reminders only)
- Impersonation / "view as member" on web

---

## User Personas

| Persona | Description | Primary Surface |
|---------|-------------|-----------------|
| **Primary Owner** | Premium account holder who creates family, owns vehicles, and manages members/roles; plan is DCO-admin-managed for this phase | Mobile + Web (read-only) |
| **Member (Secondary Owner)** | Full vehicle access except ownership transfer; can manage maintenance, expenses, documents | Mobile |
| **Driver** | View-only access to assigned vehicles; can log fuel, view documents, see maintenance due | Mobile |
| **Platform Admin** | Manages users, partners; can view family structures for support | Web Admin |

---

## User Stories

### US-FAM-001: Create Family
> As a Primary Owner,  
> I want to create a family group and get a share code/QR  
> So that I can invite family members to join.

### US-FAM-002: Join Family via Code
> As a family member,  
> I want to enter a share code or scan a QR code  
> So that I can join the family and access shared vehicles.

### US-FAM-003: Manage Member Roles
> As a Primary Owner,  
> I want to change a member's role (Member ↔ Driver) or remove them  
> So that I control who can do what on our vehicles.

### US-FAM-004: Assign Drivers to Vehicles
> As a Primary Owner or Member,  
> I want to assign one or more drivers to a vehicle  
> So that they can access that vehicle's info and log fuel.

### US-FAM-005: View Car Details with Drivers
> As any family member,  
> I want to see vehicle info, documents, and assigned drivers on the Car Detail screen  
> So that I know who drives what and where the papers are.

### US-FAM-006: Manage Driving License
> As a Driver or Member,  
> I want to upload my license photo and set expiry date  
> So that I get reminders before it expires.

### US-FAM-007: Transfer Ownership
> As a Primary Owner,  
> I want to transfer Primary Ownership to another Member before leaving  
> So that the family continues without data loss.

### US-FAM-008: Web Family View
> As a Primary Owner on desktop,  
> I want to sign in to the web portal and see my family's vehicles and members  
> So that I can get an overview without using my phone.

---

## Functional Requirements

### 1. Family Group

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `name` | String, required, max 100 |
| `share_code` | String, unique, 8-char alphanumeric (e.g., `A7K9M2QX`) |
| `qr_code_data` | JSON: `{ code, family_id, expires_at }` — QR regenerates on demand |
| `created_by` | FK → `users.id` (Primary Owner) |
| `created_at` | Timestamp |
| `status` | `active` \| `archived` |

**Rules:**
- One family per user (enforced by unique `user_id` on `family_memberships` where `role = primary_owner`)
- Share code rotates on Primary Owner request (old code invalidated)
- QR code expires in 7 days; can be regenerated

### 2. Family Membership

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `family_id` | FK → `families.id` |
| `user_id` | FK → `users.id` |
| `role` | `primary_owner` \| `member` \| `driver` |
| `joined_at` | Timestamp |
| `invited_by` | FK → `users.id` (nullable) |

**Rules:**
- Exactly one `primary_owner` per family
- A user can have only one membership across all families (unique `user_id`)
- Creating a family and performing Primary Owner management actions requires `users.plan=premium`
- Joining a family and using an active member/driver membership does not require the invited user's plan to be Premium
- If the Primary Owner's plan changes from `premium` to `free`, archive the family, revoke/delete its active vehicle grants, and invalidate family-authenticated sessions immediately; retain each user's own vehicles and records
- `member` = Secondary Owner (full access except ownership transfer)
- `driver` = Assigned driver access (view + fuel log + document view)

### 3. Vehicle Grants

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `vehicle_id` | FK → `vehicles.id` |
| `user_id` | FK → `users.id` (member or driver) |
| `granted_by` | FK → `users.id` (Primary Owner or Member) |
| `permission` | `full` \| `drive_only` |
| `created_at` | Timestamp |

**Rules:**
- `full` = Member access: maintenance, expenses, documents, fuel logs, parts
- `drive_only` = Driver access: view vehicle, documents, log fuel/charge, view maintenance due
- Primary Owner has implicit `full` on all their vehicles (no grant row needed)
- Multiple grants per vehicle allowed (multiple drivers)
- Grant requires grantor to have `full` on the vehicle

### 4. Driving License

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `user_id` | FK → `users.id` |
| `license_number` | String, optional |
| `issuing_country` | String, optional (ISO 3166-1 alpha-2) |
| `expiry_date` | Date, required |
| `categories` | String, optional (e.g., "B, BE") |
| `front_media_id` | FK → `media_objects.id` (license front photo) |
| `back_media_id` | FK → `media_objects.id` (license back photo) |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- One license per user (unique `user_id`)
- Expiry date drives local notification reminders (30/14/7 days before)
- Images stored via existing media pipeline (compressed, 15 MB cap)

### 5. API Endpoints (v1)

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/families` | `dco-owner` | Create family (Primary Owner) |
| GET | `/v1/families/me` | `dco-owner` | Get my family (if member) |
| GET | `/v1/families/:code` | `dco-owner` | Lookup family by share code (for joining) |
| POST | `/v1/families/:id/join` | `dco-owner` | Join family by code |
| PATCH | `/v1/families/:id` | `dco-owner` | Update family (name, regenerate code) — Primary Owner only |
| DELETE | `/v1/families/:id` | `dco-owner` | Archive family — Primary Owner only (after transfer) |
| GET | `/v1/families/:id/members` | `dco-owner` | List members with roles |
| PATCH | `/v1/families/:id/members/:userId` | `dco-owner` | Update member role / remove — Primary Owner only |
| POST | `/v1/families/:id/vehicle-grants` | `dco-owner` | Grant vehicle access — Primary Owner or Member |
| DELETE | `/v1/families/:id/vehicle-grants/:grantId` | `dco-owner` | Revoke grant — Primary Owner or grantor |
| GET | `/v1/users/me/license` | `dco-owner` | Get my driving license |
| PUT | `/v1/users/me/license` | `dco-owner` | Upsert my driving license |
| GET | `/v1/users/:id/license` | `dco-owner` | Get member's license (family only) |
| POST | `/v1/users/me/license/media` | `dco-owner` | Upload license photo (returns media_id) |
| GET | `/v1/vehicles/:id/detail` | `dco-owner` | Vehicle detail with grants, documents, assigned drivers |
| GET | `/v1/users/:id/detail` | `dco-owner` | User detail with license, family role, owned vehicles |

Authorization: `POST /v1/families` and Primary Owner management mutations require Premium. Family-code lookup, joining by invitation, and access through an active family membership do not require the invitee to be Premium. The server checks plan, family status, membership role, and vehicle grants; client route visibility is not sufficient authorization.

**Web Admin (Primary Owner read-only):**
| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| GET | `/v1/families/me` | `dco-owner` | Same as mobile — family overview |
| GET | `/v1/families/:id/members` | `dco-owner` | List members |
| GET | `/v1/vehicles/:id/detail` | `dco-owner` | Vehicle detail |

### 6. Mobile Screens

#### Family Setup Screen (New)
- Entry: **Hamburger menu** → Family → "Create Family"
- Input: Family name
- Output: Share code (copy button), QR code (share sheet), "Invite Members" button
- State: Empty family → shows only Primary Owner

#### Family Management Screen (New)
- Entry: **Hamburger menu** → Family (after family exists)
- Tabs: Members / Vehicles / Invite
- **Members tab**: List with avatar, name, role badge, vehicle count, "Change Role" / "Remove" (Primary Owner only)
- **Vehicles tab**: List vehicles with assigned drivers badges
- **Invite tab**: Share code display, QR code, "Regenerate Code" button

#### Car Detail Screen (New)
- Entry: Garage Home → Vehicle card tap (replaces Vehicle Detail)
- Sections:
  1. **Vehicle Identity**: Photo, nickname, plate, make/model/year, mileage, VIN, fuel type
  2. **Documents**: Filtered Documents vault (reuse `documents.md` UI) — categories: registration, insurance, invoice, warranty, receipt, other
  3. **Assigned Drivers**: List of drivers with license status (valid/expiring/expired), tap → User Detail
  4. **Quick Actions**: Log Service, Log Fuel, Add Document, Manage Drivers (Primary Owner/Member)

#### User Detail Screen (New)
- Entry: Family Management → Member tap, or Car Detail → Driver tap, or Settings → Profile
- Sections:
  1. **Profile**: Avatar, name, email, family role badge
  2. **Driving License**: Front/back image thumbnails, expiry date with status badge (Valid / Expiring Soon / Expired), license number, categories
  3. **Access Level**: Role description, permissions summary
  4. **My Vehicles**: List of vehicles this user owns (not family vehicles)
  5. **Actions** (contextual):
     - Primary Owner viewing Member: Change Role, Remove, Assign/Revoke Vehicles
     - Member viewing self: Edit License, Leave Family (with transfer prompt if Primary Owner)

### 7. Web Admin Changes

#### Auth
- Allow `role=owner` users to sign in via `/login` (currently admin-only)
- Issue `dco-owner` audience JWT via BFF (same as mobile)
- Route guard: if `role=admin` → admin routes; if `role=owner` + has family → family read-only routes; else → 403

#### Family Dashboard (Read-Only) — New Route: `/family`
- Header: Family name, share code (copy), member count, vehicle count
- **Vehicles Table**: Nickname, Plate, Make/Model, Primary Owner, Assigned Drivers (count), Status
- **Members Table**: Name, Email, Role, Vehicles Owned, License Status, Joined Date
- No edit/delete actions — view only
- Deep link to mobile via QR for management actions

---

## Business Rules

1. **Free users can participate when invited** — an active family membership provides only the role/grant-scoped access granted by the Premium Primary Owner
2. **Primary Owner Premium entitlement** — only a Premium user can create/manage a family; Premium is DCO-admin-managed for this phase, with no purchase or billing flow
3. **Invited members do not need Premium** — family membership and vehicle grants govern their scoped access
4. **Premium revocation archives the family** — archive the family, revoke/delete active vehicle grants, invalidate family-authenticated sessions, and remove member access without deleting accounts, personally owned vehicles, or history
5. **One family per user** — enforced at membership level
6. **Primary Owner must transfer** before leaving or deleting account; a new Primary Owner must have Premium
7. **Vehicle grants are additive** — Primary Owner retains full access; grants add Member/Driver access
8. **Driving license expiry** triggers local notifications at 30/14/7 days (reuse `notifications.md` engine)
9. **Share code is case-insensitive** but stored uppercase
10. **QR code contains deep link**: `dco://family/join?code=XXXXXXXX`
11. **Archive family** = soft delete; members revert to individual accounts; vehicles stay with original `vehicles.user_id`
12. **License images** follow existing media pipeline (compression, signed URLs)
13. **Web Primary Owner login** uses same BFF cookie flow as admin; audience `dco-owner`

---

## User Flow

### Create Family → Invite → Join
```
Primary Owner (Mobile)
  Premium user: Hamburger menu → Family → Create Family
  → Enter name → Family created
  → Share code/QR displayed
  → Tap "Invite" → Share sheet (code + QR)
  Free user without an active family membership: Family entry is hidden

Member (Mobile)
  Opens shared family join link / scans QR (joining does not require Premium)
  → If needed, logs in or signs up → confirms "Joining [Family Name] as Member"
  → Success → Family Management screen

Driver (Mobile)
  Same as Member, but role = driver
```

### Assign Driver to Vehicle
```
Primary Owner / Member (Mobile)
  Car Detail → Assigned Drivers → "Add Driver"
  → Select family member (role = driver or member)
  → Permission: "Full Access" (Member) or "Drive Only" (Driver)
  → Grant created → Driver sees vehicle in their Garage
```

### Web Primary Owner Login
```
Primary Owner (Web)
  /login → Email + Password
  → BFF validates, checks role=owner + has family
  → Sets httpOnly cookie with dco-owner JWT
  → Redirects to /family (read-only dashboard)
```

---

## Validation Rules

### Family Creation and Management
- Creator/manager must have `users.plan=premium`
- Family management mutations require Primary Owner role plus Premium entitlement
- Invited members can join and use their scoped grants without Premium
- Name: required, 1-100 chars
- Share code: auto-generated, unique, 8 chars alphanumeric

### Join Family
- Code: required, 8 chars, case-insensitive match
- User must not already belong to a family
- Family must be `active`

### Member Role Change
- Cannot change Primary Owner role (must transfer ownership)
- Cannot demote last Member with `full` grants on a vehicle (would orphan grants)

### Vehicle Grant
- Grantor must have `full` permission on vehicle
- Grantee must be family member
- Cannot grant to Primary Owner (implicit)

### Driving License
- Expiry date: required, must be future date
- License number: optional, max 50 chars
- Issuing country: optional, ISO 3166-1 alpha-2
- Images: max 15 MB after compression, JPEG/PNG/PDF

---

## Error States

| Scenario | Response |
|----------|----------|
| Family create/manage attempted without Premium | 403 `premium_required` |
| Primary Owner plan downgraded | Family archived; member access revoked |
| Join code invalid/expired | 404 `family_not_found` |
| User already in family | 409 `already_in_family` |
| Family inactive/archived | 410 `family_archived` |
| Not Primary Owner (for admin actions) | 403 `not_primary_owner` |
| Last Primary Owner trying to leave | 409 `transfer_required` |
| License expiry in past | 400 `invalid_expiry_date` |
| Web login: owner without family | 403 `no_family_access` |
| Web login: owner with family but admin routes | 403 `admin_only` |

---

## Non-Functional Requirements

- **Offline-first**: Family membership, grants, licenses sync via existing change log
- **Load time**: Car Detail < 2s (local DB), Family Management < 1.5s
- **Security**: Grants validated server-side on every vehicle access; share code not guessable (8-char alphanumeric = 2.8T combos)
- **Image handling**: License photos compressed before upload; thumbnail + full-size
- **Accessibility**: Role badges have text + color; license expiry announced to screen readers
- **Testability**: Unit tests for grant permission logic; integration tests for join/transfer flows

---

## Analytics Events

| Event | Properties |
|-------|------------|
| `family_created` | `family_id`, `vehicle_count` |
| `family_joined` | `family_id`, `role`, `method` (code/qr) |
| `member_role_changed` | `family_id`, `target_user_id`, `old_role`, `new_role` |
| `vehicle_grant_created` | `family_id`, `vehicle_id`, `grantee_id`, `permission` |
| `vehicle_grant_revoked` | `family_id`, `vehicle_id`, `grantee_id` |
| `license_uploaded` | `user_id`, `has_front`, `has_back`, `expiry_days` |
| `ownership_transferred` | `family_id`, `from_user_id`, `to_user_id` |
| `web_family_view_opened` | `family_id` |

---

## Success Metrics

- Families created per week
- Average family size (members + drivers)
- Vehicles with ≥1 assigned driver
- License upload rate among drivers
- Primary Owner web login rate (adoption of read-only dashboard)
- Family retention (active after 30/90 days)

---

## Dependencies

- Auth (JWT, roles, audiences)
- Users API (profile, license)
- Vehicles API (grants, detail)
- Documents API (vault reuse)
- Media storage (license images)
- Notifications (license expiry reminders)
- Sync (family, membership, grant, license entities)

---

## Future Enhancements (Post-v1.1)

- Family expense splitting / shared budget view
- Shared maintenance calendar (family-wide upcoming services)
- Workshop booking for family vehicles
- Insurance policy sharing within family
- Family-level mileage tracking
- Invite links with role pre-selection
- Multiple families per user (with clear ownership boundaries)
- Family admin delegation (co-owners)

---

## Migration Notes

- **Schema**: Add `families`, `family_memberships`, `vehicle_grants`, `driving_licenses` tables
- **Users table**: Add `family_id` nullable FK (denormalized for quick "my family" lookup)
- **Vehicles table**: No change (ownership stays on `user_id`); grants are separate
- **Sync**: New entity types `family`, `family_membership`, `vehicle_grant`, `driving_license`
- **Mobile Drift**: New tables for offline family/grants/license
- **Web**: New BFF auth flow for owner audience; new `/family` route tree
- **Admin API**: New `/v1/admin/families` for support visibility (list, view only)

---

## Open Decisions

1. **Billing integration**: When monetization activates, how does family plan interact with individual premium?
2. **License OCR**: Auto-extract expiry/number from uploaded license image?
4. **Shared reminders**: Should Member/Maintenance reminders notify all drivers?
5. **Vehicle transfer**: Allow transferring vehicle ownership between family members (changes `vehicles.user_id`)?
6. **Web write actions**: Enable Primary Owner to manage family from web in v1.2?
