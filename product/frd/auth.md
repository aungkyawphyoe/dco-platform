# Auth Module

## Overview

Authentication is the account gate for the mobile app and the API. A car owner creates an email-and-password account, verifies the address, signs in, and keeps a session so Garage, Maintenance, Documents, and Expenses work across launches.

This module does not include Google, Apple, or other social login. Those are future enhancements.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable users to:

- Create an account with email and password
- Verify their email
- Sign in and sign out
- Reset a forgotten password
- Stay signed in across app launches until they sign out or the session expires

---

# In Scope

- Email + password signup
- Email verification
- Login and logout
- Password reset
- Session persistence on the device
- JWT access and refresh tokens
- Authenticated route guards on mobile

---

# Out of Scope

- Google / Apple / other OAuth
- Magic links
- Multi-factor authentication
- Passkeys
- Family sharing / multi-driver accounts
- Admin login (see `admin.md`)

---

# User Personas

- Everyday Owner
- Family Manager (own account only; sharing is out of MVP)
- Car Enthusiast

---

# User Stories

### US-AUTH-001

As a new user,

I want to create an account with email and password

So that I can store my vehicle records.

---

### US-AUTH-002

As a user,

I want to verify my email

So that I can recover the account and prove the address is mine.

---

### US-AUTH-003

As a returning user,

I want to sign in and stay signed in

So that I do not re-enter credentials on every launch.

---

### US-AUTH-004

As a user,

I want to reset my password from email

So that I can recover access if I forget it.

---

### US-AUTH-005

As a user,

I want to sign out

So that another person cannot use my session on this device.

---

# Functional Requirements

## Sign up

Required fields

- Email
- Password
- Confirm password

Behavior

- Create the user with plan field `free` (monetization not activated)
- Send a verification email
- On success, establish a session and enter the authenticated app (Garage empty state if no vehicles)
- Show a persistent prompt until email is verified; do not block adding the first vehicle

## Email verification

- Link or code in email marks the account verified
- Resend verification from login and from an in-app prompt (rate-limited)

## Login

Required fields

- Email
- Password

Behavior

- Issue JWT access token and refresh token
- Persist session in secure local storage
- Restore session on cold start if the refresh token is valid
- Unverified users may sign in; verification prompt remains

## Logout

- Invalidate the local session
- Discard tokens from secure storage
- Return to the login screen
- Queued offline writes remain on device until a later sign-in of the same account (see `sync.md`)

## Password reset

- User submits email from "Forgot password"
- If the email exists, send a reset link; always show a generic success message
- New password must meet the same rules as signup
- After reset, existing refresh tokens for that user are revoked

## Route guards

- Unauthenticated users only see welcome, login, signup, and password-reset screens
- Authenticated users cannot open those screens without signing out

---

# Business Rules

- Email is unique and stored lowercase
- One person has one user account in MVP
- Plan field exists (`free` / `premium`) but billing is off
- Access token is short-lived; refresh token is longer-lived and rotated on use
- Failed login attempts are rate-limited on the server

---

# User Flow

Welcome

↓

Create account or Sign in

↓

Email + password

↓

Session established

↓

Garage / Dashboard

---

Password reset

↓

Email submitted

↓

Open reset link

↓

Set new password

↓

Sign in

---

# Validation Rules

Email

- Required
- Valid email format
- Maximum 254 characters

Password

- Required
- Minimum 8 characters
- Confirm password must match on signup and reset

---

# Error States

- Email already registered
- Invalid credentials
- Unverified email (warning, not a hard block after signup)
- Verification link expired or already used
- Reset link expired or already used
- Network failure on signup/login (retry; no local account without a server user)
- Session expired (refresh failed → login)
- Rate limit exceeded

---

# Non-Functional Requirements

- Tokens in secure local storage (Keychain / Keystore)
- TLS for all auth API calls
- Auth screens work only while online; after a session exists, other modules are offline-first
- Load time < 2 seconds for login and signup screens on a mid-range device
- Accessible forms (labels, errors, password visibility toggle)
- Automated tests for uniqueness, password rules, and refresh failure

---

# Analytics

Events

auth_signed_up

auth_signed_in

auth_signed_out

auth_password_reset_requested

auth_email_verified

---

# Success Metrics

- Accounts created
- Accounts with verified email
- Sign-in success rate
- Week-1 retention of created accounts

---

# Dependencies

- Backend Auth API (JWT issue / refresh)
- Email provider for verification and reset
- Secure local storage
- Sync Engine (after session exists)
- Garage (first-run destination)

---

# Future Enhancements

- Google and Apple sign-in
- Magic link
- Multi-factor authentication
- Passkeys
- Device session list and remote revoke
