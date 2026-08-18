# Sync Module

## Overview

Sync is the offline-first engine. The owner can create and edit Garage, Maintenance, Documents, and Expenses data with no network. Changes queue locally and replicate to the REST API when a connection exists. The server holds the durable copy; the device holds a full working copy.

Sync is not "cloud backup" as a user-facing product. There is no separate backup toggle, restore-from-cloud screen, or extra-device backup SKU in MVP. Those are v1.1. This module is the change-log and conflict path that must never drop user data.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable the product to:

- Accept writes while offline
- Push queued changes when online
- Pull remote changes onto the device
- Resolve conflicts without silent data loss
- Retry after failures

---

# In Scope

- Local Drift/SQLite as the working database
- Outbox / change queue for creates, updates, deletes (including archive)
- Bidirectional change-log API
- Automatic sync on app start, on reconnect, and after local writes (debounced)
- Conflict handling
- Retry with backoff
- Sync status for the user (idle, syncing, offline queued, failed)
- Auth token refresh during sync
- Media upload/download queue for photos, PDFs, receipts

---

# Out of Scope

- User-facing "Cloud backup" product and restore wizard
- Selective sync / per-module opt-out
- Multi-device real-time collaboration
- End-to-end encryption of the change log
- Sync of Admin portal data to mobile
- Push campaigns

---

# User Personas

- Everyday Owner
- Family Manager
- Car Enthusiast

(All owner personas. Admins use the online web portal and do not use this engine.)

---

# User Stories

### US-SYNC-001

As a user,

I want to add a service or expense without signal

So that I can log at the workshop.

---

### US-SYNC-002

As a user,

I want my phone to send those records later

So that I do not re-enter them.

---

### US-SYNC-003

As a user,

I want to know if sync failed

So that I can retry rather than assume the server has my data.

---

# Functional Requirements

## Local writes

- Every in-scope entity (vehicle, plan item, service record, document metadata, expense, reminder state) is written locally first
- Each write appends an outbox entry with entity type, id, operation, payload, client timestamp, and attempt count
- UI reads only from the local database

## Push

- When online, drain the outbox in order per entity
- On 401, refresh JWT once and retry
- On 409 conflict, apply the conflict policy below, then continue
- On 5xx or timeout, backoff and keep the outbox row
- Media bytes upload after metadata is accepted, or in the same transaction if the API supports it; if metadata succeeds and bytes fail, retry bytes without duplicating the record

## Pull

- Change-log API: client sends last-seen server cursor
- Server returns records newer than the cursor for this user
- Apply remote creates/updates/archives to local DB
- Do not apply a remote mileage that is lower than local mileage (see conflicts)

## Triggers

- App foreground / cold start (after auth)
- Network reaches connected
- After a local write (debounce ~1s)
- Manual retry from the failed state

## Status

Show a compact indicator:

- Offline, N changes queued
- Syncing
- Up to date
- Sync failed — tap to retry

Do not block navigation because sync is running.

## Multi-device

MVP supports one account on more than one device via the same change log. There is no live presence. Last writer (see conflicts) wins except mileage.

---

# Business Rules

## Conflict policy

- **Mileage / odometer:** the higher value wins. Never decrease.
- **Archive vs edit:** archive wins; do not resurrect an archived vehicle from an older edit
- **All other fields:** last-write-wins using server-accepted timestamp; keep the discarded payload in a conflict log for support (not a user UI in MVP)
- **Duplicate create with the same client id:** treat as idempotent success

## Identity

- Client generates stable UUIDs for new records so retries do not duplicate
- Server is authoritative for the user's account id and the plan field

## Auth

- Sync never runs without a valid session
- After logout, outbox stays on device encrypted at rest, bound to that user id; a different account on the same device does not push the previous outbox

---

# User Flow

Local write (any owner module)

↓

Outbox row

↓

Online? → push then pull → cursor advanced

↓

Offline? → stay queued → retry on reconnect

↓

Conflict → apply policy → continue

↓

Failure → status "failed" → retry

---

# Validation Rules

- Outbox payload must include entity type, entity id, and operation
- Pull cursor is an opaque server string; clients must not invent one
- Maximum outbox payload size follows API limits; oversize media is rejected before queueing with the same errors as Documents/Expenses

---

# Error States

- Offline queued (expected)
- Auth expired and refresh failed → session expired, stop sync, send to login; keep outbox
- Conflict applied (silent except support log)
- Media upload failed, metadata saved (retry media)
- Server unreachable
- Sync cursor rejected (full snapshot fetch once, then resume)

Never show a generic "save failed" for a successful local write.

---

# Non-Functional Requirements

- Offline-first for all owner write modules
- Automatic retry
- Does not block UI thread; sync on a background isolate/queue
- < 2-second local read even while syncing
- Secure storage of tokens and outbox
- Automated tests for mileage conflict, idempotent create, and retry after 500
- Versioned change-log endpoints

---

# Analytics

Events

sync_completed

sync_failed

sync_conflict_resolved

---

# Success Metrics

- Sync success rate
- Median time queued change waits before ack
- Share of sessions that complete a pull
- Zero confirmed silent data loss incidents

---

# Dependencies

- Authentication (JWT refresh)
- Local Database (Drift/SQLite)
- Backend change-log API
- Media Storage
- Garage, Maintenance, Documents, Expenses (producers/consumers)

---

# Future Enhancements

- User-facing cloud backup and restore
- Per-field merge UI
- End-to-end encryption
- Selective media download
- Real-time sync
