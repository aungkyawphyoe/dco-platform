# Fleet Management Module

## Overview

Fleet Management enables **business accounts** (showrooms, dealerships, taxi fleets, rental companies, commercial fleets) to manage multiple vehicles under an organization, track warranty periods with approved workshops, and transfer vehicle ownership to buyers with full maintenance history. Organizations are created exclusively by DCO administrators via the Admin Portal (sales-led onboarding). This module extends the existing single-owner model to support multi-vehicle business operations with role-based access, warranty enforcement, ownership transfer, driver work orders, vehicle inspections, and cost analytics.

**Status:** Planned (Phase 3, Year 2).  
**Contract:** This FRD extends `product/mvp-scope.md` and `architecture/iam.md`.  
**Surfaces:** Mobile (Flutter — org members, drivers, buyers, workshops), Backend (REST API), Fleet Dashboard (Next.js — `fleet.yourdomain.com` — full fleet management for Fleet Owners/Managers), Web Admin (Next.js — `admin.yourdomain.com` — user management only for DCO staff).

---

## Objectives

Enable organizations to:

- Be created by DCO administrators via the Admin Portal (sales-led onboarding)
- Manage vehicle inventory through lifecycle states using predefined templates (showroom, taxi fleet, rental, commercial fleet)
- Configure warranty templates (duration + mileage + approved workshops)
- Transfer vehicle ownership to buyers (new or existing DCO users) with full history
- Enforce warranty service at approved workshops only
- Maintain read-only audit trail of transferred vehicles
- Import vehicles via CSV or add one-by-one
- Manage approved workshop partnerships
- Assign vehicles to drivers and track driver usage
- Log driver work orders (issue reports) with approval workflow
- Track vehicle inspections via configurable checklists
- Provide cost analytics (TCO, cost-per-mile, lemon detection) per vehicle and fleet-wide
- Enable restricted driver access for mileage logging, inspections, fuel, and issue reporting

---

## In Scope

### Backend
- Organization entity (created by DCO admin, linked to Org Admin by email)
- Organization roles: `org_admin`, `org_manager`, `org_mechanic`, `org_driver`
- Organization membership with role-based access
- Predefined lifecycle templates: showroom, taxi_fleet, rental, commercial
- Vehicle lifecycle states (free-form, chosen from template)
- Warranty templates (duration, mileage, coverage, exclusions, approved workshops)
- Per-vehicle warranty instance (sale date, template reference, warranty start mileage)
- Vehicle transfer flow (user_id change + audit table)
- `transferred_vehicles` audit table for org read-only history
- Workshop accounts (type=workshop) with limited vehicle access
- CSV vehicle import endpoint (admin portal + mobile)
- Work order entity (driver reports, 3-step lifecycle: reported → in_progress → completed)
- Inspection entity (template-based checklists, pre-trip/post-trip/random)
- Inspection templates (configurable checklist items per org)
- Driver assignment entity (vehicle ↔ driver, one active assignment at a time)
- Shift mileage tracking (start/end odometer per shift)
- Cost analytics engine (TCO, cost-per-mile, lemon detection using maintenance + fuel + wear items)
- API endpoints for org management, membership, vehicles, warranties, transfers, workshops, work orders, inspections, assignments, analytics

### Mobile (Flutter)
- **Mode Switch**: Settings toggle between Personal and Fleet mode
- **Fleet Mode**: Same 4-tab structure (Garage/Maintenance/Expenses/Settings) scoped to org vehicles
- **Org Management Screen**: Manage members, vehicles, workshops
- **Vehicle Inventory Screen**: List vehicles with status badges (template-specific), counts
- **Add Vehicle Screen**: One-by-one vehicle add (reuse existing flow) + CSV import
- **Warranty Template Screen**: Create/edit warranty templates
- **Transfer Vehicle Screen**: Enter buyer email, select warranty template, confirm transfer
- **Buyer Claim Flow**: Auto-assigned vehicle appears in buyer's garage with full history
- **Workshop Account**: Limited view — current vehicle only, warranty scope only
- **Driver Mode**: Restricted view for assigned vehicles — log mileage, inspections, fuel, report issues
- **Work Order Screen**: Driver creates reports, owner/manager reviews and resolves
- **Inspection Screen**: Template-based checklist completion (pre-trip/post-trip)
- **Reports Screen**: Per-vehicle and fleet-wide cost analytics (TCO, cost-per-mile, lemon flags)
- **Driver Assignment Screen**: Owner assigns/reassigns vehicles to drivers

### Fleet Dashboard (Next.js — `fleet.yourdomain.com`)
- **Authentication**: SSO with DCO mobile credentials (same `dco-owner` JWT audience)
- **Desktop-optimized layout**: Data tables, charts, bulk actions, sidebar navigation
- **Fleet Owner/Manager**: Full fleet management (read + write) — vehicles, work orders, inspections, assignments, analytics, reports, warranty templates, driver management
- **DCO Admin**: Read-only fleet visibility for support (cross-org view)
- **Vehicle Inventory**: Table view with filters, sorting, bulk status changes
- **Work Orders**: Table + detail view with approve/assign/resolve actions
- **Inspections**: Template management, inspection history, failure review
- **Driver Assignments**: Assignment table, bulk assign/unassign
- **Cost Analytics**: Per-vehicle TCO, cost-per-mile, lemon flags, fleet summary with charts
- **Reports**: Export to CSV, time range filters, vehicle comparison
- **Warranty Templates**: CRUD management
- **Org Settings**: Name, contact details, lemon threshold config

### Web Admin (Next.js — `admin.yourdomain.com`)
- **User Management**: List/search users, view profile, deactivate/reactivate accounts
- **Fleet Owner Support**: Re-send invite emails to Org Admin
- **Read-only Fleet Access**: DCO Admin can view fleet data for support purposes (no write actions)
- Route guard: `admin` → admin routes; `dco-owner` with org → read-only fleet routes

---

## Out of Scope (Phase 3 MVP)

- Multi-location organizations (single location only)
- Sales pipeline / deal tracking / pricing
- CRM / accounting integration
- Telematics / GPS tracking / vehicle health sensors
- Public marketplace / online vehicle listings
- Buyer CRM / follow-up tracking
- Bulk vehicle import from external systems (CSV only)
- Payment processing for rental fees or fare shares
- Multi-org membership (user belongs to one org at a time)
- Org-level expense splitting or shared budgets
- Push notifications for org events (local reminders only)
- Workshop scheduling / booking system
- Self-serve org creation (admin-only for MVP)
- Bulk org creation (one org at a time)
- Org creation via mobile app
- Real-time vehicle tracking / GPS
- Driver scheduling / shift management
- Mobile-responsive Fleet Dashboard (desktop-optimized only for MVP)
- Fleet Dashboard mobile app (mobile app handles fleet ops for now)

---

## User Personas

| Persona | Description | Primary Surface |
|---------|-------------|-----------------|
| **Fleet Owner** | Business owner (showroom, taxi fleet, rental). Full access to org, vehicles, members, templates, transfers, cost analytics, work order approval. Org created by DCO admin. | Mobile (Fleet mode) + Web |
| **Fleet Manager** | Senior employee. Full operational access: vehicles, work orders, inspections, assignments, cost analytics. Cannot manage org settings or members. | Mobile (Fleet mode) |
| **Org Mechanic** | Workshop employee. Logs service, views vehicle info. Cannot add vehicles, manage templates, or transfer. | Mobile (Fleet mode) |
| **Driver** | Taxi/rental driver. DCO user with `driver` role. Assigned one vehicle at a time. Can log mileage, complete inspections, report issues, log fuel. Restricted view — no costs, no other vehicles. | Mobile (Driver mode) |
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

### US-FLT-021: Driver Logs Mileage
> As a Driver,  
> I want to log my start and end odometer readings at the beginning and end of each shift  
> So that the fleet owner can track vehicle usage and calculate cost-per-mile.

### US-FLT-022: Driver Reports Issue
> As a Driver,  
> I want to report an issue with my assigned vehicle (breakdown, accident, wear) with description, type, urgency, and photos  
> So that the fleet owner is notified and can arrange repairs.

### US-FLT-023: Driver Completes Inspection
> As a Driver,  
> I want to complete a pre-trip or post-trip inspection using a checklist template  
> So that vehicle condition is documented and issues are caught early.

### US-FLT-024: Driver Logs Fuel
> As a Driver,  
> I want to log fuel entries for my assigned vehicle (date, amount, cost, fuel type)  
> So that fuel expenses are tracked against the vehicle.

### US-FLT-025: Driver Views Assigned Vehicle
> As a Driver,  
> I want to view my assigned vehicle's info (make, plate, photo, documents, maintenance schedule)  
> So that I know the vehicle details and when service is due.

### US-FLT-026: Driver Views Own Work Orders
> As a Driver,  
> I want to view my own work order history (reports I've submitted and their status)  
> So that I can track follow-up on issues I've reported.

### US-FLT-027: Fleet Owner Approves Work Order
> As a Fleet Owner,  
> I want to review, approve, and resolve driver-reported work orders  
> So that maintenance is authorized and tracked through completion.

### US-FLT-028: Fleet Owner Views Cost Analytics
> As a Fleet Owner,  
> I want to view TCO (Total Cost of Ownership) and cost-per-mile per vehicle and fleet-wide  
> So that I can identify underperforming vehicles and make informed decisions.

### US-FLT-029: Fleet Owner Views Lemon Flags
> As a Fleet Owner,  
> I want to see vehicles flagged as "lemons" (cost-per-mile exceeding threshold)  
> So that I can consider replacing or divesting high-cost vehicles.

### US-FLT-030: Fleet Owner Manages Inspection Templates
> As a Fleet Owner,  
> I want to create and edit inspection checklist templates with configurable items  
> So that inspections match my fleet's specific requirements.

### US-FLT-031: Fleet Owner Assigns Vehicle to Driver
> As a Fleet Owner,  
> I want to assign a vehicle to a driver (one vehicle per driver at a time)  
> So that drivers know which vehicle they're responsible for.

### US-FLT-032: Fleet Manager Views Reports
> As a Fleet Manager,  
> I want to view fleet-wide reports (maintenance costs, fuel usage, work order status, utilization)  
> So that I can monitor fleet operations and make informed decisions.

### US-FLT-033: Fleet Owner Exports Reports
> As a Fleet Owner,  
> I want to export fleet analytics and reports to CSV  
> So that I can share data with accountants or analyze in external tools.

### US-FLT-034: Fleet Owner Configures Lemon Threshold
> As a Fleet Owner,  
> I want to configure the lemon detection threshold (default 2x fleet average, with override)  
> So that the definition of "lemon" matches my business criteria.

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
| `role` | `org_admin` \| `org_manager` \| `org_mechanic` \| `org_driver` |
| `joined_at` | Timestamp |
| `invited_by` | FK → `users.id` (nullable) |

**Rules:**
- Exactly one `org_admin` per organization (the creator)
- `org_admin` (Fleet Owner): Full access — manage org, members, vehicles, templates, transfers, cost analytics, work order approval
- `org_manager` (Fleet Manager): Vehicle CRUD, log service, update status, manage inventory, approve work orders, view reports. Cannot manage members or org settings
- `org_mechanic`: Log service, view vehicles. Cannot add vehicles, manage templates, or transfer
- `org_driver` (Driver): Log mileage, complete inspections, report issues, log fuel, view assigned vehicle only. Cannot see costs, analytics, or other vehicles
- A user can only be invited if they don't already belong to an org
- Driver must have `org_driver` role to be eligible for vehicle assignment

### 3. Organization Vehicles

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `vehicle_id` | FK → `vehicles.id` |
| `lifecycle_template` | `showroom` \| `taxi_fleet` \| `rental` \| `commercial` |
| `status` | String (free-form, chosen from template's valid states) |
| `revenue_label` | String, optional (e.g., "Daily rental: $50/day", "Fare share: 70/30") |
| `added_by` | FK → `users.id` |
| `added_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- A vehicle can only belong to one organization at a time
- `lifecycle_template` determines which status transitions are valid
- Status is free-form but must be one of the template's predefined states
- `revenue_label` is informational only (no payment processing)
- Terminal states (e.g., `sold`, `retired`) prevent further status changes

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
- CSV import creates vehicles in default status for the chosen lifecycle template
- Duplicate plates within the same org are rejected
- VIN uniqueness checked globally (existing rule)
- Import returns success/failure per row with error messages
- Max 100 vehicles per import (batch limit)

### 10. Work Orders

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `vehicle_id` | FK → `vehicles.id` |
| `reported_by` | FK → `users.id` (driver with `org_driver` role) |
| `reported_at` | Timestamp |
| `odometer_km` | Integer, required |
| `issue_type` | `breakdown` \| `accident` \| `wear_tear` \| `scheduled_service` \| `other` |
| `description` | String, required, min 10 chars, max 2000 |
| `urgency` | `low` \| `medium` \| `high` \| `critical` |
| `photos` | JSON array of media_ids (optional) |
| `status` | `reported` \| `in_progress` \| `completed` |
| `assigned_to` | FK → `users.id` (nullable — who is handling it) |
| `resolved_by` | FK → `users.id` (nullable) |
| `resolved_at` | Timestamp (nullable) |
| `resolution_notes` | String, optional, max 2000 |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- 3-step lifecycle: `reported` → `in_progress` → `completed`
- Driver creates work order; Owner/Manager approves and resolves
- `reported` → `in_progress`: Owner/Manager assigns and begins work
- `in_progress` → `completed`: Owner/Manager marks resolved with notes
- No status skipping allowed
- Driver can view their own work orders only
- Owner/Manager can view all work orders across the org
- Photos stored via existing media pipeline (compressed, 15 MB cap)

### 11. Inspections

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `vehicle_id` | FK → `vehicles.id` |
| `driver_id` | FK → `users.id` (driver with `org_driver` role) |
| `template_id` | FK → `inspection_templates.id` |
| `inspection_type` | `pre_trip` \| `post_trip` \| `random` |
| `started_at` | Timestamp |
| `completed_at` | Timestamp (nullable) |
| `status` | `in_progress` \| `completed` \| `failed` |
| `items` | JSON array of checklist results (see below) |
| `notes` | String, optional, max 1000 |
| `created_at` | Timestamp |

**Checklist item structure:**
```json
{
  "item_name": "Tires",
  "result": "ok" | "not_ok",
  "photo_media_id": "optional",
  "notes": "optional"
}
```

**Rules:**
- Driver completes inspection using org's template
- All required items must be completed
- If any item is `not_ok`, inspection status is `failed` (not `completed`)
- `failed` inspections auto-generate a work order for the issue
- Pre-trip: completed before starting shift
- Post-trip: completed after ending shift
- Random: Owner/Manager can request ad-hoc inspection

### 12. Inspection Templates

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `name` | String, required, max 100 |
| `items` | JSON array of checklist item definitions |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Checklist item definition:**
```json
{
  "item_name": "Tires",
  "required": true
}
```

**Rules:**
- One org can have multiple templates
- Template is org-scoped (not global)
- Items are ordered (display order matters)
- Required items must be completed; optional items can be skipped
- Default items: Tires, Lights, Brakes, Fluids, Cleanliness, Documents, Exterior, Interior
- Org Admin can add, remove, reorder, and toggle required/optional per item

### 13. Driver Assignments

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `org_id` | FK → `organizations.id` |
| `vehicle_id` | FK → `vehicles.id` |
| `driver_id` | FK → `users.id` (must have `org_driver` role) |
| `assigned_by` | FK → `users.id` (Owner/Manager) |
| `assigned_at` | Timestamp |
| `unassigned_at` | Timestamp (nullable) |
| `status` | `active` \| `completed` |

**Rules:**
- One active assignment per driver at a time
- One active assignment per vehicle at a time
- Driver must have `org_driver` role in the org
- Owner/Manager assigns and unassigns
- `completed` assignments are historical records (unassigned_at is set)
- Active assignment means the driver sees the vehicle in their Driver Mode

### 14. Shift Mileage

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `vehicle_id` | FK → `vehicles.id` |
| `driver_id` | FK → `users.id` |
| `org_id` | FK → `organizations.id` |
| `start_odometer_km` | Integer, required |
| `end_odometer_km` | Integer, required (nullable if shift in progress) |
| `start_at` | Timestamp |
| `end_at` | Timestamp (nullable) |
| `km_driven` | Integer, computed: `end_odometer_km - start_odometer_km` |
| `created_at` | Timestamp |

**Rules:**
- Driver logs start odometer at shift start, end odometer at shift end
- `start_odometer_km` must be ≥ previous shift's `end_odometer_km` for the same vehicle
- `end_odometer_km` must be ≥ `start_odometer_km`
- `km_driven` is computed automatically
- Shift in progress: `end_odometer_km` and `end_at` are null
- Used for cost-per-mile calculations in cost analytics

### 15. Cost Analytics

**Per-vehicle metrics (computed on demand or cached):**
| Metric | Calculation |
|--------|-------------|
| **TCO (Total Cost of Ownership)** | Sum of: maintenance costs (service records) + fuel costs (fuel logs) + wear item costs (expenses with wear categories) |
| **Cost-per-mile** | TCO / total km driven (from shift mileage records) |
| **Revenue label** | Text field from `organization_vehicles.revenue_label` (informational only) |
| **Lemon flag** | `true` if cost-per-mile > lemon threshold (default: 2x fleet average) |
| **Total km driven** | Sum of all `shift_mileage.km_driven` for the vehicle |
| **Utilization rate** | Days vehicle was assigned / total days in period |

**Fleet-wide metrics:**
| Metric | Calculation |
|--------|-------------|
| **Total fleet spend** | Sum of all vehicle TCOs |
| **Average cost-per-mile** | Total fleet spend / Total fleet km |
| **Lemon count** | Number of vehicles with lemon flag |
| **Upcoming maintenance** | Vehicles with maintenance due within 30 days |
| **Active assignments** | Count of active driver assignments |

**Lemon threshold:**
- Default: 2x fleet average cost-per-mile
- Org Admin can override per org (absolute value or multiplier)
- Threshold stored in `organizations.settings` JSON field

### 16. Lifecycle Templates

**Predefined templates:**

| Template | Valid States | Terminal State |
|----------|-------------|----------------|
| `showroom` | `inventory` → `listed` → `reserved` → `sold` | `sold` |
| `taxi_fleet` | `available` → `leased` → `maintenance` → `available` | (none — cycles) |
| `rental` | `available` → `rented` → `return` → `inspection` → `available` | (none — cycles) |
| `commercial` | `available` → `in_service` → `maintenance` → `retired` | `retired` |

**Rules:**
- Owner selects template when adding vehicle to org
- Template cannot be changed after vehicle is added
- Status transitions must follow the template's state machine
- Free-form status allowed within the template's valid states
- Reversals: `showroom` allows `listed→inventory` and `reserved→listed`; others are forward-only
- `taxi_fleet` and `rental` are cyclical (vehicle returns to `available` after service/inspection)

### 17. API Endpoints (v1)

**Fleet Dashboard + Mobile (shared API — `dco-owner` audience):**
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
| POST | `/v1/organizations/:id/work-orders` | `dco-owner` | Create work order — Driver only |
| GET | `/v1/organizations/:id/work-orders` | `dco-owner` | List work orders (filtered by role) |
| GET | `/v1/organizations/:id/work-orders/:workOrderId` | `dco-owner` | View work order detail |
| PATCH | `/v1/organizations/:id/work-orders/:workOrderId` | `dco-owner` | Update work order status — Owner/Manager |
| POST | `/v1/organizations/:id/inspections` | `dco-owner` | Start inspection — Driver only |
| GET | `/v1/organizations/:id/inspections` | `dco-owner` | List inspections (filtered by role) |
| PATCH | `/v1/organizations/:id/inspections/:inspectionId` | `dco-owner` | Complete/fail inspection — Driver |
| GET | `/v1/organizations/:id/inspection-templates` | `dco-owner` | List inspection templates |
| POST | `/v1/organizations/:id/inspection-templates` | `dco-owner` | Create template — Admin only |
| PATCH | `/v1/organizations/:id/inspection-templates/:templateId` | `dco-owner` | Update template — Admin only |
| DELETE | `/v1/organizations/:id/inspection-templates/:templateId` | `dco-owner` | Delete template — Admin only |
| POST | `/v1/organizations/:id/assignments` | `dco-owner` | Assign vehicle to driver — Owner/Manager |
| GET | `/v1/organizations/:id/assignments` | `dco-owner` | List assignments |
| DELETE | `/v1/organizations/:id/assignments/:assignmentId` | `dco-owner` | Unassign — Owner/Manager |
| POST | `/v1/organizations/:id/shift-mileage` | `dco-owner` | Log shift mileage — Driver |
| GET | `/v1/organizations/:id/shift-mileage` | `dco-owner` | List shift mileage records |
| GET | `/v1/organizations/:id/analytics/vehicle/:vehicleId` | `dco-owner` | Per-vehicle TCO, cost-per-mile, lemon flag |
| GET | `/v1/organizations/:id/analytics/fleet` | `dco-owner` | Fleet-wide analytics summary |
| GET | `/v1/organizations/:id/analytics/lemons` | `dco-owner` | List lemon-flagged vehicles |
| POST | `/v1/organizations/:id/analytics/lemon-threshold` | `dco-owner` | Set lemon threshold — Admin only |
| GET | `/v1/drivers/my-vehicle` | `dco-owner` | Driver sees assigned vehicle |
| GET | `/v1/drivers/my-work-orders` | `dco-owner` | Driver sees own work orders |
| GET | `/v1/drivers/my-inspections` | `dco-owner` | Driver sees own inspections |

**Web Admin (User management only — `dco-admin` audience):**
| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| GET | `/v1/admin/users` | `dco-admin` | List users with search/filter |
| GET | `/v1/admin/users/:id` | `dco-admin` | User detail (profile, org, activity) |
| PATCH | `/v1/admin/users/:id/status` | `dco-admin` | Deactivate/reactivate user |
| POST | `/v1/admin/support/invite-resend` | `dco-admin` | Re-send invite email to Org Admin |
| GET | `/v1/admin/support/org-lookup` | `dco-admin` | Search org by name or admin email |
| GET | `/v1/admin/fleet-view` | `dco-admin` | Read-only fleet data for support (cross-org) |

### 18. Mobile Screens

#### Mode Switch (Settings)
- Entry: Settings tab → "Switch to Fleet" toggle
- Toggle visible only if user is org member
- Switching reloads the 4-tab structure with org-scoped content
- Personal mode: same as current (personal vehicles)
- Fleet mode: same tabs (Garage/Maintenance/Expenses/Settings) but filtered to org vehicles
- Driver mode: restricted view (see Driver Mode below)
- Org must be `active` for toggle to appear; `pending` shows "Your organization is being set up" message

#### Org Management Screen (New)
- Entry: Settings → Fleet (after org exists and is active)
- Tabs: Members / Vehicles / Workshops / Settings
- **Members tab**: List with name, role badge, "Change Role" / "Remove" (Admin only)
- **Vehicles tab**: List with status badges (template-specific), counts, "Add Vehicle" / "Import CSV"
- **Workshops tab**: List of approved workshops, "Add Workshop" / "Remove"
- **Settings tab**: Org name, status badge, contact details (read-only — edit requires DCO admin)

#### Vehicle Inventory Screen (New)
- Entry: Fleet mode → Garage tab (replaces personal Garage in fleet mode)
- Header: Vehicle counts by status (template-specific states)
- Vehicle list: Card with photo, name, plate, make/model, status badge, mileage, assigned driver
- Tap → Vehicle Detail (fleet version)
- "Add Vehicle" FAB → Add Vehicle form
- "Import CSV" button → CSV upload flow

#### Add Vehicle Screen (Fleet Version)
- Reuses existing Add Vehicle form from Garage
- Additional fields: Lifecycle Template (dropdown, required), Status (default from template), Warranty Template (optional), Revenue Label (optional text)
- If warranty template selected, warranty instance created on transfer

#### Transfer Vehicle Screen (New)
- Entry: Vehicle Detail → "Transfer to Buyer" (Admin only)
- Steps:
  1. Enter buyer email (autocomplete from existing users)
  2. Select warranty template (dropdown, or "No Warranty")
  3. Confirm sale date and current mileage
  4. Review transfer summary
  5. Confirm → Vehicle transferred
- Post-transfer: Vehicle status → terminal state, `transferred_vehicles` row created, vehicle's `user_id` → buyer

#### Buyer Claim Flow
- Buyer signs up / logs in → Vehicle appears in personal garage automatically
- No acceptance required (email-based auto-assign)
- Vehicle shows full history (pre-transfer maintenance, expenses, documents, fuel logs)
- Warranty status displayed in vehicle detail
- Free plan exempt from 1-vehicle limit for transferred vehicles

#### Driver Mode (New — Restricted View)
- Entry: Settings → Fleet mode toggle (if user has `org_driver` role)
- Simplified 3-tab structure: My Vehicle / My Reports / Settings
- **My Vehicle tab**: Assigned vehicle info (make, plate, photo, documents, maintenance schedule)
- **My Reports tab**: Own work orders and inspections (history + create new)
- **Settings tab**: Profile, switch to Personal mode
- Cannot see: costs, analytics, other vehicles, org settings, member management

#### Driver - My Vehicle Screen (New)
- Shows assigned vehicle only (one at a time)
- Vehicle info: photo, make/model, plate, year, VIN, fuel type
- Documents: registration, insurance (read-only)
- Maintenance schedule: next service due date/km
- Quick actions: "Log Mileage" → shift form, "Log Fuel" → fuel form

#### Driver - Log Mileage Screen (New)
- Entry: My Vehicle → "Log Mileage"
- Start of shift: Enter start odometer → "Start Shift"
- End of shift: Enter end odometer → "End Shift"
- Shows km driven for the shift
- Odometer validated against previous reading

#### Driver - Log Fuel Screen (New)
- Entry: My Vehicle → "Log Fuel"
- Fields: Date, fuel type (dropdown), amount (liters/kWh), cost, odometer
- Reuses existing fuel log form from personal mode

#### Driver - Work Order Screen (New)
- Entry: My Reports → "Report Issue"
- Fields: Issue type (dropdown), description (text), urgency (dropdown), photos (optional)
- Current odometer auto-filled from last shift
- Submit → Work order created with status `reported`
- My Reports list: Shows own work orders with status badges (reported/in_progress/completed)

#### Driver - Inspection Screen (New)
- Entry: My Reports → "Start Inspection"
- Select type: Pre-trip / Post-trip
- Checklist items loaded from org's template
- Each item: Tap to toggle OK/Not OK, optional photo, optional notes
- Required items marked with asterisk
- Submit → Inspection completed (or failed if any item is not_ok)
- Failed inspection auto-generates work order

#### Fleet Owner/Manager - Work Orders Screen (New)
- Entry: Fleet mode → Maintenance tab → "Work Orders" section
- List of all work orders with status badges, vehicle name, driver name, urgency, date
- Filter by: status, urgency, vehicle, driver
- Tap → Work Order Detail:
  - Driver info, vehicle info, issue details, photos
  - Actions: "Start" (→ in_progress), "Resolve" (→ completed + resolution notes)
  - Can assign to mechanic or handle directly

#### Fleet Owner/Manager - Assignments Screen (New)
- Entry: Fleet mode → Settings → "Driver Assignments"
- List of active assignments: Driver name, vehicle name, assigned date
- "Assign Vehicle" → Select vehicle (dropdown) → Select driver (dropdown, org_driver only) → Confirm
- "Unassign" → Confirmation → Assignment completed
- Shows assignment history

#### Fleet Owner/Manager - Reports Screen (New)
- Entry: Fleet mode → Expenses tab → "Analytics" section (or dedicated tab)
- Tabs: Per Vehicle / Fleet Summary / Lemon Flags
- **Per Vehicle tab**: Select vehicle → TCO, cost-per-mile, utilization, maintenance/fuel/wear breakdown
- **Fleet Summary tab**: Total spend, average cost-per-mile, lemon count, upcoming maintenance
- **Lemon Flags tab**: List of vehicles exceeding threshold with cost-per-mile comparison
- Time range filter: This Month / This Year / All Time
- Export button → CSV download

#### Workshop Mobile Screen (New)
- Entry: Workshop user logs in → Sees assigned vehicles list
- Vehicle list: Only vehicles currently under warranty at this workshop
- Vehicle detail: Vehicle info, warranty status, service history (limited to this workshop)
- "Log Service" → Service form (date, odometer, cost, items, notes)
- Cannot see: buyer info, other org vehicles, org member list

### 19. Fleet Dashboard (Next.js — `fleet.yourdomain.com`)

#### Auth
- SSO with DCO mobile credentials (same `dco-owner` JWT audience)
- Route guard: `dco-owner` + org membership → fleet routes; `dco-admin` → read-only fleet view

#### Layout
- Desktop-optimized: sidebar navigation, data tables, charts, bulk actions
- Sidebar items: Dashboard, Vehicles, Work Orders, Inspections, Drivers, Analytics, Settings
- NOT a mobile clone — designed for large screens and productivity

#### Dashboard (Home)
- Summary cards: Total vehicles, Active assignments, Open work orders, Upcoming maintenance, Lemon count
- Recent activity feed: Latest work orders, inspections, status changes
- Quick links: Add vehicle, Assign driver, View reports

#### Vehicle Inventory — Route: `/vehicles`
- **Table view**: Name, plate, make/model, status badge, mileage, assigned driver, lifecycle template, last service
- **Filters**: Status, lifecycle template, assigned driver, maintenance due
- **Sorting**: Any column
- **Bulk actions**: Change status, assign driver, export selected
- **Row actions**: View detail, edit, transfer to buyer
- **Add Vehicle**: Modal or separate page (reuse mobile form, desktop-optimized)
- **CSV Import**: Upload with preview, validation, async processing

#### Work Orders — Route: `/work-orders`
- **Table view**: ID, vehicle, driver, issue type, urgency badge, status badge, reported date, assigned to
- **Filters**: Status (reported/in_progress/completed), urgency, vehicle, driver, date range
- **Bulk actions**: Assign to mechanic, mark in-progress
- **Row actions**: View detail, assign, resolve
- **Detail view**: Driver info, vehicle info, issue description, photos, status timeline, resolution notes
- **Actions**: "Start" (→ in_progress), "Resolve" (→ completed + notes)

#### Inspections — Route: `/inspections`
- **Table view**: ID, vehicle, driver, type (pre/post/random), status badge, date, items failed
- **Filters**: Status, type, vehicle, driver, date range
- **Row actions**: View detail, review failure
- **Detail view**: Checklist items with OK/Not OK status, photos, notes
- **Failed inspections**: Link to auto-generated work order
- **Template Management**: Create/edit/delete inspection templates, manage checklist items

#### Driver Assignments — Route: `/drivers`
- **Active assignments table**: Driver name, vehicle, assigned date, duration
- **Available drivers list**: Drivers without active assignments
- **Available vehicles list**: Vehicles without active driver
- **Assign action**: Select vehicle + driver → confirm
- **Unassign action**: Confirmation → assignment completed
- **Assignment history**: Past assignments with dates

#### Cost Analytics — Route: `/analytics`
- **Per Vehicle tab**: Select vehicle → TCO breakdown (maintenance/fuel/wear), cost-per-mile, utilization, trend chart
- **Fleet Summary tab**: Total spend, average cost-per-mile, lemon count, top/bottom performers
- **Lemon Flags tab**: Vehicles exceeding threshold with cost comparison
- **Time range filter**: This Month / This Quarter / This Year / All Time
- **Export**: CSV download of analytics data

#### Warranty Templates — Route: `/warranty-templates`
- **Template list**: Name, duration, mileage, coverage categories, workshop count
- **Create/Edit**: Form with all template fields
- **Delete**: Confirmation required

#### Org Settings — Route: `/settings`
- **Org info**: Name, contact details (read-only — edit requires DCO admin)
- **Lemon threshold**: Configure multiplier or absolute value
- **Revenue labels**: View/manage revenue labels per vehicle

---

### 20. Web Admin Changes (Next.js — `admin.yourdomain.com`)

#### Auth
- No changes — existing `admin` role with `dco-admin` audience
- Fleet Owner/Manager can sign in for user management only

#### User Management — Route: `/users`
- **Users list**: Table with name, email, role, status, org membership, last login
- **Search**: By name, email, role
- **Filters**: Status (active/inactive), role, has org membership
- **Row actions**: View profile, deactivate/reactivate
- **User detail**: Profile info, org membership, vehicles owned, activity summary

#### Fleet Owner Support — Route: `/support`
- **Pending invites**: List of org admins who haven't set up yet
- **Re-send invite**: Action to re-send invitation email
- **Org lookup**: Search org by name or admin email → link to Fleet Dashboard (read-only)

#### Read-only Fleet Access — Route: `/fleet-view`
- **DCO Admin** can view fleet data for support purposes
- **Read-only**: No write actions (approve work orders, assign drivers, etc.)
- **Cross-org view**: See all organizations and their fleet data
- **Use case**: Support tickets, troubleshooting, auditing

---

## Business Rules

1. **Org creation is admin-only** — only DCO admins can create organizations via the Admin Portal
2. **One organization per user** — enforced at membership level
3. **Fleet Owner must transfer admin role** before leaving or deleting account
4. **Vehicle status transitions follow lifecycle template** — cannot skip states or use invalid states for the template
5. **Warranty expires on earlier of time or mileage** — system checks both on each service log
6. **Only approved workshops can log warranty service** — enforced server-side
7. **Transferred vehicles retain full history** — buyer sees everything
8. **Free plan exempt** — transferred vehicles don't count against 1-vehicle limit
9. **CSV import max 100 rows** — batch limit for performance
10. **Org must be `active`** for Fleet mode to appear on mobile
11. **Workshop visibility is scoped** — only sees assigned vehicles, no buyer info
12. **Mode switch preserves state** — switching between Personal/Fleet/Driver doesn't lose draft data
13. **Archive-not-delete** — organizations are soft-archived, vehicles revert to owners
14. **Invite email is one-time** — if not claimed, DCO admin can re-send from admin portal
15. **One active vehicle per driver** — driver cannot be assigned multiple vehicles simultaneously
16. **One active driver per vehicle** — vehicle cannot have multiple active driver assignments
17. **Work order status transitions** — reported → in_progress → completed (no skipping)
18. **Inspection required items** — all required checklist items must be completed
19. **Failed inspection auto-generates work order** — if any inspection item is not_ok
20. **Mileage monotonicity** — start odometer must be ≥ previous end odometer for same vehicle
21. **Driver visibility is restricted** — drivers cannot see costs, analytics, other vehicles, or org settings
22. **Lemon threshold default** — 2x fleet average cost-per-mile, org can override
23. **Cost analytics uses existing data** — maintenance costs (service records), fuel costs (fuel logs), wear items (expenses)
24. **Revenue label is informational only** — no payment processing or financial calculations

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

Fleet Owner (Mobile - receives email)
  "Your organization [Name] has been created."
  → Logs in to mobile app
  → Settings → Fleet toggle appears (if org is active)
  → Enables Fleet mode → Sees imported vehicles

Fleet Owner (Mobile - Fleet Mode)
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

### Fleet Owner Assigns Driver → Driver Uses Vehicle
```
Fleet Owner (Mobile - Fleet Mode)
  Fleet → Settings → "Driver Assignments"
  → "Assign Vehicle"
  → Select vehicle (Toyota Camry, status: available)
  → Select driver (John Doe, role: org_driver)
  → Confirm → Assignment created

Driver (Mobile - Driver Mode)
  Settings → Fleet toggle → Driver Mode
  → My Vehicle: Shows Toyota Camry
  → "Log Mileage" → Start odometer: 50000 → "Start Shift"
  → ... drives ...
  → "End Shift" → End odometer: 50120 → km driven: 120

  → "Log Fuel" → Date, amount, cost, odometer → Submit

  → "Report Issue" → Type: wear_tear, Description: "Brakes squeaking", Urgency: medium
  → Submit → Work order created (status: reported)

  → "Start Inspection" → Pre-trip
  → Tires: OK, Lights: OK, Brakes: Not OK (photo attached)
  → Submit → Inspection failed → Auto-generates work order

Fleet Owner (Mobile - Fleet Mode)
  Fleet → Maintenance → Work Orders
  → Sees 2 new work orders (brake issue + inspection failure)
  → Tap brake issue → "Start" → Assigned to mechanic
  → ... mechanic fixes brakes ...
  → Tap brake issue → "Resolve" → Resolution notes: "Pads replaced" → Completed
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

Fleet Owner (Mobile - Fleet Mode)
  Fleet → Garage → Vehicle → Service History
  → Sees workshop's service entry
```

### Fleet Owner Views Cost Analytics
```
Fleet Owner (Mobile - Fleet Mode)
  Fleet → Expenses → "Analytics"
  → Per Vehicle tab → Select Toyota Camry
  → TCO: $12,500, Cost-per-mile: $0.42, Utilization: 85%
  → Maintenance: $8,000, Fuel: $3,500, Wear: $1,000

  → Fleet Summary tab
  → Total spend: $125,000, Avg cost-per-mile: $0.38
  → Lemon count: 2 vehicles

  → Lemon Flags tab
  → Honda Civic: $0.78/mile (2.05x avg) — FLAGGED
  → Ford Focus: $0.72/mile (1.89x avg) — FLAGGED

  → Export → CSV downloaded
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
- Role: required, must be `org_manager`, `org_mechanic`, or `org_driver`
- Invitee must not already belong to an org

### Vehicle Add
- Name: required, 1-100 chars
- Make/Model: required
- Year: required, 1900-current+1
- Plate: required, unique within org
- VIN: required, unique globally
- Fuel type: required, must match existing fuel types
- Lifecycle template: required, must be one of: showroom, taxi_fleet, rental, commercial

### CSV Import
- File format: CSV with headers
- Required columns: `name`, `make`, `model`, `year`, `plate`, `vin`, `fuel_type`
- Optional columns: `mileage`, `lifecycle_template`
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

### Work Order
- Vehicle ID: required, must be in same org
- Description: required, 10-2000 chars
- Issue type: required, must be one of: breakdown, accident, wear_tear, scheduled_service, other
- Urgency: required, must be one of: low, medium, high, critical
- Odometer: required, must be ≥ 0
- Photos: optional, max 5 photos, each max 15 MB

### Inspection
- Template ID: required, must exist in same org
- Inspection type: required, must be one of: pre_trip, post_trip, random
- All required items must have a result (ok or not_ok)
- Notes: optional, max 1000 chars

### Driver Assignment
- Vehicle ID: required, must be in same org, must not have active assignment
- Driver ID: required, must have `org_driver` role in same org, must not have active assignment

### Shift Mileage
- Start odometer: required, must be ≥ 0
- End odometer: optional (null if shift in progress), must be ≥ start odometer
- Start odometer must be ≥ previous end odometer for same vehicle

### Lemon Threshold
- Multiplier: optional, must be ≥ 1.0 (default: 2.0)
- Absolute value: optional, must be ≥ 0 (in cost-per-mile currency unit)

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
| Driver already has active assignment | 409 `driver_already_assigned` |
| Vehicle already has active driver | 409 `vehicle_already_assigned` |
| Work order: invalid status transition | 400 `invalid_work_order_status` |
| Inspection: required item not completed | 400 `inspection_incomplete` |
| Mileage: end < start | 400 `invalid_odometer_range` |
| Mileage: start < previous end | 400 `odometer_regression` |
| Driver: not assigned to vehicle | 403 `not_assigned_to_vehicle` |
| Driver: cannot view other vehicles | 403 `driver_access_restricted` |
| Driver: cannot view costs/analytics | 403 `driver_no_cost_access` |
| Work order: vehicle not in org | 404 `work_order_vehicle_not_in_org` |
| Inspection: template not found | 404 `inspection_template_not_found` |

---

## Non-Functional Requirements

- **Offline-first**: Org membership, vehicles, templates, work orders, inspections, assignments sync via existing change log
- **Load time**: Vehicle inventory < 2s (local DB), Org management < 1.5s, Cost analytics < 3s (on demand)
- **Security**: Workshop access validated server-side on every request; buyer info not exposed to workshops; driver access restricted to assigned vehicle only
- **CSV import**: Process in background, return job ID, poll for results
- **Mode switch**: Instant UI swap, no data reload needed (data already synced)
- **Admin portal**: Org creation form submission < 3s (excluding CSV import)
- **Invite email**: Delivered within 60 seconds of org creation
- **Driver mode**: Lightweight UI, optimized for quick actions (log mileage, report issue)
- **Inspection completion**: < 30 seconds for standard 10-item checklist
- **Cost analytics**: Computed on demand for fleets < 50 vehicles; cached hourly for larger fleets
- **Accessibility**: Status badges have text + color; warranty expiry announced to screen readers; inspection items are screen-reader friendly
- **Testability**: Unit tests for warranty expiry logic, status transitions, cost calculations, lemon detection; integration tests for transfer flow, work order lifecycle, inspection flow

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
| `vehicle_added_to_org` | `org_id`, `vehicle_id`, `status`, `lifecycle_template` |
| `vehicle_status_changed` | `org_id`, `vehicle_id`, `old_status`, `new_status` |
| `csv_import_completed` | `org_id`, `source` (admin/mobile), `total_rows`, `success_count`, `fail_count` |
| `warranty_template_created` | `org_id`, `template_id`, `duration_years`, `mileage_limit_km` |
| `vehicle_transferred` | `org_id`, `vehicle_id`, `buyer_email`, `has_warranty` |
| `warranty_service_logged` | `vehicle_id`, `workshop_id`, `odometer`, `is_warranty` |
| `warranty_expired` | `vehicle_id`, `expired_by` (time/mileage) |
| `fleet_mode_switched` | `user_id`, `org_id`, `direction` (personal→fleet / fleet→personal / fleet→driver) |
| `workshop_service_logged` | `vehicle_id`, `workshop_id`, `service_type` |
| `work_order_created` | `org_id`, `vehicle_id`, `driver_id`, `issue_type`, `urgency` |
| `work_order_status_changed` | `org_id`, `work_order_id`, `old_status`, `new_status`, `changed_by` |
| `work_order_resolved` | `org_id`, `work_order_id`, `resolution_time_hours` |
| `inspection_started` | `org_id`, `vehicle_id`, `driver_id`, `inspection_type`, `template_id` |
| `inspection_completed` | `org_id`, `inspection_id`, `result` (completed/failed), `items_failed_count` |
| `inspection_failed` | `org_id`, `inspection_id`, `failed_items` |
| `driver_assigned` | `org_id`, `vehicle_id`, `driver_id`, `assigned_by` |
| `driver_unassigned` | `org_id`, `vehicle_id`, `driver_id`, `assignment_duration_days` |
| `shift_mileage_logged` | `org_id`, `vehicle_id`, `driver_id`, `km_driven` |
| `fuel_logged_by_driver` | `org_id`, `vehicle_id`, `driver_id`, `fuel_type`, `amount`, `cost` |
| `cost_analytics_viewed` | `org_id`, `view_type` (vehicle/fleet/lemons), `vehicle_id` (if vehicle view) |
| `lemon_flag_triggered` | `org_id`, `vehicle_id`, `cost_per_mile`, `threshold` |
| `lemon_threshold_updated` | `org_id`, `old_threshold`, `new_threshold`, `updated_by` |
| `inspection_template_created` | `org_id`, `template_id`, `item_count` |
| `inspection_template_updated` | `org_id`, `template_id`, `items_changed` |
| `report_exported` | `org_id`, `export_type` (vehicle/fleet/lemons), `format` (csv) |

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
- Fleet Owner fleet mode usage frequency
- Admin portal org management actions per week
- Driver adoption rate (% of org_driver members who log mileage weekly)
- Work order creation rate (per driver per month)
- Work order resolution time (average hours from reported to completed)
- Inspection completion rate (% of shifts with completed inspection)
- Inspection failure rate (% of inspections that fail)
- Cost analytics usage (Fleet Owner views per week)
- Lemon flag accuracy (vehicles flagged vs actually replaced)
- CSV export usage (reports exported per month)

---

## Dependencies

- Auth (JWT, roles, audiences — `dco-owner` for Fleet Dashboard + Mobile, `dco-admin` for Web Admin)
- Users API (profile, org membership, email lookup)
- Vehicles API (vehicle CRUD, grants, status)
- Documents API (vault reuse for transferred vehicles)
- Partners API (workshop accounts, approved list)
- Media storage (vehicle photos, inspection photos, work order photos)
- Notifications (warranty expiry reminders, org created email, work order updates)
- Email service (invite emails, org creation notifications)
- Sync (org, membership, vehicle, template, warranty, work order, inspection, assignment entities)
- Admin API (user management only — list, search, deactivate, reactivate)
- Fleet Dashboard API (org CRUD, vehicles, work orders, inspections, assignments, analytics — shared with mobile)
- Existing Maintenance module (plan items, service records — reused for fleet maintenance rules)
- Existing Fuel module (fuel logs, fuel types — reused for driver fuel logging)
- Existing Expenses module (expense categories — reused for cost analytics wear items)

---

## Future Enhancements (Post-Phase 3)

- Multi-location organizations
- Sales pipeline / deal tracking
- CRM integration (buyer follow-ups)
- Telematics / GPS tracking / real-time vehicle tracking
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
- Driver scheduling / shift management
- Insurance premium tracking per vehicle
- Depreciation calculations
- Revenue analytics (actual fare tracking, not just labels)
- GPS-based mileage tracking (automatic odometer)
- Multi-vehicle driver assignments (primary + backup)
- Inspection photo OCR (auto-detect issues)
- Predictive maintenance (AI-based service recommendations)
- Fleet benchmarking (compare across orgs)

---

## Migration Notes

- **Schema**: Add `organizations`, `organization_members`, `organization_vehicles`, `warranty_templates`, `warranty_template_workshops`, `vehicle_warranties`, `transferred_vehicles`, `work_orders`, `inspections`, `inspection_templates`, `driver_assignments`, `shift_mileage` tables
- **Organizations table**: `admin_user_id` (FK → users.id, the Fleet Owner), `created_by` (FK → users.id, the DCO admin), `contact_email`, `contact_phone`, `settings` (JSON — lemon threshold config)
- **Organization members**: Add `org_driver` to role enum
- **Organization vehicles**: Add `lifecycle_template`, `revenue_label` fields; status becomes free-form string
- **Users table**: Add `org_id` nullable FK (denormalized for quick "my org" lookup)
- **Vehicles table**: No change (ownership stays on `user_id`); org link via `organization_vehicles`
- **Partners table**: Add `workshop_account` flag for workshop DCO accounts
- **Sync**: New entity types `organization`, `organization_member`, `organization_vehicle`, `warranty_template`, `vehicle_warranty`, `transferred_vehicle`, `work_order`, `inspection`, `inspection_template`, `driver_assignment`, `shift_mileage`
- **Mobile Drift**: New tables for offline org/vehicles/work_orders/inspections/assignments
- **Fleet Dashboard (fleet.yourdomain.com)**: New Next.js app with desktop-optimized layout, sidebar navigation, data tables, charts. SSO with DCO credentials (`dco-owner` audience). Full fleet management (read + write).
- **Web Admin (admin.yourdomain.com)**: Shrunk to user management only. New routes: `/users` (list, search, deactivate), `/support` (invite resend, org lookup), `/fleet-view` (read-only fleet access for DCO admin support).
- **Admin API**: Reduced to user management endpoints only (`/v1/admin/users/*`, `/v1/admin/support/*`, `/v1/admin/fleet-view`)
- **Fleet API**: Shared between Fleet Dashboard and Mobile (`/v1/organizations/*`, `/v1/drivers/*`). Same endpoints, different consumers.
- **Email templates**: New "Org Created" email template for admin user notification
- **Cost analytics**: Computed on demand initially; consider caching layer for large fleets (100+ vehicles)

---

## Open Decisions

1. **Workshop JWT audience**: Should workshops get a new `dco-workshop` audience, or extend `dco-owner` with a workshop flag?
2. **Buyer auto-creation**: If the buyer email doesn't exist, should we auto-create a pending account (requires email verification) or reject the transfer?
3. **Warranty mileage tracking**: Who updates the vehicle's mileage to check against warranty limits — the workshop on each service, or the owner on each fuel log?
4. **Fleet Owner ownership transfer**: Can the Fleet Owner transfer admin role to another member (like Primary Owner transfer in families)?
5. **Bulk status update**: Can the Fleet Owner change status of multiple vehicles at once (e.g., mark 5 vehicles as `listed`)?
6. **Workshop service on non-warranty vehicles**: Should workshops be able to log service on vehicles not under warranty (general service)?
7. **CSV template download**: Should we provide a CSV template file for import?
8. **Transferred vehicle reversal**: If the buyer returns the vehicle within X days, can the org reclaim it?
9. **Invite expiry**: How long is the invite email valid? Should it expire? Can it be re-sent?
10. **Org suspension effect**: When an org is suspended, should existing vehicles be locked (no status changes) or just new vehicles blocked?
11. **Inspection template sharing**: Can inspection templates be shared across orgs, or are they always org-scoped?
12. **Work order assignment**: Can a work order be assigned to a specific mechanic, or just to the org generally?
13. **Driver fuel cost tracking**: Should the driver's fuel cost be visible to the Fleet Owner in the cost analytics, or just the org-level fuel total?
14. **Cost analytics caching**: Should TCO/cost-per-mile be computed on demand or cached? At what fleet size does caching become necessary?
15. **Lemon threshold notification**: Should the system auto-notify the Fleet Owner when a vehicle crosses the lemon threshold?
16. **Multi-vehicle shifts**: Can a driver use multiple vehicles in one shift (e.g., swap vehicles mid-day)?
17. **Inspection photo requirement**: Should photos be required for `not_ok` inspection items, or just recommended?
18. **Work order urgency escalation**: Should `critical` urgency work orders trigger push notifications or SMS to the Fleet Owner?
19. **Fleet Dashboard vs Mobile parity**: Should the Fleet Dashboard have 100% feature parity with mobile, or are some features web-only (bulk actions, advanced filters) and some mobile-only (quick actions, push notifications)?
20. **Fleet Dashboard deployment**: Same Vercel project as Web Admin with different subdomains, or separate Vercel projects?
21. **DCO Admin org creation**: Since org management moved to Fleet Dashboard, does the DCO Admin still create orgs via Web Admin, or does the Fleet Owner self-serve?
22. **Fleet Dashboard theme**: Should it use the same Garage Minimal Dark theme as mobile, or a different theme optimized for desktop/data-heavy UIs?
