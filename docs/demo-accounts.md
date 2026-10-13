# Demo Accounts & Admin Account Controls (Demo Period)

Status: active during the **demo period only**. Revisit before production launch.

This document covers:

1. The DCO Admin full account-control surface (create / read / update / delete + verification bypass)
2. Known demo accounts across all surfaces
3. How to create, reset, and recover demo accounts

## 1. Admin full account control

The DCO Admin portal (`web/`, JWT audience `dco-admin`) has complete account CRUD plus demo-period access-control overrides. All actions are audit-logged (`user.*` audit events).

### Capabilities

| Capability | Backend endpoint | Web admin UI |
|---|---|---|
| List users (search, status filter) | `GET /admin/users` | Users list |
| User detail | `GET /admin/users/:id` | User profile page |
| Create user (temp password, role, plan) | `POST /admin/users` | Users → New user |
| Change plan | `PATCH /admin/users/:id` | User profile → Actions |
| Change account role (owner/admin) | `PATCH /admin/users/:id` | User profile → Actions |
| Edit profile (name, phone, address) | `PATCH /admin/users/:id/profile` | User profile → Edit profile |
| Deactivate / reactivate | `POST /admin/users/:id/deactivate` · `/reactivate` | User profile → Actions |
| Soft delete (archives vehicles, revokes shares) | `POST /admin/users/:id/delete` | User profile → Actions |
| Send password-reset email | `POST /admin/users/:id/send-password-reset` | User profile → Actions |
| **Bypass: mark email verified** | `PATCH /admin/users/:id/access` `{ "email_verified": true }` | User profile → Account access |
| **Bypass: clear must-change-password** | `PATCH /admin/users/:id/access` `{ "must_change_password": false }` | User profile → Account access |
| **Set password directly** (no email) | `PATCH /admin/users/:id/access` `{ "password": "..." }` | User profile → Account access → Set password |
| Create org driver (username + temp password) | `POST /admin/organizations/:id/drivers` | Organization detail → Drivers |
| Driver activate/deactivate | `PATCH /admin/organizations/:id/drivers/:userId/status` | Organization detail → Drivers |

### Verification bypass policy (demo period)

Email verification is **not** enforced at login. It only gates vehicle sharing when `AUTH_CODES_ENABLED=on`, and first-password setup for invited accounts. During the demo:

- Admin-created users are created with `email_verified: false` and `must_change_password: true`.
- Use **Mark email verified** and **Clear requirement** on the user profile page to bypass these without email delivery.
- Use **Set password** to give an account a known password without needing a working mail provider (all existing sessions are revoked; share the password out-of-band).

These overrides are intended for demo/support use. Before production, decide whether to keep them as permanent support tooling or restrict them behind a separate permission.

### Guards that still apply

- Cannot deactivate/delete yourself; cannot delete the last admin.
- Cannot demote the last admin (`last_admin`).
- Cannot deactivate a user who administers a pending/active/suspended organization (archive the org first).

## 2. Demo accounts

Credentials below are seeded by code or scripts in this repo. Passwords are demo-only — never reuse them outside the demo environment.

| Surface | Account | Password | Role / access | How it's created |
|---|---|---|---|---|
| Web Admin (`web/`, `dco-admin`) | `BOOTSTRAP_ADMIN_EMAIL` (default `admin@example.com`) | `BOOTSTRAP_ADMIN_PASSWORD` env | Platform admin | `backend/src/lib/bootstrap.ts` on first boot |
| Owner app / mobile (`dco-owner`) | `customer1@example.com` | `password123` | Free owner + seeded vehicles/expenses | `POST /admin/reset-users` seed (see §3) |
| Owner app / mobile (`dco-owner`) | `customer2@example.com` | `password123` | Free owner | `POST /admin/reset-users` seed |
| Fleet Portal (`fleet-portal/`, `dco-fleet`) | `fleet@example.com` | `password123` | Org admin of seeded Enterprise org | `POST /admin/reset-users` seed |
| Fleet Portal (local dev) | `orgadmin@example.com` | `OrgAdmin123!` | Org admin of "Acme Motors" | `backend`: `npm run seed:org` |
| Fleet driver (mobile) | `driver@example.com` (or `--email`) | as passed to `seed:org` | `org_driver` | `npm run seed:org -- --role org_driver …` |
| DCO Admin (this environment) | `dcomotor@gmail.com` | **unknown** — reset via §3 | Org admin of active Enterprise org | Provisioned via Web Admin |

### Known issue: invite-created org admins

Org admins created through organization provisioning (`POST /admin/organizations`) are created via `createInvitedOwnerAccount` with a **random password** plus a mailed reset link (`backend/src/lib/account-invites.ts`). If mail delivery is not configured (e.g. `MAIL_PROVIDER=stdout`), the password is unusable. Recover such accounts with **Set password** in the admin UI (or the `PATCH /admin/users/:id/access` endpoint).

## 3. Creating and resetting demo accounts

### Fastest: admin UI (recommended during demo)

1. Sign in to Web Admin as the bootstrap admin.
2. **Create**: Users → New user (email + temporary password + role/plan).
3. **Fix access**: open the user → Account access → Mark email verified / Clear requirement / Set password.
4. **Org + fleet access**: Organizations → New organization (provisions an Enterprise org with an Org Admin), activate it, then sign in on the Fleet Portal with that admin account (use Set password first if the invite email never arrived).

### Nuclear: reset-users endpoint (demo only)

`backend/src/modules/admin.ts` exposes a **temporary public** endpoint that wipes user data and reseeds the three demo accounts above:

```bash
curl -X POST "$API_BASE/v1/admin/reset-users" \
  -H "x-reset-secret: reset-users-2024"
```

- Destructive: clears vehicles, expenses, maintenance, org, share, and related tables before reseeding.
- Guarded only by a hardcoded header secret — **remove this endpoint before any production deployment**.

### Local development

```bash
cd backend
npm run seed:org                                          # orgadmin@example.com / OrgAdmin123!
npm run seed:org -- --email driver@example.com --role org_driver
```

## 4. Before production — cleanup checklist

- [x] Backend `v1.8.0` deployed (2026-10-13) with `PATCH /admin/users/:id/access` — Set password / Mark verified / Clear requirement available in Web Admin; `PUBLIC_API_URL` set to `https://api.autoxmm.com/v1`; CORS includes `www.autoxmm.com`.
- [ ] Remove `POST /admin/reset-users` from `backend/src/modules/admin.ts` (and `backend/reset_users.js`).
- [ ] Decide policy for the `PATCH /admin/users/:id/access` overrides (keep as restricted support tooling vs. remove).
- [ ] Rotate all demo passwords; do not carry `password123` accounts into production.
- [ ] Enable Azure Communication Services mail (`MAIL_PROVIDER=acs` — see `docs/deployment.md` §Email) so invite/reset emails work without the Set-password bypass. Current env is `MAIL_PROVIDER=stdout` (emails only print to container logs).
- [ ] Set strong `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD` and complete first-login hardening.
