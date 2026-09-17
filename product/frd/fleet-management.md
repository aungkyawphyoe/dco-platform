# Fleet Management Module

## Overview

Fleet Management enables **business accounts** (showrooms, dealerships, small fleets) to manage multiple vehicles under an organization, track warranty periods with approved workshops, and transfer vehicle ownership to buyers with full maintenance history. Organizations are created exclusively by DCO administrators via the Admin Portal (sales-led onboarding). This module extends the existing single-owner model to support multi-vehicle business operations with role-based access, warranty enforcement, and ownership transfer.

**Status:** Planned (Phase 3, Year 2).  
**Contract:** This FRD extends `product/mvp-scope.md` and `architecture/iam.md`.  
**Surfaces:** Mobile (Flutter — org members, buyers, workshops), Backend (REST API), Web Admin (Next.js — org creation and management for DCO staff).

---

## Objectives

Enable organizations to:

- Be created by DCO administrators via the Admin Portal (sales-led onboarding)
- Manage vehicle inventory through lifecycle states (inventory → listed → reserved → sold)
- Configure warranty templates (duration + mileage + approved workshops)
- Transfer vehicle ownership to buyers (new or existing DCO users) with full history
- Enforce warranty service at approved workshops only
- Maintain read-only audit trail of transferred vehicles
- Import vehicles via CSV or add one-by-one
- Manage approved workshop partnerships

---

## In Scope

### Backend
- Organization entity (created by DCO admin, linked to Org Admin by email)
- Organization roles: `org_admin`, `org_manager`, `org_mechanic`
- Organization membership with role-based access
- Vehicle lifecycle states: `inventory`, `listed`, `reserved`, `sold`
- Warranty templates (duration, mileage, coverage, exclusions, approved workshops)
- Per-vehicle warranty instance (sale date, template reference, warranty start mileage)
- Vehicle transfer flow (user_id change + audit table)
- `transferred_vehicles` audit table for org read-only history
- Workshop accounts (type=workshop) with limited vehicle access
- CSV vehicle import endpoint (admin portal + mobile)
- API endpoints for org management, membership, vehicles, warranties, transfers, workshops

### Mobile (Flutter)
- **Mode Switch**: Settings toggle between Personal and Fleet mode
- **Fleet Mode**: Same 4-tab structure (Garage/Maintenance/Expenses/Settings) scoped to org vehicles
- **Org Management Screen**: Manage members, vehicles, workshops
- **Vehicle Inventory Screen**: List vehicles with status badges (inventory/listed/reserved/sold), counts
- **Add Vehicle Screen**: One-by-one vehicle add (reuse existing flow) + CSV import
- **Warranty Template Screen**: Create/edit warranty templates
- **Transfer Vehicle Screen**: Enter buyer email, select warranty template, confirm transfer
- **Buyer Claim Flow**: Auto-assigned vehicle appears in buyer's garage with full history
- **Workshop Account**: Limited view — current vehicle only, warranty scope only

### Web Admin (Next.js)
- **Organization Creation**: Form with name, admin email, contact details, status, CSV import
- **Organization Management**: List/search orgs, edit, suspend, archive, view fleet stats
- **Org Detail**: Members, vehicles, warranty templates, transferred vehicles audit
- **Invite Management**: Re-send invite emails to Org Admin
- Route guard: `admin` → admin routes including org management

---

## Out of Scope (Phase 3 MVP)

- Multi-location organizations (single location only)
- Sales pipeline / deal tracking / pricing
- CRM / accounting integration
- Telematics / GPS tracking / vehicle health sensors
- Public marketplace / online vehicle listings
- Buyer CRM / follow-up tracking
- Bulk vehicle import from external systems (CSV only)
- Vehicle pricing or financial calculations
- Multi-org membership (user belongs to one org at a time)
- Org-level expense splitting or shared budgets
- Push notifications for org events (local reminders only)
- Workshop scheduling / booking system
- Self-serve org creation (admin-only for MVP)
- Bulk org creation (one org at a time)
- Org creation via mobile app

---

## User Personas

| Persona | Description | Primary Surface |
|---------|-------------|-----------------|
| **Org Admin** | Showroom owner/manager. Manages members, vehicles, warranty templates, initiates transfers. Full fleet access. Org created by DCO admin. | Mobile (Fleet mode) |
| **Org Manager** | Senior employee. Manages vehicles, logs service, manages inventory. Cannot manage org settings or members. | Mobile (Fleet mode) |
| **Org Mechanic** | Workshop employee. Logs service, views vehicle info. Cannot add vehicles, manage templates, or transfer. | Mobile (Fleet mode) |
| **Buyer** | Customer who receives a vehicle. Sees vehicle in personal garage with full history. Normal owner after transfer. | Mobile (Personal mode) |
| **Workshop** | External workshop with DCO account. Logs warranty service on assigned vehicles. Limited visibility. | Mobile (Workshop mode) |
| **Platform Admin** | DCO staff. Creates orgs, manages org lifecycle, imports vehicles, views fleet stats for support. | Web Admin |

---

## User Stories

### US-FLT-001: Create Organization (Admin Portal)
> As a Platform Admin,  
> I want to create a business organization with name, admin email, and contact details  
> So that a showroom owner can start using Fleet mode on mobile.

### US-FLT-002: Invite Org Admin via Email
> As a Platform Admin,  
> I want to link an existing DCO user to the new org, or send an invite email if they don't have an account  
> So that the showroom owner receives access to Fleet mode automatically.

### US-FLT-003: Import Vehicles at Creation
> As a Platform Admin,  
> I want to upload a CSV of vehicles during org creation  
> So that the showroom's inventory is ready on day one.

### US-FLT-004: Invite Members
> As an Org Admin,  
> I want to invite employees to my organization with specific roles (Manager/Mechanic)  
> So that they can help manage vehicles and log maintenance.

### US-FLT-005: Add Vehicle to Inventory
> As an Org Admin or Manager,  
> I want to add a vehicle to my organization's inventory  
> So that I can track it through the sales lifecycle.

### US-FLT-006: Import Vehicles via CSV
> As an Org Admin,  
> I want to import multiple vehicles from a CSV file  
> So that I can onboard additional inventory without adding them one by one.

### US-FLT-007: Update Vehicle Status
> As an Org Admin or Manager,  
> I want to change a vehicle's status (inventory → listed → reserved → sold)  
> So that I can track where each vehicle is in the sales process.

### US-FLT-008: Create Warranty Template
> As an Org Admin,  
> I want to create warranty templates with duration, mileage, coverage, and approved workshops  
> So that I can apply consistent warranty terms to vehicles.

### US-FLT-009: Transfer Vehicle to Buyer
> As an Org Admin,  
> I want to transfer a vehicle to a buyer by entering their email  
> So that the buyer receives the vehicle with full maintenance history in their garage.

### US-FLT-010: Log Warranty Service
> As a Workshop or Org Mechanic,  
> I want to log service done on a vehicle under warranty  
> So that the maintenance history is recorded and warranty terms are tracked.

### US-FLT-011: View Fleet Dashboard
> As an Org Admin,  
> I want to see my vehicle inventory with status counts  
> So that I can get a quick overview of my fleet.

### US-FLT-012: Manage Approved Workshops
> As an Org Admin,  
> I want to add/remove workshops from my approved list  
> So that only authorized workshops can perform warranty work.

### US-FLT-013: Receive Transferred Vehicle
> As a Buyer,  
> I want to receive a vehicle in my garage with full maintenance history  
> So that I can track my new car's maintenance from day one.

### US-FLT-014: View Warranty Status
> As a Buyer,  
> I want to see my vehicle's warranty status (remaining time/km, expiry date)  
> So that I know what's covered and until when.

### US-FLT-015: Workshop Logs Service
> As a Workshop user,  
> I want to log service on a vehicle assigned to my workshop  
> So that the maintenance record is maintained and warranty claims are tracked.

### US-FLT-016: Switch to Fleet Mode
> As an Org Member,  
> I want to switch between Personal and Fleet mode in Settings  
> So that I can manage both my personal vehicles and org vehicles.

### US-FLT-017: Admin Manages Organizations
> As a Platform Admin,  
> I want to create, edit, suspend, and archive organizations in the admin portal  
> So that I can manage the full lifecycle of business accounts.

### US-FLT-018: Admin Edits Organization
> As a Platform Admin,  
> I want to edit org details (name, contact info, status) after creation  
> So that I can keep org records accurate.

### US-FLT-019: Admin Archives Organization
> As a Platform Admin,  
> I want to archive an org and revert its vehicles to original owners  
> So that I can clean up defunct business accounts.

### US-FLT-020: Org Admin Receives Invitation
> As an Org Admin (showroom owner),  
> I want to receive an email when my organization is created, with instructions to log in and enable Fleet mode  
> So that I know my account is ready without contacting support.

---

## Functional Requirements

### 1. Organization

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `name` | String, required, max 200 |
| `type` | `fleet` (future: `rental`, `logistics`) |
| `status` | `pending` \| `active` \| `suspended` |
| `admin_user_id` | FK → `users.id` (Org Admin — showroom owner) |
| `created_by` | FK → `users.id` (DCO admin who created it) |
| `contact_email` | String, optional |
| `contact_phone` | String, optional |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- Created exclusively by DCO admins via the Admin Portal
- `admin_user_id` is the showroom owner (linked by email match or invited)
- `created_by` is the DCO admin who performed the creation
- One organization per `admin_user_id` (enforced by unique `admin_user_id` where `status != archived`)
- A user can belong to only one organization at a time
- `pending` status: org exists but owner hasn't set up yet; members cannot be invited
- `active` status: owner has logged in, Fleet mode available
- `suspended` status: DCO admin has suspended the org; members lose fleet access
- Organization name must be unique per admin (not globally unique)
- Contact details stored for DCO admin reference

### 2. Organization Membership

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `user_id` | FK → `users.id` |
| `role` | `org_admin` \| `org_manager` \| `org_mechanic` |
| `joined_at` | Timestamp |
| `invited_by` | FK → `users.id` (nullable) |

**Rules:**
- Exactly one `org_admin` per organization (the creator)
- `org_admin`: Full access — manage org, members, vehicles, templates, transfers
- `org_manager`: Vehicle CRUD, log service, update status, manage inventory. Cannot manage members or org settings
- `org_mechanic`: Log service, view vehicles. Cannot add vehicles, manage templates, or transfer
- A user can only be invited if they don't already belong to an org

### 3. Organization Vehicles

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `vehicle_id` | FK → `vehicles.id` |
| `status` | `inventory` \| `listed` \| `reserved` \| `sold` |
| `added_by` | FK → `users.id` |
| `added_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- A vehicle can only belong to one organization at a time
- Status transitions: `inventory` → `listed` → `reserved` → `sold`
- `sold` is terminal — vehicle is transferred to buyer
- `listed` → `inventory` reversal allowed (pull from sale)
- `reserved` → `listed` reversal allowed (deal fell through)
- `sold` → no reversal (use `transferred_vehicles` audit)

### 4. Warranty Template

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `name` | String, required, max 100 |
| `duration_years` | Integer, required, 1-10 |
| `mileage_limit_km` | Integer, required, 1000-500000 |
| `coverage_categories` | JSON array of strings (e.g., `["Engine", "Transmission", "Electrical"]`) |
| `exclusions` | String, optional, max 1000 |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- One org can have multiple templates
- Template is org-scoped (not global)
- Warranty expires on earlier of `duration_years` or `mileage_limit_km` from sale date
- `coverage_categories` defines what's covered (free-form strings)
- `exclusions` is free-text for fine print

### 5. Warranty Template Workshops

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `template_id` | FK → `warranty_templates.id` |
| `partner_id` | FK → `partners.id` (type=workshop) |

**Rules:**
- Links approved workshops to a warranty template
- Only workshops in this list can log warranty service for vehicles using this template
- Multiple workshops per template allowed

### 6. Vehicle Warranty Instance

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `vehicle_id` | FK → `vehicles.id` (unique — one active warranty per vehicle) |
| `template_id` | FK → `warranty_templates.id` |
| `sale_date` | Date, required |
| `sale_mileage_km` | Integer, required (mileage at time of sale) |
| `warranty_end_date` | Date, computed: `sale_date + duration_years` |
| `warranty_end_mileage` | Integer, computed: `sale_mileage_km + mileage_limit_km` |
| `status` | `active` \| `expired` \| `voided` |
| `created_at` | Timestamp |

**Rules:**
- Created when vehicle is transferred (status = `sold`)
- Warranty expires on earlier of `warranty_end_date` or when odometer exceeds `warranty_end_mileage`
- `expired` is set automatically when either limit is reached
- `voided` if warranty is manually cancelled by Org Admin
- Buyer sees warranty status in vehicle detail

### 7. Transferred Vehicles (Audit Table)

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `vehicle_id` | FK → `vehicles.id` |
| `org_id` | FK → `organizations.id` |
| `buyer_user_id` | FK → `users.id` |
| `transferred_by` | FK → `users.id` |
| `transferred_at` | Timestamp |
| `warranty_instance_id` | FK → `vehicle_warranties.id` (nullable) |

**Rules:**
- Created when vehicle is transferred to buyer
- Org retains read-only access to vehicle history via this table
- Buyer gets full ownership (vehicle's `user_id` changes to buyer)
- Org can view: vehicle info, all service records, documents, fuel logs, expenses (read-only)
- Buyer sees: full history including pre-transfer data

### 8. Workshop Account

| Field | Rule |
|-------|------|
| `user_id` | FK → `users.id` |
| `org_id` | FK → `organizations.id` (nullable — workshop can serve multiple orgs) |
| `assigned_vehicle_ids` | Array of vehicle IDs currently under warranty at this workshop |

**Rules:**
- Workshop gets a DCO account with role `workshop` (new JWT audience or extension of `dco-owner`)
- Workshop can only see vehicles currently assigned to them under active warranty
- Workshop can log service on assigned vehicles
- Workshop cannot see buyer personal info (name, email) — only vehicle info
- Workshop cannot see other org vehicles or non-warranty vehicles
- Workshop can log service on non-warranty vehicles if they have an account (optional, future)

### 9. CSV Import

| Field | Rule |
|-------|------|
| `file` | CSV format, max 100 rows per import |
| `columns` | `name`, `make`, `model`, `year`, `plate`, `vin`, `fuel_type`, `mileage` (optional) |

**Rules:**
- CSV import creates vehicles in `inventory` status
- Duplicate plates within the same org are rejected
- VIN uniqueness checked globally (existing rule)
- Import returns success/failure per row with error messages
- Max 100 vehicles per import (batch limit)

### 10. API Endpoints (v1)

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| GET | `/v1/organizations/me` | `dco-owner` | Get my organization |
| GET | `/v1/organizations/:id/members` | `dco-owner` | List members with roles |
| POST | `/v1/organizations/:id/members` | `dco-owner` | Invite member — Admin only |
| PATCH | `/v1/organizations/:id/members/:userId` | `dco-owner` | Update member role / remove — Admin only |
| GET | `/v1/organizations/:id/vehicles` | `dco-owner` | List org vehicles with status |
| POST | `/v1/organizations/:id/vehicles` | `dco-owner` | Add vehicle to org — Admin/Manager |
| PATCH | `/v1/organizations/:id/vehicles/:vehicleId` | `dco-owner` | Update vehicle status — Admin/Manager |
| POST | `/v1/organizations/:id/vehicles/import` | `dco-owner` | CSV import vehicles — Admin only |
| GET | `/v1/organizations/:id/warranty-templates` | `dco-owner` | List warranty templates |
| POST | `/v1/organizations/:id/warranty-templates` | `dco-owner` | Create warranty template — Admin only |
| PATCH | `/v1/organizations/:id/warranty-templates/:templateId` | `dco-owner` | Update template — Admin only |
| DELETE | `/v1/organizations/:id/warranty-templates/:templateId` | `dco-owner` | Delete template — Admin only |
| POST | `/v1/organizations/:id/vehicles/:vehicleId/transfer` | `dco-owner` | Transfer vehicle to buyer — Admin only |
| GET | `/v1/organizations/:id/transferred` | `dco-owner` | List transferred vehicles (audit) |
| GET | `/v1/organizations/:id/transferred/:vehicleId/history` | `dco-owner` | View transferred vehicle history (read-only) |
| GET | `/v1/organizations/:id/workshops` | `dco-owner` | List approved workshops |
| POST | `/v1/organizations/:id/workshops` | `dco-owner` | Add workshop — Admin only |
| DELETE | `/v1/organizations/:id/workshops/:partnerId` | `dco-owner` | Remove workshop — Admin only |
| POST | `/v1/workshops/:vehicleId/service` | `dco-owner` | Workshop logs service on vehicle |
| GET | `/v1/workshops/my-vehicles` | `dco-owner` | Workshop sees assigned vehicles |

**Web Admin (Org creation and management):**
| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/admin/organizations` | `dco-admin` | Create organization (name, admin email, contact details, status, CSV import) |
| GET | `/v1/admin/organizations` | `dco-admin` | List all orgs with search/filter |
| GET | `/v1/admin/organizations/:id` | `dco-admin` | Org detail (members, vehicles, templates, transferred) |
| PATCH | `/v1/admin/organizations/:id` | `dco-admin` | Edit org (name, contact details, status) |
| DELETE | `/v1/admin/organizations/:id` | `dco-admin` | Archive org (revert vehicles to owners) |
| POST | `/v1/admin/organizations/:id/invite` | `dco-admin` | Re-send invite email to Org Admin |
| GET | `/v1/admin/organizations/:id/stats` | `dco-admin` | Org fleet stats |

### 11. Mobile Screens

#### Mode Switch (Settings)
- Entry: Settings tab → "Switch to Fleet" toggle
- Toggle visible only if user is org member
- Switching reloads the 4-tab structure with org-scoped content
- Personal mode: same as current (personal vehicles)
- Fleet mode: same tabs (Garage/Maintenance/Expenses/Settings) but filtered to org vehicles
- Org must be `active` for toggle to appear; `pending` shows "Your organization is being set up" message

#### Org Management Screen (New)
- Entry: Settings → Fleet (after org exists and is active)
- Tabs: Members / Vehicles / Workshops / Settings
- **Members tab**: List with name, role badge, "Change Role" / "Remove" (Admin only)
- **Vehicles tab**: List with status badges (inventory/listed/reserved/sold), counts, "Add Vehicle" / "Import CSV"
- **Workshops tab**: List of approved workshops, "Add Workshop" / "Remove"
- **Settings tab**: Org name, status badge, contact details (read-only — edit requires DCO admin)

#### Vehicle Inventory Screen (New)
- Entry: Fleet mode → Garage tab (replaces personal Garage in fleet mode)
- Header: Vehicle counts by status (inventory: 5, listed: 3, reserved: 1, sold: 2)
- Vehicle list: Card with photo, name, plate, make/model, status badge, mileage
- Tap → Vehicle Detail (fleet version)
- "Add Vehicle" FAB → Add Vehicle form
- "Import CSV" button → CSV upload flow

#### Add Vehicle Screen (Fleet Version)
- Reuses existing Add Vehicle form from Garage
- Additional fields: Status (default: inventory), Warranty Template (dropdown, optional)
- If warranty template selected, warranty instance created on transfer

#### Transfer Vehicle Screen (New)
- Entry: Vehicle Detail → "Transfer to Buyer" (Admin only)
- Steps:
  1. Enter buyer email (autocomplete from existing users)
  2. Select warranty template (dropdown, or "No Warranty")
  3. Confirm sale date and current mileage
  4. Review transfer summary
  5. Confirm → Vehicle transferred
- Post-transfer: Vehicle status → `sold`, `transferred_vehicles` row created, vehicle's `user_id` → buyer

#### Buyer Claim Flow
- Buyer signs up / logs in → Vehicle appears in personal garage automatically
- No acceptance required (email-based auto-assign)
- Vehicle shows full history (pre-transfer maintenance, expenses, documents, fuel logs)
- Warranty status displayed in vehicle detail
- Free plan exempt from 1-vehicle limit for transferred vehicles

#### Workshop Mobile Screen (New)
- Entry: Workshop user logs in → Sees assigned vehicles list
- Vehicle list: Only vehicles currently under warranty at this workshop
- Vehicle detail: Vehicle info, warranty status, service history (limited to this workshop)
- "Log Service" → Service form (date, odometer, cost, items, notes)
- Cannot see: buyer info, other org vehicles, org member list

### 12. Web Admin Changes

#### Auth
- No changes — existing `admin` role with `dco-admin` audience

#### Organization Management — New Route: `/organizations`
- **Organizations List**: Table with name, status (pending/active/suspended), admin email, member count, vehicle count, created date
- **Search**: By org name or admin email
- **Create Button**: Opens org creation form
- **Actions per row**: Edit, Suspend/Activate, Archive, Re-send Invite

#### Organization Creation Form (New — Modal or Separate Page)
- Fields:
  - **Org Name**: Required, text
  - **Org Type**: Required, dropdown (`fleet` default)
  - **Admin Email**: Required, email — the showroom owner's DCO email
  - **Contact Email**: Optional, email (business contact)
  - **Contact Phone**: Optional, phone
  - **Initial Status**: Required, dropdown (`active` / `pending` / `suspended`)
- **Vehicle Import**: Optional CSV upload during creation
  - CSV preview: shows parsed rows with validation
  - Import runs async; results shown after org is created
- **Submit**: Creates org, links/invites user, imports vehicles (if uploaded)
- **Post-creation**: System sends info email to admin user: "Your organization [Name] has been created. Log in to the mobile app and enable Fleet mode in Settings."

#### Organization Detail — New Route: `/organizations/:id`
- **Header**: Org name, status badge, admin email, member count, vehicle count
- **Members Table**: Name, email, role, joined date
- **Vehicles Table**: Name, plate, status, mileage, added date
- **Warranty Templates Table**: Name, duration, mileage, workshop count
- **Transferred Vehicles Table**: Vehicle name, buyer (anonymized), transfer date, warranty status
- **Stats**: Total vehicles, active warranty count, transferred count
- **Actions**: Edit org, Suspend/Activate, Archive, Re-send Invite, Add Vehicle, Import CSV

#### Organization Edit Form (New — Modal)
- Fields: Org name, contact email, contact phone, status
- Save updates org record

#### Organization Archive Flow (New — Confirmation Dialog)
- Warning: "Archiving this organization will revert all vehicles to their original owners. This action cannot be undone."
- Confirmation required (type org name)
- Vehicles revert: `organization_vehicles` deleted, vehicles become personal again
- Members removed from org

---

## Business Rules

1. **Org creation is admin-only** — only DCO admins can create organizations via the Admin Portal
2. **One organization per user** — enforced at membership level
3. **Org Admin must transfer admin role** before leaving or deleting account
4. **Vehicle status transitions are enforced** — cannot skip states
5. **Warranty expires on earlier of time or mileage** — system checks both on each service log
6. **Only approved workshops can log warranty service** — enforced server-side
7. **Transferred vehicles retain full history** — buyer sees everything
8. **Free plan exempt** — transferred vehicles don't count against 1-vehicle limit
9. **CSV import max 100 rows** — batch limit for performance
10. **Org must be `active`** for Fleet mode to appear on mobile
11. **Workshop visibility is scoped** — only sees assigned vehicles, no buyer info
12. **Mode switch preserves state** — switching between Personal/Fleet doesn't lose draft data
13. **Archive-not-delete** — organizations are soft-archived, vehicles revert to owners
14. **Invite email is one-time** — if not claimed, DCO admin can re-send from admin portal

---

## User Flow

### Admin Creates Org → Owner Activates Fleet → Manages Vehicles
```
Platform Admin (Web Admin Portal)
  /organizations → "Create Organization"
  → Enter org name, admin email, contact details
  → Select initial status (active/pending/suspended)
  → Optionally upload CSV of vehicles
  → Submit → Org created
  → System sends info email to admin user

Org Admin (Mobile - receives email)
  "Your organization [Name] has been created."
  → Logs in to mobile app
  → Settings → Fleet toggle appears (if org is active)
  → Enables Fleet mode → Sees imported vehicles

Org Admin (Mobile - Fleet Mode)
  Fleet → Garage → Vehicle card → "List for Sale"
  → Status: listed

  Fleet → Garage → Vehicle card → "Reserve"
  → Status: reserved

  Fleet → Garage → Vehicle card → "Transfer to Buyer"
  → Enter buyer email
  → Select warranty template (optional)
  → Confirm sale date + mileage
  → Transfer complete → Status: sold

Buyer (Mobile - Personal Mode)
  Logs in / Signs up
  → Vehicle appears in Personal Garage
  → Full history visible
  → Warranty status shown
```

### Admin Creates Org with Vehicle Import
```
Platform Admin (Web Admin Portal)
  /organizations → "Create Organization"
  → Enter org details
  → Upload CSV: 15 vehicles
  → Preview: 15 rows parsed, 14 valid, 1 warning (duplicate VIN)
  → Submit → Org created, 14 vehicles imported
  → 1 failed row logged for review
  → Email sent to admin user
```

### Workshop Logs Warranty Service
```
Workshop (Mobile)
  Logs in → Sees assigned vehicles
  → Taps vehicle → Views warranty status
  → "Log Service"
  → Enter date, odometer, cost, items
  → Service recorded
  → Warranty mileage updated

Org Admin (Mobile - Fleet Mode)
  Fleet → Garage → Vehicle → Service History
  → Sees workshop's service entry
```

### Admin Manages Org Lifecycle
```
Platform Admin (Web Admin Portal)
  /organizations → List view
  → Search by name or email
  → Click org → Detail view
  → Actions:
    - Edit: Change name, contact details
    - Suspend: Org loses fleet access
    - Activate: Re-enable fleet access
    - Archive: Revert vehicles to owners, remove members
    - Re-send Invite: If owner hasn't set up yet
```

---

## Validation Rules

### Organization Creation (Admin Portal Only)
- Name: required, 1-200 chars
- Type: required, must be `fleet`
- Admin email: required, valid email format
- Initial status: required, must be `active`, `pending`, or `suspended`
- Contact email: optional, valid email format
- Contact phone: optional, max 20 chars

### Member Invitation
- Email: required, valid email format
- Role: required, must be `org_manager` or `org_mechanic`
- Invitee must not already belong to an org

### Vehicle Add
- Name: required, 1-100 chars
- Make/Model: required
- Year: required, 1900-current+1
- Plate: required, unique within org
- VIN: required, unique globally
- Fuel type: required, must match existing fuel types

### CSV Import
- File format: CSV with headers
- Required columns: `name`, `make`, `model`, `year`, `plate`, `vin`, `fuel_type`
- Optional columns: `mileage`
- Max rows: 100
- Duplicate plates within org: rejected
- Duplicate VINs globally: rejected

### Warranty Template
- Name: required, 1-100 chars
- Duration: required, 1-10 years
- Mileage: required, 1000-500000 km
- Coverage categories: optional, array of strings
- Exclusions: optional, max 1000 chars

### Vehicle Transfer
- Buyer email: required, must be valid email
- Buyer must exist or will be auto-created on claim
- Sale date: required, must be today or past
- Current mileage: required, must be ≥ vehicle's current mileage
- Warranty template: optional (if selected, warranty instance created)

---

## Error States

| Scenario | Response |
|----------|----------|
| User already belongs to an org | 409 `already_in_org` |
| Org pending (not active) | 403 `org_not_active` |
| Org suspended | 403 `org_suspended` |
| Vehicle already in an org | 409 `vehicle_already_in_org` |
| Invalid status transition | 400 `invalid_status_transition` |
| Workshop not approved for warranty | 403 `workshop_not_approved` |
| Warranty already expired | 400 `warranty_expired` |
| CSV import: duplicate plate | 409 `duplicate_plate` (per row) |
| CSV import: duplicate VIN | 409 `duplicate_vin` (per row) |
| CSV import: max rows exceeded | 400 `import_limit_exceeded` |
| Transfer: buyer email invalid | 400 `invalid_buyer_email` |
| Transfer: vehicle not in org | 404 `vehicle_not_in_org` |
| Not org admin (for admin actions) | 403 `not_org_admin` |
| Not DCO admin (for org creation) | 403 `not_dco_admin` |
| Org already exists for this admin | 409 `org_already_exists` |
| Admin email not found (invite) | 404 `user_not_found` |
| Workshop: vehicle not assigned | 404 `vehicle_not_assigned` |
| Org archived | 410 `org_archived` |

---

## Non-Functional Requirements

- **Offline-first**: Org membership, vehicles, templates sync via existing change log
- **Load time**: Vehicle inventory < 2s (local DB), Org management < 1.5s
- **Security**: Workshop access validated server-side on every request; buyer info not exposed to workshops
- **CSV import**: Process in background, return job ID, poll for results
- **Mode switch**: Instant UI swap, no data reload needed (data already synced)
- **Admin portal**: Org creation form submission < 3s (excluding CSV import)
- **Invite email**: Delivered within 60 seconds of org creation
- **Accessibility**: Status badges have text + color; warranty expiry announced to screen readers
- **Testability**: Unit tests for warranty expiry logic, status transitions; integration tests for transfer flow

---

## Analytics Events

| Event | Properties |
|-------|------------|
| `admin_org_created` | `org_id`, `admin_user_id`, `vehicle_count`, `initial_status` |
| `admin_org_edited` | `org_id`, `fields_changed` |
| `admin_org_suspended` | `org_id`, `reason` |
| `admin_org_archived` | `org_id`, `vehicle_count`, `member_count` |
| `admin_invite_sent` | `org_id`, `admin_email`, `user_existed` |
| `organization_joined` | `org_id`, `role`, `method` (invite) |
| `member_role_changed` | `org_id`, `target_user_id`, `old_role`, `new_role` |
| `vehicle_added_to_org` | `org_id`, `vehicle_id`, `status` |
| `vehicle_status_changed` | `org_id`, `vehicle_id`, `old_status`, `new_status` |
| `csv_import_completed` | `org_id`, `source` (admin/mobile), `total_rows`, `success_count`, `fail_count` |
| `warranty_template_created` | `org_id`, `template_id`, `duration_years`, `mileage_limit_km` |
| `vehicle_transferred` | `org_id`, `vehicle_id`, `buyer_email`, `has_warranty` |
| `warranty_service_logged` | `vehicle_id`, `workshop_id`, `odometer`, `is_warranty` |
| `warranty_expired` | `vehicle_id`, `expired_by` (time/mileage) |
| `fleet_mode_switched` | `user_id`, `org_id`, `direction` (personal→fleet / fleet→personal) |
| `workshop_service_logged` | `vehicle_id`, `workshop_id`, `service_type` |

---

## Success Metrics

- Organizations created per week (by DCO admins)
- Invite email open rate / claim rate
- Average time from org creation to first Fleet mode login
- Average org size (members + vehicles)
- Vehicle transfer completion rate
- Warranty service logging rate (workshop adoption)
- CSV import usage vs one-by-one add
- Buyer claim rate (transferred vehicles claimed within 7 days)
- Warranty expiry tracking accuracy
- Workshop account activation rate
- Org admin fleet mode usage frequency
- Admin portal org management actions per week

---

## Dependencies

- Auth (JWT, roles, audiences — new `workshop` role or extension)
- Users API (profile, org membership, email lookup)
- Vehicles API (vehicle CRUD, grants, status)
- Documents API (vault reuse for transferred vehicles)
- Partners API (workshop accounts, approved list)
- Media storage (vehicle photos)
- Notifications (warranty expiry reminders, org created email)
- Email service (invite emails, org creation notifications)
- Sync (org, membership, vehicle, template, warranty entities)
- Admin API (org creation, management, verification)

---

## Future Enhancements (Post-Phase 3)

- Multi-location organizations
- Sales pipeline / deal tracking
- Vehicle pricing and financial calculations
- CRM integration (buyer follow-ups)
- Telematics / GPS tracking
- Public marketplace listings
- Workshop scheduling / booking
- Multi-org membership
- Org-level expense splitting
- Bulk import from external systems (API, not just CSV)
- Warranty claims management (approve/reject)
- Vehicle history report PDF export for buyers
- Org dashboard analytics (charts, trends)
- Push notifications for org events
- Workshop rating / feedback system
- Self-serve org creation (public signup page)
- Org creation via mobile app
- Bulk org creation (CSV import of multiple orgs)
- Org transfer between DCO admins

---

## Migration Notes

- **Schema**: Add `organizations`, `organization_members`, `organization_vehicles`, `warranty_templates`, `warranty_template_workshops`, `vehicle_warranties`, `transferred_vehicles` tables
- **Organizations table**: `admin_user_id` (FK → users.id, the showroom owner), `created_by` (FK → users.id, the DCO admin), `contact_email`, `contact_phone`
- **Users table**: Add `org_id` nullable FK (denormalized for quick "my org" lookup)
- **Vehicles table**: No change (ownership stays on `user_id`); org link via `organization_vehicles`
- **Partners table**: Add `workshop_account` flag for workshop DCO accounts
- **Sync**: New entity types `organization`, `organization_member`, `organization_vehicle`, `warranty_template`, `vehicle_warranty`, `transferred_vehicle`
- **Mobile Drift**: New tables for offline org/vehicles/templates
- **Web Admin**: New `/organizations` route tree with creation form, edit, archive
- **Admin API**: New `/v1/admin/organizations` for org CRUD, vehicle import, invite management
- **Email templates**: New "Org Created" email template for admin user notification

---

## Open Decisions

1. **Workshop JWT audience**: Should workshops get a new `dco-workshop` audience, or extend `dco-owner` with a workshop flag?
2. **Buyer auto-creation**: If the buyer email doesn't exist, should we auto-create a pending account (requires email verification) or reject the transfer?
3. **Warranty mileage tracking**: Who updates the vehicle's mileage to check against warranty limits — the workshop on each service, or the owner on each fuel log?
4. **Org ownership transfer**: Can the Org Admin transfer admin role to another member (like Primary Owner transfer in families)?
5. **Bulk status update**: Can the Org Admin change status of multiple vehicles at once (e.g., mark 5 vehicles as `listed`)?
6. **Workshop service on non-warranty vehicles**: Should workshops be able to log service on vehicles not under warranty (general service)?
7. **CSV template download**: Should we provide a CSV template file for import?
8. **Transferred vehicle reversal**: If the buyer returns the vehicle within X days, can the org reclaim it?
9. **Invite expiry**: How long is the invite email valid? Should it expire? Can it be re-sent?
10. **Org suspension effect**: When an org is suspended, should existing vehicles be locked (no status changes) or just new vehicles blocked?
