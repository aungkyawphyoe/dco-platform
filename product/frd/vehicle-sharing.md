# Vehicle Sharing Module

## Overview

Vehicle Sharing lets an owner hand another account controlled access to **one specific vehicle** —
a partner, a caregiver, a family member, a fleet hand-over — without creating a household or
group. There is no group entity: access is a row on the vehicle (`vehicle_shares`), granted by an
8-character Code/QR or by an email invitation, at `view` or `add_edit_own`.

This replaces the Family Sharing module. The migration plan is
`product/frd/vehicle-sharing-plan.md`; the schema and IAM detail are
`architecture/data-model-vehicle-sharing.md` and `architecture/iam-vehicle-sharing.md`.

**As built:** Done. Backend, Mobile, Web owner surface, and data migration implemented; Family
Sharing tables and endpoints removed. Status index: `product/frd/README.md`.

---

# Objectives

Enable users to:

- Share one vehicle with another account, at a permission level they choose
- Invite by email (the invitee taps a link) or by Code/QR (the invitee types or scans a code)
- See and change who has access, change their access level, and revoke them
- See the vehicles other people have shared with them in their own garage
- Be confident that revoking access takes effect immediately

---

# In Scope

- Per-vehicle shares with `access_level`: `view` | `add_edit_own`
- Two invitation methods: `email` (addressed, deep link) and `code_qr` (8-char code, QR payload)
- Owner's per-vehicle **Share Management** screen: active shares, pending invitations, current
  code/QR card, access-level change, revoke, resend, cancel, regenerate code
- Invitee screens: **Accept invite**, **Join by code** (with vehicle preview), **Shared with Me**
- Plan-based share limits (free 1, lite 3, standard/fleet unlimited — one cap for per-vehicle and total)
- Sync: share changes reach both parties through the change log; shared vehicle history is seeded
  into the invitee's log on accept/join
- Web owner surface: owned + shared vehicle lists and the shares page
- Driving license remains a standalone per-user module, readable by anyone sharing a vehicle
- Data migration from `family_memberships` / `family_vehicles` / `vehicle_grants`

## Backend (Fastify)

- `POST /v1/vehicles/:id/shares` — create an invitation (`method: "email"` | `"code_qr"`)
- `GET /v1/vehicles/:id/shares` — owner's management detail (shares, pending invites, code, limits)
- `PATCH /v1/vehicles/:id/shares/:shareId` — change `access_level`, regenerate code
- `DELETE /v1/vehicles/:id/shares/:shareId` — revoke
- `POST /v1/vehicles/:id/invitations/:inviteId/resend` — rotate token and re-email
- `DELETE /v1/vehicles/:id/invitations/:inviteId` — cancel a pending invitation
- `GET /v1/vehicles/shared` — vehicles shared with me
- `POST /v1/vehicles/shares/accept` — accept by email token
- `POST /v1/vehicles/shares/join` — join by 8-char code
- `POST /v1/vehicles/shares/decline` — decline by email token
- `GET /v1/vehicles/shares/:code` — preview a code before joining
- `GET /v1/me/entitlements` → `vehicle_sharing.{available,can_share,limits,active_shares}`

## Mobile (Flutter)

- `lib/features/vehicle_sharing/` — entities, repository (REST + Drift cache), providers,
  `share_access_level`, `share_code_panel`, and the five screens below
- Routes: `/shares/shared-with-me`, `/shares/join?code=`, `/shares/accept?token=`,
  `/vehicles/:id/shares`, `/vehicles/:id/shares/new`
- Drawer: **Shared with Me** and **Join Vehicle Share** replace the old family section
- Garage: shared vehicles appear under a `shared` source with a "Shared with Me" entry tile;
  the share action is on owned vehicles only

## Web Owner (Next.js)

- `/vehicles` — owned and shared vehicle tables
- `/vehicles/[id]/shares` — share management (invite form, active shares with access select and
  revoke, pending invitations with resend/cancel, share code + QR modal, regenerate)
- `/family` removed; owner paths guard on `role === "owner"` only

---

# Out of Scope

- A household/group/family entity of any kind
- Transferring vehicle ownership through a share (use Fleet transfer, or change `vehicles.user_id`)
- Per-share expiry after acceptance (only invitations and codes expire)
- Sharing with a non-account: every sharee must be a registered account
- Sharing organization/Fleet vehicles (they are excluded from this path)
- Billing / in-app purchase — plan is DCO-admin-managed
- Sharing documents, notifications, or notes independently of a vehicle
- Per-share read-only "audit" export

---

# User Personas

- Everyday Owner
- Family Manager
- Car Enthusiast

---

# User Stories

### US-VS-001

As a vehicle owner,

I want to invite someone by email

So that they can see and log against my vehicle without me handing over my account.

---

### US-VS-002

As a vehicle owner,

I want to show an 8-character code or QR

So that someone next to me can join instantly without typing an address.

---

### US-VS-003

As a vehicle owner,

I want to see everyone who currently has access and change their level

So that a temporary helper does not keep write access forever.

---

### US-VS-004

As a vehicle owner,

I want to revoke access

So that they lose the vehicle on their next request, not "eventually".

---

### US-VS-005

As a sharee,

I want a "Shared with Me" list

So that I can open a vehicle I do not own from the same garage.

---

### US-VS-006

As a sharee,

I want to preview the vehicle before entering a code

So that I do not join the wrong car.

---

### US-VS-007

As a sharee with `view`,

I want to read the shared vehicle's history and records

So that I stay informed without changing anything.

---

### US-VS-008

As a sharee with `add_edit_own`,

I want to add my own services, expenses, and documents

So that my usage is recorded without rewriting the owner's history.

---

# Functional Requirements

## Create an invitation (owner only)

Required

- `method`: `email` or `code_qr`
- For `email`: an email address
- `access_level` (defaults to `view`)

Behavior

- Email: stores a 7-day token, mails `dco://vehicle/share/accept?token=…`. If the address already
  has an account, a `pending` share row is created so the owner sees it as waiting.
- Code/QR: replaces any outstanding code (rotating invalidates the old one), stores an 8-char
  code with a 7-day expiry, returns `dco://vehicle/share/join?code=…`.
- Both methods check the plan's per-vehicle and total caps first.
- Emailing is best-effort: a mail failure does not fail the request.

## Share Management screen (owner only)

- Current share code + QR (or a "Generate code" prompt when none is outstanding)
- Active shares: display name, email, access level (editable), revoke
- Pending invitations: email, expiry, resend, cancel
- Plan limits shown as "n of N on this vehicle"
- Regenerating the code invalidates the previous one immediately

## Accept / decline (email flow)

- Accept requires the signed-in account's email to match the invited email (`403 email_mismatch`)
- Decline deletes the invitation and any `pending` placeholder share
- Accept seeds the vehicle and its plan items, service records, parts, fuel logs, documents, and
  expenses into the invitee's change log so history is not empty

## Join by code (Code/QR flow)

- `GET /v1/vehicles/shares/:code` previews vehicle nickname, plate, owner display name, access
  level, and expiry before joining
- The vehicle owner cannot join their own vehicle (`409 owner_cannot_join`)
- Case-insensitive code input; server upper-cases before lookup

## Access levels

Three roles: the vehicle **owner**, a sharee with `add_edit_own` (contributor), and a sharee with
`view` (read-only). This table is the contract for both the API and the mobile UI.

| Capability | Owner | `add_edit_own` | `view` |
|------------|:-----:|:--------------:|:------:|
| Read the vehicle, plan items, service records, parts, expenses, fuel logs, documents, dashboard, warranty | ✓ | ✓ | ✓ |
| Create service records, expenses, parts, documents, fuel logs | ✓ | ✓ | ✗ |
| Edit/delete records you created | ✓ | ✓ | ✗ |
| Edit/delete records someone else created | ✓ | ✗ | ✗ |
| Edit vehicle identity, archive the vehicle | ✓ | ✗ | ✗ |
| Create/edit/delete maintenance plan items | ✓ | ✗ | ✗ |
| Create, edit, revoke, resend shares (share roster) | ✓ | ✗ | ✗ |
| Advance mileage (service or fuel odometer) | ✓ | ✓ | ✗ |

Notes:

- Completing a plan item happens as a side effect of registering a service record, so anyone who
  can create service records can check an item off — the plan item itself stays owner-managed.
- Fuel types and notifications are per-user: every user, including a sharee, reads and manages
  their own fuel-type catalog, and a fuel log must reference a type from the logging user's catalog.
- The API stays authoritative; the mobile UI hides actions it knows are not allowed instead of
  surfacing 403s.

## Shared with Me (sharee)

- Lists non-archived vehicles with an active share on you, with owner name and access level
- Selecting one makes it the active vehicle; the vehicle's history arrives through sync
- Revocation removes it on the next pull (`vehicle_share` delete → local row dropped only when
  the vehicle's source is `shared`)

---

# Business Rules

- One row per `(vehicle_id, user_id)` — you cannot be granted the same vehicle twice
- Only `status='active'` grants access; `pending` never does
- Only the vehicle owner creates, edits, revokes, resends, or cancels shares
- Sharees cannot edit vehicle identity, archive the vehicle, manage the maintenance plan, or see
  other sharees
- Vehicles linked to an organization cannot be shared and are invisible to this path
- Plan limits are enforced per **owner**, on create and on accept/join:

  | Plan | Active shares per vehicle | Active shares total |
  |------|---------------------------|---------------------|
  | `free` | 1 | 1 |
  | `lite` | 3 | 3 |
  | `standard` | unlimited | unlimited |
  | `fleet` | unlimited | unlimited |

- Downgrading revokes shares above the new plan's caps (oldest kept) and blocks new ones while
  over the cap; vehicles are never revoked or hidden
- Revoking deletes the row (the enum's `revoked` value is never written)
- Fuel types and notifications stay user-scoped: a sharee uses their own fuel-type catalog
- Admin deactivating a user deletes their shares in both directions and archives their vehicles

---

# User Flow

Owner: vehicle card → Share

↓

Choose **Invite by email** (address + access) or **Show code**

↓

Share Management: see active shares, pending invites, current code/QR

↓

Invitee opens the link or enters the code → preview → **Accept** / **Join**

↓

Vehicle appears under **Shared with Me**; history streams in via sync

↓

Owner revokes → invitee's copy disappears on the next pull

---

# Validation Rules

Email

- Required for `method: "email"`, valid address format
- Must not already hold a share on the vehicle (`409 already_shared`)

Share code

- Exactly 8 alphanumeric characters, upper-cased on lookup
- Not expired (`410 share_code_expired`)

Invitation token

- Not expired (`410 invitation_expired`)
- Not already used (`409 already_accepted`)
- Sign-in email must match the invited email

Access level

- One of: `view`, `add_edit_own`

---

# Error States

- `403 not_vehicle_owner` — managing shares on a vehicle you do not own
- `403 no_vehicle_access` — reading a vehicle you have no share on
- `403 insufficient_permission` — any write with `view`, or editing/deleting a record you did not
  create on a vehicle you do not own (owner-only: vehicle identity, plan items, shares)
- `403 share_limit_reached` — over the per-vehicle or total cap
- `403 email_mismatch` — accepting with the wrong account
- `404 share_not_found` / `invitation_not_found` / `share_code_not_found` / `vehicle_not_found`
- `409 already_shared`, `409 already_accepted`, `409 already_responded`, `409 owner_cannot_join`
- `410 invitation_expired` / `410 share_code_expired`
- Offline: shares are read-only offline; accept/join and management actions need the network
- Mail delivery failure: invitation still created, no error surfaced

---

# Non-Functional Requirements

- Revocation effective on the next request (no token refresh required — no share claims in JWT)
- Share codes: 62⁸ ≈ 2.18 × 10¹⁴ combinations, 7-day expiry
- Invite tokens: random, unique, rotated on resend
- QR payload carries `{code, vehicle_id, expires_at}` only — no secrets
- Shared vehicle history is seeded once at accept/join, not on every pull
- Change fan-out is bounded by the vehicle's audience (owner + active shares)

---

# Analytics

Events

- `vehicle_share_created` (method)
- `vehicle_share_accepted`
- `vehicle_share_joined`
- `vehicle_share_declined`
- `vehicle_share_revoked`
- `vehicle_share_access_changed`

---

# Success Metrics

- Sharees with at least one active share
- Acceptance rate of invitations within 7 days
- Median time from invite to first shared action
- Revocations within 30 days of grant (too high suggests the default level is wrong)

---

# Dependencies

- Authentication (all flows require a signed-in account)
- Garage (vehicle identity, active vehicle)
- Sync Engine (change log, history seeding)
- Entitlements (`GET /v1/me/entitlements`)
- Mail (email invitations, best-effort)
- Local Database (Drift share cache, `source='shared'` stamping)

---

# Future Enhancements

- Share an entire garage with one relationship (still not a "family" object — a rule set)
- Expiring shares / time-boxed access
- Share-level read-only audit trail
- Sharing a single document or note without the vehicle
- Native universal links for `dco://` deep links (currently GoRouter paths only)
- Per-share notification preferences

---

# Migration Notes

`backend/drizzle/0008_vehicle_sharing.sql` (idempotent, runs on every boot):

- `family_memberships` + `family_vehicles` → `vehicle_shares`, skipping the vehicle owner;
  `member`/`primary_owner` → `add_edit_own`, `driver` → `view`; `accepted_at = joined_at`
- `vehicle_grants` → `vehicle_shares`, `full` → `add_edit_own`, otherwise `view`
- Drops `families`, `family_memberships`, `family_vehicles`, `vehicle_grants`, `users.family_id`,
  and the `family_status` / `family_role` / `grant_permission` enums
- Makes `refresh_tokens.family_id` nullable so existing sessions survive
- Keeps `driving_licenses`

Verified by `backend/test/migrations.test.ts` (double apply) and
`backend/test/family-migration.test.ts` (conversion).
