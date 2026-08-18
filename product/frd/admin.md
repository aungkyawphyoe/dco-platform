# Admin Module

## Overview

The web portal is the business-side surface for DCO staff. It is not the owner app. Admins sign in with an admin-only role, see counts of users and vehicles, support a user account, and record workshop and insurer partners. Partners do not get a product portal in MVP: no bookings, no claims, no dealer tools.

This module is online-only. It does not use the mobile offline sync engine.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable admins to:

- Sign in securely
- See how many users and vehicles exist
- Find a user and view their profile
- Deactivate or reactivate an account for support
- Create and update workshop and insurer partner records

---

# In Scope

- Admin login (email + password, admin role only)
- Dashboard overview: user count, vehicle count, recent activity
- User management: list, search, view profile, deactivate, reactivate
- Support actions on a user (see Functional Requirements)
- Partner onboarding records: workshops and insurers (name, contact, status, verification)

---

# Out of Scope

- Owner Garage / Maintenance / Documents / Expenses screens on web
- Workshop booking product
- Insurance policy or claims product
- Dealer portal
- Marketplace
- Impersonating a mobile session (optional later)
- Billing / subscription management (plan field is visible, charges are off)
- Push campaigns
- Fleet operator tools

---

# User Personas

- Platform administrator (internal)

Partner personas (Workshop Manager, Insurance Agent) are **records** in this module, not portal users in MVP.

---

# User Stories

### US-ADM-001

As an admin,

I want to sign in with an admin account

So that owners cannot reach this portal.

---

### US-ADM-002

As an admin,

I want a dashboard of users, vehicles, and recent activity

So that I can see if the system is alive.

---

### US-ADM-003

As an admin,

I want to find a user and deactivate the account

So that I can handle abuse or support requests.

---

### US-ADM-004

As an admin,

I want to record a workshop or insurer partner

So that we can onboard them before booking and policy products exist.

---

# Functional Requirements

## Admin login

- Email + password
- Only users with role `admin` may enter
- JWT (or equivalent session) separate from the mobile owner token audience if practical; at minimum role is checked on every admin API
- Logout clears the session

## Dashboard

Show at least

- Total users
- Total vehicles (non-archived)
- Recent activity: last N sign-ups, vehicles added, or sync errors (whichever the API already stores)

No fuel or insurance KPIs.

## User management

List

- Email, name if present, plan field, account status (active / deactivated), created date
- Search by email (and name if stored)

View profile

- Account id, email, verification status, plan, status, created date
- Vehicle count and list of vehicle nicknames / plates (read-only)
- No document file bytes in the default view (avoid unnecessary PII exposure); metadata count is enough

Support actions

- Deactivate: user cannot sign in on mobile; local data remains on device until they sign in again (they cannot)
- Reactivate: sign-in allowed again
- Trigger password-reset email (same flow as Auth)
- Cannot hard-delete a user in MVP (aligns with archive-not-delete)

## Partner onboarding

Entity types: `workshop`, `insurer`

Fields

- Name (required)
- Type (required)
- Contact email
- Contact phone
- Status: draft, pending_verification, verified, rejected
- Notes (internal)

Behavior

- Create, edit, list, search
- Verification is a manual status change by the admin, not an automated KYC product
- Partners cannot sign in to this portal in MVP
- No booking calendar, no policy objects

---

# Business Rules

- Owner accounts never have `admin` unless explicitly granted by an existing admin (seed the first admin out of band)
- Deactivated owners are blocked at Auth
- Plan field is displayed; changing it is allowed for support (billing still off)
- Partner `verified` does not enable marketplace or booking features
- All admin writes are audited with admin user id and timestamp (server log or audit table)

---

# User Flow

Admin login

↓

Dashboard

↓

Users → search → profile → deactivate / reactivate / send reset

or

Partners → create workshop or insurer → set status

---

# Validation Rules

Admin email / password

- Same format rules as `auth.md`

Partner name

- Required
- Maximum 120 characters

Partner type

- Required
- `workshop` or `insurer`

Status

- One of: draft, pending_verification, verified, rejected

---

# Error States

- Non-admin credentials (generic unauthorized; do not reveal that the email exists as an owner)
- User not found
- Partner validation errors
- Network / API errors
- Deactivate of the last remaining admin is rejected

---

# Non-Functional Requirements

- Online-only
- TLS
- Role checks on every endpoint
- Accessible tables and forms
- Minimal PII on lists (email, not documents)
- Load dashboard < 2 seconds for typical MVP data volumes
- Automated tests for role gate, deactivate, and partner status transitions

---

# Analytics

Events

admin_signed_in

admin_user_deactivated

admin_user_reactivated

admin_partner_created

admin_partner_status_changed

---

# Success Metrics

- Partner accounts onboarded (business signal)
- Support deactivation / reactivation volume
- Admin dashboard usage (weekly active admins)

---

# Dependencies

- Backend Auth with roles
- Users API
- Vehicles API (read)
- Partners API
- Email provider (reset)

---

# Future Enhancements

- Workshop booking console
- Insurer policy / claims console
- Dealer portal
- Owner impersonation with audit
- Billing console
- Mileage correction workflow (admin exception to monotonic mileage)
