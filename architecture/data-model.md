# Data model / ERD (MVP)

**Status:** Binding. Honor `product/mvp-scope.md` business rules.  
**Compare target:** Autozis demo + public feature list (`https://autozis.com/`, `/app/dashboard`, `/app/garage`, `/app/expenses`).

Client IDs are UUID v4 generated on device so retries are idempotent. Server `user.id` and `plan` are authoritative.

---

## Canonical ERD

```mermaid
erDiagram
  users ||--o{ vehicles : owns
  users ||--o{ refresh_tokens : has
  users ||--o{ device_tokens : registers
  users ||--o{ notification_feed : receives
  users ||--o{ fuel_types : catalog
  users {
    uuid id PK
    string email UK
    string password_hash
    string display_name
    uuid profile_photo_media_id FK
    string contact_phone
    string address
    enum role
    enum plan
    enum status
    bool email_verified
    uuid active_vehicle_id FK
    timestamptz created_at
  }

  vehicles ||--o{ plan_items : schedules
  vehicles ||--o{ service_records : history
  vehicles ||--o{ documents : vault
  vehicles ||--o{ expenses : costs
  vehicles ||--o{ parts : catalog
  expenses ||--o{ expense_parts : uses
  parts ||--o{ expense_parts : assigned_on
  vehicles ||--o{ fuel_logs : energy
  vehicles ||--o{ notification_feed : alerts
  vehicles {
    uuid id PK
    uuid user_id FK
    string name
    string nickname
    string make
    string model
    int year
    string license_plate
    string vin
    string color
    enum fuel_type
    decimal mileage
    enum mileage_unit
    date purchase_date
    decimal purchase_price
    uuid photo_media_id FK
    bool archived
    timestamptz archived_at
    timestamptz updated_at
  }

  plan_items ||--o{ service_record_items : completed_by
  plan_items {
    uuid id PK
    uuid vehicle_id FK
    string name
    int interval_days
    decimal interval_distance
    decimal next_due_mileage
    date next_due_on
    bool enabled
    string notes
    string catalog_key
  }

  service_records ||--|{ service_record_items : contains
  service_records ||--o{ service_record_parts : uses
  parts ||--o{ service_record_parts : assigned_on
  service_records {
    uuid id PK
    uuid vehicle_id FK
    date serviced_on
    decimal odometer
    decimal total_cost
    string workshop_name
    string notes
    uuid receipt_media_id FK
  }

  service_record_items {
    uuid id PK
    uuid service_record_id FK
    uuid plan_item_id FK
    string name
    decimal line_cost
  }

  parts {
    uuid id PK
    uuid vehicle_id FK
    string name
    string brand
    string part_number
    string notes
  }

  service_record_parts {
    uuid id PK
    uuid service_record_id FK
    uuid part_id FK
    string name
  }

  fuel_types {
    uuid id PK
    uuid user_id FK
    string name
    enum kind
    string unit
  }

  fuel_types ||--o{ fuel_logs : used_on
  fuel_logs {
    uuid id PK
    uuid user_id FK
    uuid vehicle_id FK
    enum kind
    uuid fuel_type_id FK
    string fuel_type_name
    string unit
    date logged_on
    decimal amount
    decimal cost
    decimal odometer
  }

  documents {
    uuid id PK
    uuid vehicle_id FK
    string name
    enum category
    date expires_on
    string notes
    uuid media_id FK
  }

  expenses {
    uuid id PK
    uuid vehicle_id FK
    enum category
    decimal amount
    date incurred_on
    string notes
    uuid receipt_media_id FK
  }

  expense_parts {
    uuid id PK
    uuid expense_id FK
    uuid part_id FK
    string name
  }

  media_objects {
    uuid id PK
    uuid user_id FK
    string blob_key
    string content_type
    int byte_size
    string sha256
  }

  partners {
    uuid id PK
    string name
    enum type
    enum status
    string contact_email
    string contact_phone
    string notes
  }

  change_log {
    bigint seq PK
    uuid user_id FK
    string entity_type
    uuid entity_id
    enum op
    jsonb payload
    timestamptz server_ts
  }

  audit_events {
    bigint id PK
    uuid admin_user_id FK
    string action
    jsonb detail
    timestamptz at
  }

  users ||--o{ vehicle_shares : receives
  users ||--o{ vehicle_shares : grants
  vehicles ||--o{ vehicle_shares : shared_on
  users ||--o{ vehicle_share_invitations : sends
  vehicles ||--o{ vehicle_share_invitations : invites_on
  users ||--|| driving_licenses : has
  driving_licenses }|--|| media_objects : front_photo
  driving_licenses }|--|| media_objects : back_photo

  vehicle_shares {
    uuid id PK
    uuid vehicle_id FK
    uuid user_id FK
    uuid granted_by FK
    enum access_level
    enum status
    string invited_email
    string share_code UK
    jsonb qr_code_data
    timestamptz accepted_at
    timestamptz created_at
  }

  vehicle_share_invitations {
    uuid id PK
    uuid vehicle_id FK
    uuid invited_by FK
    string invited_email
    enum access_level
    string token UK
    string share_code UK
    timestamptz expires_at
    timestamptz created_at
    timestamptz accepted_at
    uuid accepted_by FK
  }

  driving_licenses {
    uuid id PK
    uuid user_id FK UK
    string license_number
    string issuing_country
    date expiry_date
    string categories
    uuid front_media_id FK
    uuid back_media_id FK
    timestamptz created_at
    timestamptz updated_at
  }
```

Local-only (mobile, not a server table): **outbox** rows (`entity_type`, `entity_id`, `op`, `payload`, `client_ts`, `attempt_count`). Server equivalent is `change_log` plus ordinary CRUD.

---

## Tables and rules

### users

| Field | Rule |
|-------|------|
| `email` | Unique, stored lowercase, max 254 |
| `role` | `owner` (default on signup) or `admin` (granted by an existing admin / seed) |
| `plan` | `free` \| `lite` \| `standard` \| `fleet` (per `docs/pricing.md`), AutoX-admin-managed until billing is added. Sizes Vehicle Sharing caps (free 1, lite 3, standard/fleet unlimited — one cap for per-vehicle and total) and the advisory `vehicle_limit` (1 / 3 / 10 / null). Anyone can share and accept shares; vehicle-count enforcement lands with the server limit checks (`architecture/feature-gating.md` PR3). |
| `status` | `active` \| `deactivated`. Deactivated cannot sign in |
| `active_vehicle_id` | Null only when the garage is empty. After the first vehicle, always one active vehicle |
| `email_verified` | Prompt until true; does not block adding a vehicle |
| `profile_photo_media_id` | Nullable FK to `media_objects`. Profile photo follows existing media pipeline. |
| `contact_phone` | Optional. Max 20 chars. Free-form text. |
| `address` | Optional. Max 500 chars. Free-form text. |

### vehicles

| Field | Rule |
|-------|------|
| `license_plate` | Required, max 20, **unique per `user_id`** among non-archived rows |
| `vin` | Optional; if set, exactly 17 chars; **globally unique** among non-archived vehicles |
| `fuel_type` | Required: `petrol` \| `electric` \| `hybrid_plugin` |
| `year` | 1900 … current year + 1 |
| `mileage` | Required, ≥ 0. **Must not decrease** (higher value wins on sync) |
| `archived` | Soft-delete. Child rows stay; they disappear from owner lists with the vehicle |

Suggested maintenance catalog is **not** a table of user data. It is seed/config keyed by `fuel_type` (see Garage / Maintenance FRDs). Copying a suggestion into `plan_items` stores `catalog_key` for analytics; the row is then user-owned.

### plan_items / service_records

- A plan item needs a time interval, a distance interval, or both.
- Service odometer ≥ vehicle mileage; if greater, bump `vehicles.mileage`.
- Completing a service may clear matching plan dues and set the next due from intervals.
- Line items optional `plan_item_id`. Total cost ≥ 0; may override the sum of lines.
- `service_record_parts.part_id` is **nullable** (Oct 2026): parts may be free-text names without a `parts` catalog row (fleet work-order completion, driver logs).
- **Fleet (Oct 2026, second grilling):** drivers write service records through `POST /drivers/vehicles/:id/service-records` (do-myself) — same table, plan-linked or free-text; work-order completion auto-creates a service record at the **report-time odometer** (`work_orders.plan_item_id` links the WO and advances the plan item on completion). Personal-garage service-record routes stay owner-only and 403 driver identities.

### documents / expenses

- One primary file per document (`media_objects`).
- Document categories: `insurance` \| `registration` \| `invoice` \| `warranty` \| `receipt` \| `other`.
- `documents.expires_on` optional expiry date (ISO `YYYY-MM-DD`); drives the Vehicle Detail "License Due" tile for `registration` documents.
- Expense categories: `fuel` \| `maintenance` \| `insurance` \| `parking` \| `tolls` \| `parts` \| `other`.
- Expense `fuel` is **money only** (no litres, no kWh). Volume and kWh live on `fuel_logs`. Expense `maintenance` does **not** auto-create from service records. Dashboard totals read **expenses only**.
- Assigned parts on an expense snapshot `name` on `expense_parts` so later catalog edits do not rewrite history.

### fuel_types / fuel_logs

- `fuel_types.kind`: `liquid` \| `electric`. Unique `name` per `user_id` (case-insensitive).
- `fuel_logs.kind`: `refuel` \| `charge`. Petrol and hybrid plugin vehicles write `refuel`; electric vehicles write `charge`.
- Amount is litres/gallons or kWh from the catalog type's `unit`. Name and unit are snapshotted on the log.
- `fuel_logs.odometer` is **optional**, in the vehicle's `mileage_unit`. When set: ≥ vehicle mileage; if greater, bump `vehicles.mileage` (same rule as service odometer). It feeds distance/consumption KPIs in `product/frd/stats.md`. Still do not copy Autozis partial/full tank or cost-per-unit fields.

### vehicle_shares / vehicle_share_invitations

Schema detail, access matrix, and query patterns: [`architecture/data-model-vehicle-sharing.md`](data-model-vehicle-sharing.md).

- There is **no family/group entity**. Access is granted per vehicle, one row per `(vehicle_id, user_id)`.
- `access_level`: `view` (read-only) or `add_edit_own` (read + create, editing/deleting only rows
  the writer created; vehicle identity, maintenance plan items, and shares stay owner-only).
  Records carry `created_by` (`fuel_logs.user_id`) so authorship is enforceable.
- `status`: `pending` (email invited, not yet accepted) → `active` → `revoked` (row deleted, not kept).
- Two ways in: `POST /v1/vehicles/:id/shares` with `method: code_qr` (8-char code, 7-day expiry, stored on `vehicle_share_invitations.share_code`) or `method: email` (random token, 7-day expiry, emailed link).
- `vehicle_share_invitations` is the invite ledger; `vehicle_shares` is the access ledger. Both are needed because a code/QR invite has no addressee.
- `users.family_id` was dropped in `backend/drizzle/0008_vehicle_sharing.sql`, which also converts legacy `vehicle_grants` and `family_vehicles` rows into `vehicle_shares`.
- `driving_licenses` is a **standalone** per-user module, unrelated to sharing; it stays even though the family tables were removed.

### change_log

- Append-only. Cursor is opaque (`seq` encoded, not invented by clients).
- Entity types: `user`, `vehicle`, `plan_item`, `service_record`, `document`, `expense`, `notification`, `media`, `part`, `fuel_type`, `fuel_log`, `vehicle_share`, `driving_license`. Vehicle rows and their history are fanned out to the vehicle's **change audience** — the owner plus every user holding an active share.
- Duplicate create with the same client UUID → idempotent success.
- Archive vs later edit: **archive wins**.

### partners / audit_events

- Partner types: `workshop` \| `insurer`. Status: `draft` \| `pending_verification` \| `verified` \| `rejected`.
- Partners cannot sign in. `verified` does not unlock booking.
- Every admin write gets an `audit_events` row.

### Enterprise Fleet backend extension

Fleet entitlement is **organization-scoped**, not a `users.plan` value or `users.role`. The schema added by `backend/drizzle/0003_fleet_foundation.sql` keeps personal ownership on `vehicles.user_id` and links managed inventory through `organization_vehicles`.

| Entity | Key fields and constraints |
|--------|----------------------------|
| `organizations` | `type` (showroom/dealership/taxi_fleet/rental/commercial/logistics), `plan=enterprise`, `status` (pending/active/suspended/archived), linked `admin_user_id`, created/activated audit fields, contacts, settings. One non-archived organization per Org Admin. |
| `organization_members` | `org_id`, `user_id`, role (`org_admin`/`org_manager`/`org_mechanic`/`org_driver`), inviter and join time. One organization per user; one Org Admin per org. |
| `organization_vehicles` | Organization ↔ existing `vehicles` link, lifecycle template/state, revenue label. One organization per vehicle. Fleet vehicles are excluded from personal-owner vehicle routes while linked. |
| `driver_assignments` | Organization, vehicle, driver, assigning user, active/completed timestamps. Many-to-many access: multiple vehicles per Driver and multiple Drivers per vehicle. Only the same organization/Driver/vehicle tuple must be unique while active; historical assignments remain. |
| `work_orders` | Organization/vehicle, reporting driver, odometer, issue, urgency, photos, status, assignee and resolution fields, optional **`plan_item_id`** and **`completion_cost`** (Oct 2026). Completion (admin/manager) auto-creates a service record at the report-time odometer and advances the linked plan item. Driver visibility is own-only; managers can review fleet-wide. |
| `inspections` / `inspection_templates` | Organization-scoped checklist definitions and submitted results. Required items must be answered; a `not_ok` result creates a work order. |
| ~~`shift_mileage`~~ | **Removed (Oct 2026, second grilling)** — shift start/end capture retired; vehicle mileage is log-driven only (service records + fuel logs). Table and routes dropped. |
| `warranty_templates` / `vehicle_warranties` | Organization template terms and per-vehicle time/mileage limits, created on showroom transfer when selected. |
| `warranty_template_workshops` | Template ↔ approved workshop partner link. Only workshops on this list may log warranty service for vehicles using the template. |
| `organization_workshops` | Organization ↔ verified workshop partner approval list. Warranty templates may only reference workshops approved here; removal also clears the partner from the org's templates. |
| `workshop_members` | Workshop partner ↔ user account link, created by AutoX Admin for verified workshop partners. One workshop per user. Workshop sign-in uses the `dco-workshop` audience. |
| `transferred_vehicles` | Read-only organization audit row linking vehicle, buyer, transfer actor/time, and optional warranty instance. `vehicles.user_id` changes to the buyer. |
| `vehicle_import_jobs` | Persistent CSV import status/results, limited to 100 rows per job and polled by job ID. |
| `vehicles.vehicle_class` | `car` \| `motorcycle` \| `truck` \| `van` \| `bus`, default `car` (`backend/drizzle/0013_maintenance_catalog_fleet.sql`). Primary dimension for maintenance-template matching; synced through the normal vehicle outbox path. |
| `maintenance_catalog` (fleet extension) | Same table gains `vehicle_class` (default `car`), optional `lifecycle_template` narrowing, and nullable `org_id` (NULL = platform-seeded global row; non-NULL = org copy created in the Fleet Portal). Indexes on `vehicle_class` and `org_id`. 47 global rows seeded (11 car + 10 motorcycle + 14 truck + 12 van). |
| `organization_vehicles.maintenance_template_class` | Assigned **vehicle class** string (replaced the `maintenance_template_id` anchor FK in `backend/drizzle/0021_maintenance_template_class.sql`). The effective template set is computed, not stored: enabled rows (global + org copies) matching the vehicle's class + lifecycle + fuel, deduped case-insensitively by name with the **org copy winning**. Fleet Portal generates a one-time plan snapshot from a selected subset of the set into `plan_items`; drivers can additionally add items from the set's suggested list (`product/frd/fleet-maintenance-templates.md`). |

**Identity extension (Oct 2026 alignment — specified, pending migration):**

| Change | Rule |
|--------|------|
| `users.username` | New column, globally unique, NOT NULL after backfill (email local part; collisions suffixed `_2`, `_3`, …). Login accepts email or username. |
| `users.email` | Nullable (identity flexibility for backfill; **driver accounts are email-bearing** — created on the Fleet Portal Members page by email, and creation rejects emails already held by existing accounts, so a driver identity is always new; second grilling Oct 2026). Existing UNIQUE constraint is kept — Postgres treats NULLs as distinct. Customer signup still requires email at the API layer. |
| `users.must_change_password` | Boolean, default false. Set on temp-password accounts (Fleet Admin provisioning, driver creation, admin password reset). Enforced server-side: fleet/driver routes except profile/password return 403 `password_change_required`. |
| `users.status` | `deactivated` reused for driver soft delete by the Fleet Admin: login blocked, active `driver_assignments` cascaded to `completed` + `unassigned_at`, history rows retained, reactivation allowed, username never freed. |

Authorization checks run against the live database for each request: Fleet requires Enterprise plan + active organization + membership; role controls each operation. Fleet Dashboard tokens use `dco-fleet`, mobile remains `dco-owner`, and verified workshop accounts use `dco-workshop` (scoped to active approved-warranty vehicles only; buyer personal data is not exposed). `plan` changes only resizing limits: downgrading from Premium does not revoke existing shares, but new shares are refused while the owner is over the free-plan caps.

---

## Mileage monotonicity

1. Create vehicle: mileage required.
2. Edit vehicle mileage, log a service odometer, or save a fuel log odometer: reject if new value < stored mileage (`409` / validation error). Admin correction workflow is **out of MVP**.
3. Sync conflict: `max(local, remote)` wins. Never apply a remote mileage lower than local.
4. Dashboard and garage cards display the stored mileage, not a trip log (no trips table).

---

## Archive rules

| Action | Effect |
|--------|--------|
| Archive vehicle | `archived=true`, `archived_at` set. Cancel local notifications. Hide from garage and dashboard switcher. Keep all child rows. |
| Un-archive | Not in MVP UI. Do not resurrect from an older outbox edit if archive already applied. |
| Delete document / expense | Hard-delete that row + queue remote delete + delete media. Not the same as vehicle archive. |
| Delete user | **Soft-delete** (deactivate). Vehicles archived; shares where they are the grantee or grantor are deleted. Admin can reactivate. |
| Logout | Tokens discarded. Outbox remains encrypted, bound to `user_id`. |

---

## Comparison with Autozis

Observed in the Autozis demo (Toyota Camry dashboard, multi-vehicle garage, expenses form) and [features](https://autozis.com/features):

| Autozis | AutoX MVP | Decision |
|---------|---------|----------|
| Multi-vehicle garage, photo, make/model, mileage, purchase date | Same core + plate uniqueness, VIN rule, fuel type enum, nickname, archive | **Adopt** (with AutoX rules) |
| Dashboard: vehicle health, mileage, next event, cost KPIs, needs-attention, recent activity | Dashboard for **active vehicle**: identity, ownership summary (spend + counts), 3 maintenance rows, next plan item | **Adopt shape, shrink metrics** — no refuel €, L/100km, insurance expiry module |
| Maintenance plan + reminders (time and/or mileage) + service history | Same | **Adopt** |
| Refuel / charge logs (date, type, amount, cost) | `fuel_types` catalog + `fuel_logs` | **Adopt simplified** — no efficiency KPIs at MVP; optional odometer + KPIs later via `stats.md` |
| Insurance **tracker** (policy, renew, expiry) | Document category + expense category | **Defer** policy object |
| Trips / mileage logbook | Mileage on vehicle + service odometer only | **Defer** |
| Notes, catalogs (expense types, locations) as first-class screens | Fuel Types catalog only; other catalogs deferred | **Adopt Fuel Types**; defer the rest |
| Parts catalog (name, brand, number) assigned on service / expense | Per-vehicle parts + service assignment | **Adopt** (expense assignment with the expenses form) |
| Documents with multiple attachments, notes | One file per document | **Adopt simplified** |
| Receipt scanning / OCR ("Load from Receipt") | Attach photo, no extract | **Defer** |
| Vehicle sharing | Per-vehicle shares via 8-char Code/QR or email invitation (`vehicle_shares`), access `view` \| `add_edit_own` | **Adopt simplified** — no household/group entity |
| Import/export, PDF reports, AI assistant | — | **Defer** |
| Online web owner app, instant sync | Flutter offline-first + change log | **Different architecture** (intentional) |
| No staff admin | Users + partners + audit | **AutoX-only** |
| Freemium (advanced features gated) | `plan` field sizes Vehicle Sharing limits; no billing yet; vehicle-count gate remains off | **Adopt plan + share-limit gate** |

Do not add Autozis tables (`trips`, `policies`, `notes`, `expense_types`) to this schema. Fuel logs are a AutoX slice (`fuel_types`, `fuel_logs`), not Autozis efficiency tracking.

---

## Freemium field

`users.plan` is `free` / `lite` / `standard` / `fleet`. `vehicle_limit` on `GET /v1/me` is advisory (free 1, lite 3, standard 10, null = unlimited); enforcement lands with the server limit checks (`architecture/feature-gating.md` PR3).

Plan limits are enforced per owner, not per vehicle alone: `checkShareLimits` refuses a share when the owner already holds `shareLimits[plan]` active shares on that vehicle, or that many across all vehicles. The limits live in one place — `backend/src/lib/plans.ts`, mirrored by the `plans` table — so there is nothing to keep in step.

## Document storage ownership (migration 0023)

`media_objects.vehicle_id` scopes vehicle uploads. `owner_org_id` selects the fleet storage pool; when null, `user_id` selects the personal pool. For organization uploads, `user_id` retains the uploader identity. Vehicle scope is immutable through upload retries. Existing document/service/expense references are backfilled during migration.

Storage usage sums stored primary-file bytes, excluding `vehicle_photo` and `profile_photo`. Upload admission locks the owning user or organization row until the direct upload and media-row insert complete; retries reuse the media UUID. Current direct uploads do not issue presigned upload reservations.

`media_cleanup` holds media IDs awaiting object deletion. Document removal schedules cleanup; failed deletion keeps the media row charged. Storage refresh retries scoped cleanup, deleting the usage row only after object deletion succeeds. This queue is separate from user-visible Trash, which is not supported.

Full attachment-link and replacement lifecycle implementation remains tracked in [Document storage implementation](../product/frd/document-storage-implementation.md).


## Reusable document links (migration 0024)

`document_links` associates an ordinary document with a service record or fuel log. Exactly one target is required per row; duplicate document/target pairs are prohibited. Both sides use cascading foreign keys: deleting a log removes only its links, while deleting a document removes all its links. Stored bytes remain on the document's single media object.

Document API/sync payloads include `links: [{kind, record_id}]`. Omitted links preserve existing associations; an explicit empty array unlinks all targets after permission checks. Cross-vehicle links are rejected. Organization link changes feed the existing organization change stream. Legacy service receipts are attached once during migration, without copying bytes.

Mobile schema 24 persists the link list as JSON on its document rows. Saving a service/fuel form and its document/outbox writes uses one local transaction. Deleting a log removes its cached and queued link references, preserving document rows and local files.
