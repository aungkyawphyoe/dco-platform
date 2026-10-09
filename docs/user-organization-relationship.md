# User & Organization Relationship — Admin Operations Guide

## Overview

Users and Organizations are **separate entities** with independent lifecycles and statuses. They are linked via the `organization_members` join table.

---

## Entity Definitions

| Aspect | User | Organization |
|--------|------|--------------|
| **Table** | `users` | `organizations` |
| **Status values** | `active`, `deactivated` | `pending`, `active`, `suspended`, `archived` |
| **Purpose** | Human account (login, ownership, family, org membership) | Business entity (fleet, showroom, taxi, rental, etc.) |
| **Plan** | `free`, `lite`, `standard`, `fleet` | `enterprise` (only) |
| **Roles** | `owner`, `admin` | `org_admin`, `org_manager`, `org_mechanic`, `org_driver` (via membership) |

---

## Status Independence

```
User status          Organization status
─────────────────────────────────────────────
active        ←→     pending / active / suspended
deactivated   ←→     pending / active / suspended / archived
```

**Deactivating a user does NOT change their organization's status.**
**Suspending/archiving an organization does NOT deactivate its members.**

---

## Link: `organization_members`

| Column | Description |
|--------|-------------|
| `org_id` | FK → `organizations.id` |
| `user_id` | FK → `users.id` (unique — one org per user) |
| `role` | `org_admin` \| `org_manager` \| `org_mechanic` \| `org_driver` |
| `joined_at` | Timestamp |
| `invited_by` | FK → `users.id` |

- A user can belong to **at most one organization**.
- The `organizations.admin_user_id` points to the `org_admin` user (enforced by unique index where status ≠ `archived`).

---

## Admin Dashboard — User CRUD Guardrails

### `POST /admin/users/:userId/deactivate`

| Condition | Result |
|-----------|--------|
| User is `admin_user_id` of an org with status `pending`, `active`, or `suspended` | **409 `org_admin_active`** — Blocked. Must suspend/archive org first. |
| User is regular member (or org_admin of archived org) | Allowed → user status = `deactivated`, tokens revoked |
| User already `deactivated` | Idempotent (no error) |

### `POST /admin/users/:userId/reactivate`

| Condition | Result |
|-----------|--------|
| User exists | Allowed → user status = `active` |

---

## Fleet Admin — Driver CRUD Guardrails

### `POST /organizations/:id/members/:userId/status` (org_admin only)

| Condition | Result |
|-----------|--------|
| Member role = `org_admin` | **409 `cannot_change_org_admin`** |
| Target user is `admin_user_id` of **another** org with status `pending`/`active`/`suspended` | **409 `org_admin_active`** |
| Target user already `deactivated` | **409 `already_deactivated`** |
| Valid deactivation | Completes active driver assignments, deactivates user, revokes tokens |

### `PATCH /admin/organizations/:id/drivers/:userId/status` (platform admin only)

| Condition | Result |
|-----------|--------|
| Member role ≠ `org_driver` | **409 `not_a_driver`** |
| Target user is `admin_user_id` of **any** org with status `pending`/`active`/`suspended` | **409 `org_admin_active`** |
| Target user already `deactivated` | **409 `already_deactivated`** |
| Valid deactivation | Same as fleet endpoint |

---

## Organization Status Transitions (Admin)

```
pending ──activate──→ active ──suspend──→ suspended
                            │                │
                            └──archive──→ archived (terminal)
```

| Endpoint | `PATCH /admin/organizations/:organizationId/status` |
|----------|-----------------------------------------------------|
| Body | `{ "status": "active" \| "suspended" \| "archived" }` |
| `active` → `active` | No-op |
| `archived` | Deletes `organization_members` and `organization_vehicles` |
| `active` ← `pending`/`suspended` | Sets `activated_by`, `activated_at`, sends email to org admin |

---

## Scenario Table

| Scenario | User Status | Org Status | Who Can Fix |
|----------|-------------|------------|-------------|
| Org admin deactivated via Admin Dashboard | `deactivated` | `active` (unchanged) | Platform admin → reactivate user |
| Org admin deactivated via Fleet Admin | `deactivated` | `active` (unchanged) | Org admin → reactivate member |
| Org suspended via Admin Dashboard | `active` (unchanged) | `suspended` | Platform admin → activate org |
| Org archived via Admin Dashboard | `active` (unchanged) | `archived` | Platform admin → (manual cleanup) |
| Last org member deactivated | `deactivated` | `active` (orphaned) | Platform admin → suspend/archive org |

---

## Error Codes Reference

| Code | HTTP | Meaning |
|------|------|---------|
| `org_admin_active` | 409 | User is admin of non-archived organization |
| `cannot_change_org_admin` | 409 | Cannot change status of org_admin member |
| `already_deactivated` | 409 | User already deactivated |
| `already_active` | 409 | User already active |
| `org_archived` | 410 | Cannot modify archived organization |
| `member_not_found` | 404 | No membership in that org |
| `user_not_found` | 404 | User ID does not exist |

---

## Recommended Workflow

1. **To disable an organization**: Use Admin Dashboard → Organizations → set status to `suspended` or `archived`.
2. **To disable a user**: Use Admin Dashboard → Users → deactivate. If they're an org admin, you'll be prompted to handle the org first.
3. **Org admin managing their team**: Use Fleet Portal → Members → change status. Cannot touch org_admin; blocked if user admins another org.

---

## API Endpoints Summary

| Operation | Admin Dashboard (Platform) | Fleet Portal (Org Admin) |
|-----------|----------------------------|--------------------------|
| List users | `GET /admin/users` | — |
| View user | `GET /admin/users/:id` | — |
| Deactivate user | `POST /admin/users/:id/deactivate` | `POST /organizations/:id/members/:userId/status` |
| Reactivate user | `POST /admin/users/:id/reactivate` | `POST /organizations/:id/members/:userId/status` |
| List orgs | `GET /admin/organizations` | `GET /organizations` (owned) |
| View org | `GET /admin/organizations/:id` | `GET /organizations/:id` |
| Change org status | `PATCH /admin/organizations/:id/status` | — |
| Create org | `POST /admin/organizations` | — |

---

## Implementation Notes

- Guardrails added in: `backend/src/modules/admin.ts` and `backend/src/modules/fleet.ts`
- Checks: `organizations.admin_user_id` with status IN (`pending`, `active`, `suspended`)
- Org `archived` is excluded from guardrails (terminal state)
- Tests: `backend/test/fleet.test.ts` (Driver provisioning), `backend/test/admin.test.ts`