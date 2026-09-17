# User Profile & Account Management Module

## Overview

This module extends the existing Auth and Admin modules to support post-signup profile completion, user-initiated account deletion, and admin user creation. The current auth flow creates accounts with email and password only — no user information is collected after signup. This FRD closes that gap and adds account lifecycle management.

**No email server or domain exists.** Email verification is skipped. Admin-created accounts use temporary passwords communicated out-of-band.

**Source of truth:** `product/mvp-scope.md`.
**Extends:** `product/frd/auth.md`, `product/frd/admin.md`, `product/frd/family-sharing.md`.

---

## Objectives

Enable users to:

- Complete their profile after account creation (photo, name, contact, address)
- Delete their account when they no longer want to use the system
- Have their vehicles and family memberships handled correctly on deletion

Enable admins to:

- Create user accounts with temporary passwords
- View full user profiles including new fields
- Delete (deactivate) user accounts from the admin portal

---

## In Scope

- Profile fields: profile photo, display name, contact number, address
- Profile completion prompt after signup
- Profile edit screen in Settings
- User-initiated account deletion (soft-delete)
- Cascading behavior: vehicles archived, family handled
- Admin: create user (email + temp password + profile fields)
- Admin: delete user (soft-delete) with vehicle/family handling
- Admin: view new profile fields on user detail

---

## Out of Scope

- Email verification (no email server)
- Hard-delete / purge of user data
- Admin impersonation
- Bulk user import/export
- Profile fields beyond the four listed (bio, social links, etc.)
- Profile photo cropping / editing beyond upload

---

## User Personas

| Persona | Description |
|---------|-------------|
| **New Owner** | Just signed up, needs to complete profile |
| **Existing Owner** | Wants to update profile or delete account |
| **Primary Owner** | Must handle family before deleting |
| **Platform Admin** | Creates/supports user accounts |

---

## User Stories

### US-PROF-001: Complete Profile After Signup

> As a new user,
> I want to set my profile picture, name, contact number, and address after creating my account
> So that my identity is established in the system.

### US-PROF-002: Edit Profile

> As a user,
> I want to update my profile information from Settings
> So that my details stay current.

### US-PROF-003: Delete Account

> As a user,
> I want to delete my account when I no longer want to use the system
> So that my data is removed and I am no longer tracked.

### US-PROF-004: Admin Create User

> As an admin,
> I want to create a user account with a temporary password
> So that I can onboard users who cannot self-register.

### US-PROF-005: Admin Delete User

> As an admin,
> I want to delete (deactivate) a user account
> So that I can remove abusive or requested accounts.

### US-PROF-006: Admin View Full Profile

> As an admin,
> I want to see contact number and address on a user's profile
> So that I have complete information for support.

---

## Functional Requirements

### 1. Profile Schema Changes

**Table: `users`**

| New Field | Type | Rule |
|-----------|------|------|
| `profile_photo_media_id` | UUID, nullable FK → `media_objects.id` | Profile photo. Follows existing media pipeline (compress, upload). |
| `contact_phone` | text, nullable | Optional. Max 20 chars. E.164 format recommended but not enforced. |
| `address` | text, nullable | Optional. Free-form text. Max 500 chars. |

**Existing field reused:**
| Field | Usage |
|-------|-------|
| `display_name` | Already exists, nullable. Becomes the "User Name" field. |

### 2. Backend API Changes

#### Update Profile

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| PATCH | `/v1/users/me/profile` | `dco-owner` | Update own profile fields |

**Request body (all optional):**
```json
{
  "display_name": "string",
  "contact_phone": "string",
  "address": "string"
}
```

**Response:** Updated `publicUser` object.

#### Upload Profile Photo

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/users/me/profile/photo` | `dco-owner` | Upload profile photo (multipart) |

**Behavior:**
- Accept image (JPEG/PNG/WebP), max 5 MB
- Compress server-side (existing media pipeline)
- Store in `media_objects`, set `users.profile_photo_media_id`
- Return `{ media_id, url }` (signed URL, 1-hour expiry)
- Old photo media object is orphaned (not deleted immediately; cleanup job later)

#### Get Profile

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| GET | `/v1/users/me/profile` | `dco-owner` | Get own full profile |

**Response:**
```json
{
  "id": "uuid",
  "email": "string",
  "display_name": "string",
  "contact_phone": "string",
  "address": "string",
  "profile_photo_url": "string",
  "role": "owner",
  "plan": "free",
  "status": "active",
  "email_verified": false,
  "active_vehicle_id": "uuid",
  "family_id": "uuid",
  "created_at": "2026-09-17T00:00:00Z"
}
```

#### Delete Account

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/users/me/delete` | `dco-owner` | Request account deletion |

**Request body:**
```json
{
  "password": "string (required, confirmation)",
  "reason": "string (optional)"
}
```

**Behavior:**
1. Validate password
2. Check family status:
   - If Primary Owner with other members → **reject** with `409 transfer_required`
   - If Primary Owner, sole member → dissolve family (archive family, remove membership)
   - If Member/Driver → remove membership, revoke vehicle grants
3. Archive all vehicles owned by user (`archived=true`, `archived_at` set)
4. Set `users.status = 'deactivated'`
5. Revoke all refresh tokens
6. Clear `users.family_id`
7. Return `204`

**After deletion:**
- User cannot sign in (blocked at auth)
- Local data remains on device until they sign in again (they cannot)
- Outbox remains bound to `user_id` (never pushed)
- Vehicle data preserved (archived, not deleted)
- Admin can reactivate if needed

#### Get Public User (updated)

The existing `GET /v1/users/:id/detail` endpoint returns:
```json
{
  "id": "uuid",
  "email": "string",
  "display_name": "string",
  "contact_phone": "string",
  "address": "string",
  "profile_photo_url": "string",
  "role": "owner",
  "family_role": "primary_owner",
  "vehicles": [...],
  "license": {...}
}
```

### 3. Mobile Changes

#### Profile Completion Prompt

**Trigger:** After signup, if `display_name` is null.

**Location:** Dashboard screen, top of screen as a dismissible banner.

**Copy:** "Complete your profile — add a photo and your details"

**Action:** Taps navigate to Profile screen.

**Dismiss:** User can dismiss. Prompt reappears on next app launch until profile is completed (display_name is set).

**Completion criteria:** `display_name` is not null. Other fields are optional.

#### Profile Screen (New — in Settings)

**Entry:** Settings → Profile (or from Dashboard prompt)

**Sections:**
1. **Photo**: Circle avatar with camera icon overlay. Tap to upload. Shows current photo or default avatar.
2. **Name**: Text field. Required for completion. Max 50 chars.
3. **Contact Number**: Text field. Optional. Max 20 chars. Phone keyboard.
4. **Address**: Text field. Optional. Max 500 chars. Multiline.
5. **Email**: Display only (not editable). Shows verification status badge.
6. **Account**: Member since date. "Delete Account" button (red, at bottom).

**Save:** Single "Save" button at top-right. Calls `PATCH /v1/users/me/profile`. Shows success snackbar.

**Photo upload:** Tap avatar → image picker → compress → `POST /v1/users/me/profile/photo` → update avatar in UI.

#### Delete Account Flow

**Entry:** Profile screen → "Delete Account" (red text button)

**Confirmation dialog:**
```
Delete Account?

This will deactivate your account and archive all your vehicles.
You will not be able to sign in again.

This action can be reversed by contacting support.

Type your password to confirm:
[password field]

[Cancel]  [Delete Account]
```

**Validation:**
- Password required
- If user is Primary Owner with family members → show different message: "You must transfer ownership of your family before deleting. Go to Family Settings."
- Block deletion, do not proceed

**On success:**
- Show confirmation: "Your account has been deleted."
- Clear local tokens (same as logout)
- Navigate to Welcome screen

**On error (transfer required):**
- Show message: "You are the Primary Owner of a family. Transfer ownership or dissolve your family before deleting your account."
- Offer "Go to Family Settings" button

### 4. Admin Changes

#### Create User

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/admin/users` | `dco-admin` | Create a new user account |

**Request body:**
```json
{
  "email": "string (required)",
  "temporary_password": "string (required, min 8 chars)",
  "display_name": "string (optional)",
  "role": "owner | admin (default: owner)",
  "plan": "free | premium (default: free)"
}
```

**Behavior:**
1. Validate email unique
2. Create user with provided fields
3. Hash temporary_password (bcrypt)
4. Set `email_verified = false` (but not blocking)
5. Seed default fuel types for the user
6. Return `publicUser` object

**Business rules:**
- Admin cannot create a user with `role=admin` unless the creating user is already `admin` (prevent escalation)
- No verification email sent (no email server)
- User must log in with email + temp password, then change password

#### Delete User (Soft-Delete)

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/admin/users/:userId/delete` | `dco-admin` | Soft-delete a user |

**Behavior:**
1. Prevent admin from deleting themselves
2. Prevent deleting the last admin account
3. If user is Primary Owner with family members:
   - Dissolve family (archive, remove all memberships, revoke grants)
   - OR block and return error asking admin to resolve family first
4. Archive all vehicles owned by user
5. Set `users.status = 'deactivated'`
6. Revoke all refresh tokens
7. Clear `users.family_id`
8. Audit log the action
9. Return `204`

**Decision**: Admin delete should be **forceful** — dissolve family automatically, archive vehicles. The admin is a support role and should be able to clean up. If the user needs family transfer, that's a user-facing concern, not admin.

#### Update User Profile (Admin)

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| PATCH | `/v1/admin/users/:userId/profile` | `dco-admin` | Update user profile fields |

**Request body (all optional):**
```json
{
  "display_name": "string",
  "contact_phone": "string",
  "address": "string",
  "plan": "free | premium"
}
```

**Audit logged.**

#### Admin User List (Updated)

The `GET /v1/admin/users` endpoint now includes:

```json
{
  "id": "uuid",
  "email": "string",
  "display_name": "string",
  "contact_phone": "string",
  "plan": "free",
  "status": "active",
  "vehicle_count": 2,
  "created_at": "2026-09-17T00:00:00Z"
}
```

#### Admin User Detail (Updated)

The `GET /v1/admin/users/:userId` endpoint now includes:

```json
{
  "id": "uuid",
  "email": "string",
  "display_name": "string",
  "contact_phone": "string",
  "address": "string",
  "profile_photo_url": "string",
  "email_verified": false,
  "plan": "free",
  "status": "active",
  "family": {
    "id": "uuid",
    "name": "string",
    "role": "primary_owner"
  },
  "vehicles": [...],
  "documents_count": 5,
  "created_at": "2026-09-17T00:00:00Z"
}
```

### 5. Web Admin UI Changes

#### User List Page (Updated)

**New columns:** Contact Phone (abbreviated), address (truncated)

**Search:** Include `contact_phone` in search

#### User Detail Page (Updated)

**New sections:**
- **Contact**: Phone, Address
- **Profile Photo**: Display if set

**New actions:**
- "Edit Profile" button → modal with display_name, contact_phone, address, plan, role
- "Delete User" button (replaces or supplements "Deactivate") with confirmation dialog

**Delete confirmation dialog:**
```
Delete User [email]?

This will:
- Deactivate their account
- Archive all their vehicles
- Dissolve their family (if Primary Owner)

This action can be reversed by reactivating the account.

[Cancel]  [Delete User]
```

#### Create User Page (New)

**Entry:** Users page → "Create User" button

**Form fields:**
- Email (required)
- Temporary Password (required, min 8 chars, show/hide toggle)
- Display Name (optional)
- Role: radio (Owner / Admin) — Admin requires confirmation
- Plan: radio (Free / Premium)

**Submit:** Calls `POST /v1/admin/users`. On success, show temp password to admin (one-time display, with copy button). Admin must share it with the user out-of-band.

---

## Business Rules

1. **Profile completion is optional** — users can use the app without filling profile fields. Prompt is non-blocking.
2. **display_name is the completion trigger** — when set, the Dashboard prompt is dismissed.
3. **User self-delete is soft-delete** — account deactivated, vehicles archived, family handled. Data preserved for admin recovery.
4. **Primary Owner cannot delete** if family has other members — must transfer ownership or dissolve family first.
5. **Member/Driver deletion** — removes membership, revokes grants, clears family_id. Family continues.
6. **Admin delete is forceful** — dissolves family, archives vehicles, deactivates. No transfer step required.
7. **Admin cannot delete themselves** or the last admin.
8. **Temp password** — admin-created accounts require the user to change password on first login (prompt after login).
9. **No email verification** — skipped for now. `email_verified` stays false. No blocking behavior.
10. **Profile photo** — follows existing media pipeline (compress, 5 MB cap). Old photo orphaned (cleanup later).
11. **All admin writes audited** — create user, delete user, update profile.

---

## User Flow

### Post-Signup Profile Completion
```
Signup (email + password)
  → Session established
  → Dashboard (empty garage)
  → Banner: "Complete your profile"
  → Tap → Profile Screen
  → Set name, photo, phone, address
  → Save → Banner dismissed
  → (Can revisit from Settings anytime)
```

### User Deletes Account
```
Settings → Profile → "Delete Account"
  → Confirmation dialog
  → Enter password
  → If Primary Owner with family → BLOCKED, show message
  → If OK → Account deactivated
  → Vehicles archived
  → Family handled (dissolved if sole owner, membership removed if member)
  → Tokens cleared
  → Welcome screen
```

### Admin Creates User
```
Admin Portal → Users → "Create User"
  → Fill email, temp password, optional fields
  → Submit
  → Temp password displayed (copy to share)
  → New user appears in list
  → User logs in with temp password
  → Prompted to change password
```

### Admin Deletes User
```
Admin Portal → Users → [user] → "Delete User"
  → Confirmation dialog
  → Confirm
  → Account deactivated
  → Vehicles archived
  → Family dissolved
  → User cannot sign in
```

---

## Validation Rules

### Profile Update
- `display_name`: max 50 chars
- `contact_phone`: max 20 chars
- `address`: max 500 chars

### Profile Photo
- MIME: image/jpeg, image/png, image/webp
- Max size: 5 MB (before compression)

### Account Deletion (User)
- Password required and must match
- Must not be Primary Owner with family members

### Admin Create User
- Email: required, valid format, unique
- Temporary password: required, min 8 chars
- Role: `owner` or `admin`

### Admin Delete User
- Cannot delete self
- Cannot delete last admin

---

## Error States

| Scenario | Response |
|----------|----------|
| Profile photo too large | 413 `photo_too_large` |
| Invalid photo format | 400 `invalid_photo_format` |
| Password mismatch on delete | 401 `invalid_password` |
| Primary Owner with family | 409 `transfer_required` |
| Admin tries to delete self | 409 `cannot_delete_self` |
| Admin tries to delete last admin | 409 `last_admin` |
| Email already exists (admin create) | 409 `email_taken` |
| Temp password too short | 400 `password_too_short` |

---

## Non-Functional Requirements

- **Profile load time** < 500ms (single user read)
- **Photo upload** < 3s on 4G (compress + upload + CDN)
- **Delete account** < 2s (soft-delete + archive)
- **Accessible forms** — labels, error messages, photo has alt text
- **Offline behavior** — profile edits go through outbox (sync). Delete account is online-only.
- **Secure** — temp password not logged. Profile photo signed URLs expire in 1 hour.

---

## Analytics Events

| Event | Properties |
|-------|------------|
| `profile_completed` | `fields_set` (count), `has_photo` |
| `profile_updated` | `fields_changed` |
| `profile_photo_uploaded` | `size_bytes` |
| `account_deleted` | `reason`, `had_vehicles`, `had_family`, `family_role` |
| `admin_user_created` | `role`, `plan` |
| `admin_user_deleted` | `target_user_id`, `had_vehicles`, `had_family` |

---

## Success Metrics

- Profile completion rate (% of users with `display_name` set)
- Profile photo upload rate
- Account deletion volume (and reasons if collected)
- Admin-created accounts (adoption of manual onboarding)
- Time from admin create to first user login

---

## Dependencies

- Auth (JWT, session management, password validation)
- Media storage (profile photo pipeline)
- Vehicles API (archive on delete)
- Family Sharing API (dissolve/remove membership on delete)
- Sync Engine (profile edits via outbox)
- Admin API (existing user management)

---

## Migration Notes

**Schema:**
- Add `profile_photo_media_id` (UUID, nullable FK) to `users`
- Add `contact_phone` (text, nullable) to `users`
- Add `address` (text, nullable) to `users`

**Mobile:**
- New `ProfileScreen` in Settings
- Profile completion banner on Dashboard
- Delete account flow in Profile screen
- User entity updated with new fields

**Backend:**
- New endpoints: `PATCH /v1/users/me/profile`, `POST /v1/users/me/profile/photo`, `GET /v1/users/me/profile`, `POST /v1/users/me/delete`
- Admin endpoints: `POST /v1/admin/users`, `POST /v1/admin/users/:userId/delete`, `PATCH /v1/admin/users/:userId/profile`
- Updated serialization: `publicUser` includes new fields

**Web Admin:**
- New "Create User" page
- Updated user list and detail pages
- Delete user action with confirmation

---

## Open Decisions

1. **Profile photo orphan cleanup** — When a user uploads a new photo, the old `media_objects` row is orphaned. Add a periodic cleanup job, or delete immediately on new upload? (Recommend: delete immediately, simpler.)
2. **Admin force-delete family** — Should admin dissolution of family notify other members? (Recommend: no notification in MVP, just remove memberships.)
3. **Temp password expiry** — Should the temp password expire if unused? (Recommend: no expiry in MVP. Admin can deactivate if needed.)
4. **Hard delete later** — Should we plan for a future hard-delete/purge endpoint with a grace period? (Recommend: yes, document as future enhancement.)
