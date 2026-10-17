# Fleet Management Module

## Overview

Fleet Management enables **business accounts** (showrooms, dealerships, taxi fleets, rental companies, commercial fleets) to manage multiple vehicles under an organization, track warranty periods with approved workshops, and transfer vehicle ownership to buyers with full maintenance history. Organizations are created exclusively by AutoX administrators via the Admin Portal (sales-led onboarding). This module extends the existing single-owner model to support multi-vehicle business operations with role-based access, warranty enforcement, ownership transfer, driver work orders, vehicle inspections, and cost analytics.

**Status:** Partial — backend, Fleet Portal (`fleet-portal/`, `dco-fleet`), mobile Driver mode, and Web Admin organization provisioning implemented; Workshop Portal still planned (Phase 3, Year 2). Web Admin does not import initial vehicles during provisioning — seed inventory via the Fleet Portal CSV import after activation.
**Requirement alignment (October 2026) — pending implementation:** Enterprise access-model shift confirmed by grilling: (1) Fleet Portal sidebar visibility is role-based — full nav for `org_admin`, reduced nav for `org_manager`/`org_mechanic`, no portal login for `org_driver`; (2) AutoX Admin provisions the Fleet Admin account with email + temporary password (invite-email provisioning retires); (3) drivers are created/deactivated by the Fleet Admin — ~~username + password and no email~~ superseded: drivers are created on the Fleet Portal **Members** page by **email** (see *Confirmed Access Decisions* 15–24); (4) driver login forces Driver mode; (5) driver deactivation is a soft delete that cascades to active assignments and reserves the username. See *Confirmed Access Decisions* 7–24.
**Driver surface realignment (October 2026 — second grilling; implemented — mobile + backend + Fleet Portal, merged Oct 2026):** Driver mode now mirrors the personal app: **same four tabs** (Garage / Maintenance / Expenses / Settings) and the same screens, with driver-mode repositories mapping to org endpoints (`/organizations/:id/*`, `/drivers/*`) — online-first, no Drift/outbox for org data. Driver-only entry points (**Report Issue**, **Start Inspection**, Refuel, Notes) live in the Dashboard **Quick Actions** grid. Drivers log maintenance from the Maintenance tab through a **Report | Do myself** flow (Report → work order; Do myself → service record). **Shift start/end and live odometer capture are retired** — vehicle mileage is log-driven only (service records + fuel logs), same as personal mode. Drivers are **banned from the personal garage** (server-enforced) but see their assigned vehicle read-only in the Garage tab. On the Fleet Portal, work-order completion now **requires cost** and auto-creates a service record; vehicle detail gains read-only **Service history** and **Maintenance plan** cards. See *Confirmed Access Decisions* 15–24.
**Mobile surface (October 2026 — implemented):** the mobile app serves personal owners and the restricted **Driver** surface only. Fleet management (members, inventory, assignments, work-order resolution, analytics/reports, warranty templates, transfers) lives exclusively on the Fleet Portal; management API routes require the `dco-fleet` audience and are unreachable from mobile's `dco-owner` token. Non-driver org members (`org_admin`/`org_manager`/`org_mechanic`) keep mobile login for their personal garage but have no fleet surface on mobile.
**Maintenance templates (October 2026 — implemented):** vehicle-class maintenance templates (car/motorcycle/truck/van/bus) — platform-seeded globals plus org-scoped copies managed on the Fleet Portal **Maintenance Templates** page; per-vehicle assignment; one-time plan snapshot generation on assignment. Drivers view the generated plan and add items from the template set's suggested list in Driver mode. Contract: [`fleet-maintenance-templates.md`](fleet-maintenance-templates.md).
**Mobile implementation deviations:** the Workshop mobile screen (`dco-workshop` surface) is not implemented.
**Contract:** This FRD extends `product/mvp-scope.md` and `architecture/iam.md`.  
**Surfaces:** Mobile (Flutter — personal owners + fleet drivers), Backend (REST API), Fleet Dashboard (Next.js — `fleet.yourdomain.com` — full fleet management for Fleet Owners/Managers), Web Admin (Next.js — `admin.yourdomain.com` — AutoX user management, organization provisioning/activation, and read-only fleet support).

### Account Plans and Feature Entitlements

| Account/context | Entitlement source | Available capabilities |
|-----------------|--------------------|------------------------|
| Free user (`users.plan=free`) | User account | Basic personal app functionality plus Vehicle Sharing capped at 1 active share (per vehicle and total). No Fleet entry point unless the user has an active organization membership. |
| Paid tier user (`users.plan=lite|standard|fleet`) | User account | Basic personal app functionality + raised caps per `docs/pricing.md` (sharing 3 / unlimited / unlimited; vehicles 3 / 10 / unlimited). Assigned by AutoX Admin for this phase; in-app billing and subscription management are out of scope. |
| Enterprise user | Organization (`organizations.plan=enterprise`) | Basic personal app functionality + Fleet context while the user has an active membership in an `active` Enterprise organization. Organization role limits Fleet actions. Enterprise is not a value of `users.plan`. |

**Entitlement rules:**
- User plan and organization entitlement are independent. An Enterprise member retains their personal plan; Enterprise does not imply Premium or raised sharing limits.
- A Premium user who belongs to an active Enterprise organization can use both Personal and Fleet contexts. Personal mode remains available; Fleet membership does not replace or transfer ownership of personal vehicles.
- Sharing works on both plans: a sharee never needs their own Premium plan to hold or use a share. Premium only raises the owner's per-vehicle/total caps.
- If a Premium owner downgrades, existing shares are NOT revoked — only new share creation is blocked while active shares exceed the free caps. Personal vehicle ownership and records remain with their owners.
- Hide the Fleet entry point when the user has no active organization membership. A sharee's Shared with Me entry stays visible even when that member is on the free plan.
- The API is authoritative: it validates share plan caps and vehicle access level for Vehicle Sharing, and organization plan, status, membership, and role for every Fleet operation. UI visibility is not an authorization boundary.
- Organization provisioning is AutoX-admin-only. New Enterprise organizations start `pending`; only AutoX Admin activation changes status to `active` and enables Fleet access. Suspension removes Fleet access for all members but does not affect their personal app access.

**Audience boundary:** Mobile owner clients use `dco-owner`. The Fleet Dashboard uses `dco-fleet`. Both can call shared Fleet API routes, which independently validate organization membership and role. AutoX support uses `dco-admin` through Web Admin read-only routes.

---

## Objectives

Enable organizations to:

- Be created by AutoX administrators via the Admin Portal (sales-led onboarding)
- Manage vehicle inventory through lifecycle states using predefined templates (showroom, taxi fleet, rental, commercial fleet)
- Configure warranty templates (duration + mileage + approved workshops)
- Transfer vehicle ownership to buyers (new or existing AutoX users) with full history
- Enforce warranty service at approved workshops only
- Maintain read-only audit trail of transferred vehicles
- Import vehicles via CSV or add one-by-one
- Manage approved workshop partnerships
- Assign vehicles to drivers and track driver usage
- Log driver work orders (issue reports) with approval workflow
- Track vehicle inspections via configurable checklists
- Provide cost analytics (TCO, cost-per-mile, lemon detection) per vehicle and fleet-wide
- Enable restricted driver access for maintenance logging, inspections, fuel, and issue reporting

---

## In Scope

### Backend
- Organization entity (created by AutoX admin; Org Admin account created by AutoX admin with email + temporary password, or linked when an account already exists)
- Organization roles: `org_admin`, `org_manager`, `org_mechanic`, `org_driver`
- Driver accounts: created on the Fleet Portal Members page by **email + temporary password** (rejection when the email belongs to an existing account); username remains a global backfilled identifier but is no part of driver creation
- Account identifiers: `users.username` (globally unique) added alongside `users.email` (nullable); login accepts email **or** username
- Temporary-password accounts (`org_admin` via provisioning, drivers via Fleet Admin creation) carry `must_change_password`, enforced server-side
- Organization membership with role-based access
- Predefined lifecycle templates: showroom, taxi_fleet, rental, commercial
- Vehicle lifecycle states (free-form, chosen from template)
- Warranty templates (duration, mileage, coverage, exclusions, approved workshops)
- Per-vehicle warranty instance (sale date, template reference, warranty start mileage)
- Vehicle transfer flow (user_id change + audit table)
- `transferred_vehicles` audit table for org read-only history
- Workshop accounts (type=workshop) with limited vehicle access
- CSV vehicle import endpoint (admin portal + mobile)
- Work order entity (driver reports, 3-step lifecycle: reported → in_progress → completed; optional `plan_item_id` linkage; completion requires cost → auto service record)
- Inspection entity (template-based checklists, pre-trip/post-trip/random)
- Inspection templates (configurable checklist items per org)
- Driver assignment entity (vehicle ↔ driver, one active assignment at a time)
- Driver maintenance logging: do-myself service records (`POST /drivers/vehicles/:id/service-records`, plan-linked or free-text) and Report-branch work orders
- ~~Shift mileage tracking (start/end odometer per shift)~~ **retired October 2026** — mileage is log-driven only
- Cost analytics engine (TCO, cost-per-mile, lemon detection using maintenance + fuel + wear items)
- API endpoints for org management, membership, vehicles, warranties, transfers, workshops, work orders, inspections, assignments, analytics

### Mobile (Flutter)
- **Personal garage**: unchanged for personal owners; non-driver org members keep login for their personal garage only (no fleet surface)
- **Driver Mode**: forced on login for `org_driver`, no mode toggle — **same four tabs and same screens as personal mode** (Garage / Maintenance / Expenses / Settings); driver-mode repositories map to org endpoints (`/organizations/:id/*`, `/drivers/*`), online-first (no Drift/outbox for org data)
- **Driver differences from personal mode**:
  - Garage tab: assigned org vehicle shown **read-only** (single row in My Garage, "+" hidden, no edit/add/archive); spend/expense cards hidden (driver has fuel logs only, no expenses)
  - Expenses tab: **fuel logs only** (existing org fuel endpoints) — no generic expense CRUD
  - Dashboard Quick Actions: **Report Issue · Start Inspection · Refuel · Notes** (personal set: Log Service · History · Refuel · Notes)
  - Maintenance tab: plan (read-only + suggested add) + **Register service** form with **Report | Do myself** branches + merged history (service records + maintenance-Report work orders)
  - Pushed **Reports** screen (Quick Action): own inspections + Report-Issue work orders
  - Personal-garage routes are **server-denied** (403) while an `org_driver` role or active driver assignment exists; Notes stay local-only personal
- **Buyer Claim Flow**: Auto-assigned vehicle appears in buyer's personal garage with full history
- **Workshop Account**: Limited view — current vehicle only, warranty scope only
- Fleet management (mode switch, org management, inventory, transfers, assignments, warranty templates, reports/analytics) is **Fleet Portal only** — removed from mobile; management API routes require the `dco-fleet` audience

### Fleet Dashboard (Next.js — `fleet.yourdomain.com`)
- **Authentication**: SSO with AutoX credentials; Fleet Dashboard token audience is `dco-fleet`
- **Desktop-optimized layout**: Data tables, charts, bulk actions, sidebar navigation
- **Role-based sidebar visibility**: `org_admin` sees the full sidebar; `org_manager` and `org_mechanic` see a reduced sidebar (Dashboard, Vehicles, Work Orders, Inspections, Driver Assignments, Reports, Transferred); `org_driver` cannot log into the Fleet Portal at all
- **Fleet Admin (`org_admin`)**: Full fleet management (read + write) — vehicles, work orders, inspections, assignments, analytics, reports, warranty templates, and member/driver account management
- **Driver management**: Fleet Admin creates driver accounts on the **Members** page by **email + role `org_driver` + temporary password** (the username-only driver-creation endpoint and Web Admin driver management are removed); creation **rejects emails belonging to existing personal accounts**; deactivates/reactivates drivers from the Members page
- **AutoX Admin**: Read-only fleet visibility for support through the Web Admin portal only (`dco-admin`)
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
- **Organization Management**: Create Enterprise organizations in `pending`, link/invite the Org Admin, import initial vehicles, activate/suspend/archive organizations
- **Fleet Owner Support**: Re-send invite emails to Org Admin
- **Read-only Fleet Access**: AutoX Admin can view fleet data for support purposes (no write actions)
- Route guard: `admin` + `dco-admin` audience → Web Admin routes; Fleet members use the separate Fleet Dashboard

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
- Fleet management on the mobile app (management is Fleet Portal only; mobile serves personal garage + Driver mode)

---

## User Personas

| Persona | Description | Primary Surface |
|---------|-------------|-----------------|
| **Fleet Owner** | Business owner (showroom, taxi fleet, rental). Full access to org, vehicles, members, templates, transfers, cost analytics, work order approval. Org created by AutoX admin. | Web (Fleet Portal) |
| **Fleet Manager** | Senior employee. Full operational access: vehicles, work orders, inspections, assignments, cost analytics. Cannot manage org settings or members. | Web (Fleet Portal) |
| **Org Mechanic** | Workshop employee. Logs service, views vehicle info. Cannot add vehicles, manage templates, or transfer. | Web (Fleet Portal) |
| **Driver** | Taxi/rental driver. Org member with `org_driver` role. Account created by the Fleet Admin on the Members page with **email + temporary password**; must change password on first login. Assigned one vehicle at a time. Logs in to the mobile app and is taken directly to Driver mode — the personal four-tab layout with their assigned vehicle read-only. Can log maintenance (Report \| Do myself), complete inspections, report issues, and log fuel from Dashboard quick actions. Restricted view — no costs/analytics, no other vehicles, no personal garage. | Mobile (Driver mode) |
| **Buyer** | Customer who receives a vehicle. Sees vehicle in personal garage with full history. Normal owner after transfer. | Mobile (Personal mode) |
| **Workshop** | External workshop with AutoX account. Logs warranty service on assigned vehicles. Limited visibility. | Mobile (Workshop mode) |
| **Platform Admin** | AutoX staff. Creates orgs, manages org lifecycle, imports vehicles, views fleet stats for support. | Web Admin |

---

## User Stories

### US-FLT-001: Create Organization (Admin Portal)
> As a Platform Admin,  
> I want to create a business organization with name, admin email, and contact details  
> So that a showroom owner can start using Fleet mode on mobile.

### US-FLT-002: Create Org Admin Account (Admin Portal)
> As a Platform Admin,  
> I want to link an existing AutoX user to the new org, or create a new Org Admin account with email and a temporary password  
> So that the Fleet Admin can log in immediately without waiting for an invite email.

### US-FLT-003: Import Vehicles at Creation
> As a Platform Admin,  
> I want to upload a CSV of vehicles during org creation  
> So that the showroom's inventory is ready on day one.

### US-FLT-004: Add Members
> As an Org Admin,  
> I want to add employees to my organization with the Manager or Mechanic role by email, handing new accounts a temporary password  
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
> I want to switch between Personal and Fleet mode from the hamburger menu
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
> I want to receive an email when my organization is created and activated, with instructions to log in and enable Fleet mode
> So that I know my account is ready without contacting support.

### US-FLT-021: Driver Logs Maintenance
> As a Driver,  
> I want to log maintenance on my assigned vehicle — either **Report** it to the fleet (creates a work order) or **Do myself** (records it directly as completed history)  
> So that maintenance is tracked against the plan and the fleet owner sees accurate service history.

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

### US-FLT-035: AutoX Admin Activates Enterprise Organization
> As a AutoX Admin,
> I want to activate a provisioned Enterprise organization after reviewing its setup
> So that Fleet access becomes available to its invited members only when the organization is ready.

### US-FLT-036: Fleet Admin Creates Driver Account
> As a Fleet Admin,
> I want to create a driver account inside the Fleet Portal Members page with an email, role `org_driver`, and a temporary password
> So that the driver receives working credentials, and accounts that already exist as personal users are rejected.

### US-FLT-037: Fleet Admin Deactivates Driver
> As a Fleet Admin,
> I want to deactivate a driver (and reactivate later)
> So that a driver who left the fleet can no longer log in, without destroying their work order, inspection, or mileage history.

### US-FLT-038: Driver Signs In
> As a Driver,
> I want to log in to the mobile app with my email and temporary password (changed on first login)
> So that I can use the same account identity the Fleet Admin invited me with.

### US-FLT-039: Driver Changes Temporary Password
> As a Driver,
> I want to be required to change my admin-set password on first login
> So that the credentials handed out by the Fleet Admin are not left shared or guessable.

### US-FLT-040: Role-Based Fleet Portal Sidebar
> As an Org Member,
> I want the Fleet Portal to show only the navigation my role permits (full for Fleet Admin, reduced for Manager/Mechanic, no portal access for drivers)
> So that the portal matches my responsibilities and never exposes admin-only surfaces.

---

## Functional Requirements

### 1. Organization

| Field | Rule |
|-------|------|
| `id` | UUID, PK |
| `name` | String, required, max 200 |
| `type` | `showroom` \| `dealership` \| `taxi_fleet` \| `rental` \| `commercial` (future: `logistics`) |
| `plan` | `enterprise` (AutoX-admin assigned; no billing in this phase) |
| `status` | `pending` \| `active` \| `suspended` \| `archived` |
| `admin_user_id` | FK → `users.id` (Org Admin — showroom owner) |
| `created_by` | FK → `users.id` (AutoX admin who created it) |
| `activated_by` | FK → `users.id` (nullable; AutoX admin who activated it) |
| `activated_at` | Timestamp (nullable until activation) |
| `contact_email` | String, optional |
| `contact_phone` | String, optional |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- Created exclusively by AutoX admins via the Admin Portal
- `admin_user_id` is the Fleet Admin: linked by email match when an account already exists, otherwise created by the AutoX admin with email + temporary password (`must_change_password` enforced on first login) — invite-email provisioning is retired
- `created_by` is the AutoX admin who performed the creation
- Exactly one `org_admin` per organization; the account is created only by AutoX Admin — the Fleet Admin cannot invite or promote another admin (admin-role transfer remains open decision #3)
- `plan=enterprise` is an organization entitlement; it is distinct from the organization's business `type` and from each member's `users.plan`
- Organization `type` records the business use case; it does not grant or remove features. Vehicle lifecycle template remains a separate per-vehicle choice.
- New organizations are created in `pending`; a AutoX admin explicitly activates them after provisioning is ready
- One organization per `admin_user_id` (enforced by unique `admin_user_id` where `status != archived`)
- A user can belong to only one organization at a time
- `pending` status: org exists but has not been activated by AutoX; Fleet API access is unavailable
- While pending, only the linked Org Admin may be invited/linked; the Org Admin cannot invite other members until the organization is active
- `active` status: AutoX admin has activated the org; active members get fleet access on the Fleet Portal subject to their org roles; `org_driver` members get the Driver surface on mobile
- `suspended` status: AutoX admin has suspended the org; members lose fleet access
- Organization name must be unique per admin (not globally unique)
- Contact details stored for AutoX admin reference

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
- `org_driver` (Driver): Register maintenance (Report | Do myself), complete inspections, report issues, log fuel (entering and seeing its own cost — Decision 14), view assigned vehicle only. Cannot see fleet cost analytics, other vehicles, or org management
- A user can only be invited if they don't already belong to an org
- Any member role grants access to the Fleet context only while the organization is active; the role grants only the operations listed for that role
- `organization_members.role` is separate from `users.role` and does not grant AutoX Admin privileges
- Driver must have `org_driver` role to be eligible for vehicle assignment

**Account and credential rules (added October 2026; driver creation revised October 2026 — second grilling):**
- `users.username`: globally unique, required for all accounts after migration (existing users backfilled from the email local part, collisions suffixed `_2`, `_3`, …); `users.email` becomes nullable
- Login accepts **email or username** in the login identifier field; signup remains email-required (customer flow unchanged)
- **Driver accounts are created only on the Fleet Portal Members page** — email + role `org_driver` + temporary password. The dedicated username-only driver-creation endpoint (`POST /organizations/:id/drivers`) and Web Admin driver management (`/admin/organizations/:id/drivers`) are **removed** (Confirmed Decision 13, finally enforced)
- **Personal-account rejection**: driver creation with an email that already belongs to any existing account is rejected — 409 `personal_account_exists`, surfaced as "This email already has a personal account. Try again with a different email address." A driver identity is therefore always new; **every driver account has an email** (drivers use email-based password recovery like any account)
- Drivers created this way carry `must_change_password=true`; the backend rejects fleet/driver API calls (except profile and password-change endpoints) with 403 `password_change_required` until the password is changed
- **Deactivation (delete driver):** soft delete — `users.status=deactivated`, login blocked, excluded from assignment lists; the active `driver_assignments` row is cascaded to `completed` (frees the vehicle); work orders, inspections, and fuel logs are retained and attributed; reactivation is allowed and re-requires manual vehicle assignment; the username stays **reserved** (never reused)
- A driver may edit only their own profile and password; no other user, vehicle, or org record is writable by a driver (server-enforced)
- **Personal-garage ban**: while a user holds the `org_driver` role or an active driver assignment, personal-garage routes (`/vehicles`, `/vehicle-shares`, owner service/expense/document routes) return 403 `personal_garage_forbidden` — a driver identity never has personal data (the rejection rule above prevents retroactive dual identities)

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
- Workshop gets a AutoX account linked by AutoX Admin (verified partner only); sign-in uses the separate `dco-workshop` audience (`JWT_WORKSHOP_AUD`)
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
| `plan_item_id` | FK → `plan_items.id` (nullable — set when the driver's Report branch came from a plan item) |
| `status` | `reported` \| `in_progress` \| `completed` |
| `assigned_to` | FK → `users.id` (nullable — who is handling it) |
| `resolved_by` | FK → `users.id` (nullable) |
| `resolved_at` | Timestamp (nullable) |
| `resolution_notes` | String, optional, max 2000 |
| `completion_cost` | Numeric (nullable until completion) — **required on the `completed` transition** |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

**Rules:**
- 3-step lifecycle: `reported` → `in_progress` → `completed`
- Two creation paths: **Report Issue** (standalone driver form — breakdown/accident/wear/other) and the maintenance **Report** branch (from the Maintenance tab's Register-service form, typically `scheduled_service`, optionally plan-linked)
- Driver creates work order; Owner/Manager approves and resolves
- `reported` → `in_progress`: Owner/Manager assigns and begins work
- `in_progress` → `completed`: **Admin/Manager only** — completion requires `completion_cost` (400 `completion_cost_required` when missing), optional resolution notes and parts (free-text names allowed; `service_record_parts.part_id` is nullable)
- **Completion auto-creates a service record** for the vehicle: `serviced_on` = completion date, `odometer_km` = **report-time odometer** (stale by design — chosen over a fresh entry), `total_cost` = `completion_cost`, parts/notes copied; this keeps TCO/cost analytics complete for reported repairs
- **Plan linkage**: when `plan_item_id` is set, completion **advances that plan item's `nextDueMileage`/`nextDueOn`** exactly like a do-myself log; plan-linked WOs close the plan loop
- No status skipping allowed
- Driver can view their own work orders only
- Owner/Manager can view all work orders across the org
- Photos stored via existing media pipeline (compressed, 15 MB cap)
- **Placement rule**: work orders appear where they were created — maintenance-Report WOs in the driver's **Maintenance history**; Report-Issue WOs in the driver's pushed **Reports** screen. The auto-created service record is portal-side only and never shown to the driver (the WO row carries the status)

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
- Pre-trip: completed before driving (start of the day's use)
- Post-trip: completed after finishing (end of the day's use)
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

### 14. Shift Mileage — retired (October 2026)

~~Shift start/end odometer logging~~ **Removed by the second grilling.** The `shift_mileage` table and the `POST/PATCH /organizations/:id/shift-mileage` routes are deleted; the mobile Log Mileage screen and shift quick actions are removed. Vehicle mileage is **log-driven only**: service records (driver do-myself, portal completion, workshop) and fuel logs bump `vehicles.mileage` — identical to personal mode. Odometer fields elsewhere (Report Issue, fuel log, register service) auto-fill from `vehicles.mileage` (last known value). Cost-per-mile distance is derived from odometer readings (see §15).

### 15. Cost Analytics

**Per-vehicle metrics (computed on demand or cached):**
| Metric | Calculation |
|--------|-------------|
| **TCO (Total Cost of Ownership)** | Sum of: maintenance costs (service records) + fuel costs (fuel logs) + wear item costs (expenses with wear categories) |
| **Cost-per-mile** | TCO / total km driven (derived from odometer readings — see below) |
| **Revenue label** | Text field from `organization_vehicles.revenue_label` (informational only) |
| **Lemon flag** | `true` if cost-per-mile > lemon threshold (default: 2x fleet average) |
| **Total km driven** | Latest odometer reading − baseline: max minus min of all logged odometer readings (service records + fuel logs), floored at the vehicle's initial mileage at org-add — shift mileage no longer exists |
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

**Fleet Dashboard + Mobile (shared API):** The audience column lists the mobile audience (`dco-owner`) by default. Entitlement and organization/driver routes also accept the Fleet Dashboard audience (`dco-fleet`). Audience identifies the client surface and does not grant organization access. Workshop routes use `dco-workshop`.

`GET /v1/me/entitlements` returns a navigation snapshot such as:
```json
{
  "plan": "free",
  "vehicle_sharing": { "available": true, "can_share": true, "limits": { "per_vehicle": 1, "total": 3 }, "active_shares": 1 },
  "organization": { "id": "uuid", "plan": "enterprise", "status": "active", "role": "org_driver" },
  "features": { "vehicle_sharing": true, "fleet": true }
}
```
`vehicle_sharing.can_share` reflects the plan caps (free 1, lite 3, standard/fleet unlimited) and whether the caller is already at them; `active_shares` counts the caller's outgoing active shares. `features.fleet` is true only for active Enterprise org members. This payload controls navigation visibility only; operation-level role and entitlement checks remain server-side.

| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| GET | `/v1/me/entitlements` | `dco-owner` | Return plan, Vehicle Sharing caps/usage, and active organization context for conditional navigation; a UI hint only |
| GET | `/v1/organizations/me` | `dco-owner` | Get my organization and membership; returns `organization: null` when not a member |
| GET | `/v1/organizations/:id/members` | `dco-owner` | List members with roles |
| POST | `/v1/organizations/:id/members` | `dco-owner` | Add member by email — Admin only; roles `org_manager` / `org_mechanic` / `org_driver` (drivers are created here — no other creation path); new accounts are created with a temporary password returned once — no invite email; **409 `personal_account_exists` when the email belongs to an existing account and the role is `org_driver`** |
| PATCH | `/v1/organizations/:id/members/:userId` | `dco-owner` | Update member role / remove — Admin only |
| ~~POST~~ | ~~`/v1/organizations/:id/drivers`~~ | — | **Removed October 2026** — username-only driver creation retired; drivers use `POST /members` with role `org_driver` |
| POST | `/v1/organizations/:id/members/:userId/status` | `dco-owner` | Deactivate/reactivate driver (soft delete; cascades active assignment) — Admin only |
| POST | `/v1/auth/change-password` | `dco-owner` | Change own password (current password required); clears `must_change_password` |
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
| POST | `/v1/workshops/:vehicleId/service` | `dco-workshop` | Workshop logs service on vehicle |
| GET | `/v1/workshops/my-vehicles` | `dco-workshop` | Workshop sees assigned vehicles |
| POST | `/v1/organizations/:id/work-orders` | `dco-owner` | Create work order — Driver only |
| GET | `/v1/organizations/:id/work-orders` | `dco-owner` | List work orders (filtered by role) |
| GET | `/v1/organizations/:id/work-orders/:workOrderId` | `dco-owner` | View work order detail |
| PATCH | `/v1/organizations/:id/work-orders/:workOrderId` | `dco-owner` | Update work order status — Admin/Manager (completion requires `completion_cost` → auto service record; plan-linked WOs advance the plan item) |
| GET | `/v1/organizations/:id/vehicles/:vehicleId/service-records` | `dco-owner` | Service history for an org vehicle (portal Service-history card; admin/manager/mechanic) |
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
| ~~POST/GET~~ | ~~`/v1/organizations/:id/shift-mileage`~~ | — | **Removed October 2026** — shift mileage retired (§14) |
| GET | `/v1/organizations/:id/analytics/vehicle/:vehicleId` | `dco-owner` | Per-vehicle TCO, cost-per-mile, lemon flag |
| GET | `/v1/organizations/:id/analytics/fleet` | `dco-owner` | Fleet-wide analytics summary |
| GET | `/v1/organizations/:id/analytics/lemons` | `dco-owner` | List lemon-flagged vehicles |
| POST | `/v1/organizations/:id/analytics/lemon-threshold` | `dco-owner` | Set lemon threshold — Admin only |
| GET | `/v1/drivers/my-vehicle` | `dco-owner` | Driver sees assigned vehicle |
| GET | `/v1/drivers/my-work-orders` | `dco-owner` | Driver sees own work orders |
| GET | `/v1/drivers/my-inspections` | `dco-owner` | Driver sees own inspections |
| POST | `/v1/drivers/vehicles/:vehicleId/service-records` | `dco-owner` | **Do myself** — driver logs maintenance directly (plan-linked or free-text; requires cost; advances the plan item when linked) — Driver only, active assignment |

**Web Admin (user and organization management — `dco-admin` audience):**
| Method | Path | Audience | Description |
|--------|------|----------|-------------|
| POST | `/v1/admin/organizations` | `dco-admin` | Create Enterprise organization in `pending`; Org Admin account created with temporary password when none exists (no invite email) |
| PATCH | `/v1/admin/organizations/:id` | `dco-admin` | Edit organization contact/details |
| PATCH | `/v1/admin/organizations/:id/status` | `dco-admin` | Activate, suspend, or archive organization; activation records actor and timestamp |
| GET | `/v1/admin/organizations` | `dco-admin` | List/search organizations and provisioning status |
| GET | `/v1/admin/users` | `dco-admin` | List users with search/filter |
| GET | `/v1/admin/users/:id` | `dco-admin` | User detail (profile, org, activity) |
| PATCH | `/v1/admin/users/:id/status` | `dco-admin` | Deactivate/reactivate user |
| POST | `/v1/admin/support/invite-resend` | `dco-admin` | Legacy: re-send invite email to Org Admin (only pre-alignment pending orgs; new provisioning does not send invites) |
| GET | `/v1/admin/support/org-lookup` | `dco-admin` | Search org by name or admin email |
| GET | `/v1/admin/fleet-view` | `dco-admin` | Read-only fleet data for support (cross-org) |

### 18. Mobile Screens

Mobile serves personal owners and the restricted **Driver** surface. Fleet management is **Fleet Portal only** (October 2026): the mobile Fleet hub, mode switch, and management screens were removed, and management API routes require the `dco-fleet` audience. The management screen specs below (Org Management through Transfer) describe the Fleet Portal surface.

#### Mode Switch — retired
- There is **no mobile Fleet entry or mode switch**. The drawer's Fleet tile, the Fleet hub (`/fleet`), and the stored per-user mode preference were removed.
- `org_driver` accounts are forced into Driver mode: login lands directly on the **personal four-tab layout** (Garage / Maintenance / Expenses / Settings) driven by org data; no personal garage writes, no toggle.
- The old 3-tab Driver shell (My Vehicle / My Reports) is **removed** — My Vehicle's data lives on the personal Dashboard with the assigned vehicle as the active vehicle; Reports became a pushed screen (below).
- `org_admin` / `org_manager` / `org_mechanic` members keep mobile login for their **personal garage only** — no fleet surface is offered on mobile.
- The effective mode is derived from live entitlements (`GET /me/entitlements`); a legacy stored `fleet` mode value degrades to personal. API checks organization plan, status, membership, and role on every request.

#### Org Management Screen (Fleet Portal)
- Entry: Fleet Portal sidebar → Members / Vehicles / Workshops / Settings
- Tabs: Members / Vehicles / Workshops / Settings
- **Members tab**: List with name, role badge, "Change Role" / "Remove" (Admin only)
- **Vehicles tab**: List with status badges (template-specific), counts, "Add Vehicle" / "Import CSV"
- **Workshops tab**: List of approved workshops, "Add Workshop" / "Remove"
- **Settings tab**: Org name, status badge, contact details (read-only — edit requires AutoX admin)

#### Vehicle Inventory Screen (Fleet Portal)
- Entry: Fleet Portal → Vehicles
- Header: Vehicle counts by status (template-specific states)
- Vehicle list: Card with photo, name, plate, make/model, status badge, mileage, assigned driver
- Tap → Vehicle Detail (fleet version)
- "Add Vehicle" FAB → Add Vehicle form
- "Import CSV" button → CSV upload flow

#### Add Vehicle Screen (Fleet Portal)
- Reuses the vehicle form fields
- Additional fields: Lifecycle Template (dropdown, required), Status (default from template), Warranty Template (optional), Revenue Label (optional text)
- If warranty template selected, warranty instance created on transfer

#### Transfer Vehicle Screen (Fleet Portal)
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

#### Driver Mode (Personal Parity View)
- Entry: login as a driver → **forced directly into Driver mode** (no Personal/Fleet toggle is offered to `org_driver` accounts)
- **Same four tabs as personal mode**: Garage / Maintenance / Expenses / Settings — same screens, driver-mode repositories mapping to org endpoints (online-first)
- **Dashboard (Garage tab)**: personal `DashboardScreen` with the assigned org vehicle as the active vehicle; **Quick Actions = Report Issue · Start Inspection · Refuel · Notes** (personal set is Log Service · History · Refuel · Notes); spend/expense cards hidden
- **Garage**: assigned vehicle read-only — My Garage shows a single read-only row, "+" hidden, tap → read-only detail (no edit/archive/share)
- **Maintenance**: plan (read-only + suggested add) · Register service (**Report | Do myself**) · merged history (service records as Completed, maintenance-Report work orders as Reported→Completed)
- **Expenses**: fuel logs only (list + entry) — no generic expense CRUD
- **Settings**: own profile, change password (required on first login when `must_change_password`), sign out; sharing entry points removed
- Pushed **Reports** screen (Dashboard quick action): own inspections + Report-Issue work orders with status chips
- Cannot see: costs, analytics, other vehicles, org settings, member management — and cannot create/edit/delete vehicles or any user record beyond their own profile; personal-garage routes return 403 server-side

#### Driver - Register Service (Report | Do myself) Screen
- Entry: Maintenance tab → **Register service** button (free-text logging entry; plan rows also offer "Log")
- Segmented control: **Report | Do myself** (default: Do myself)
- Shared fields: date (default today), odometer (required, auto-filled from `vehicles.mileage`), item (plan-item picker **or free-text**), cost (**required** — drivers who don't know the cost contact the fleet admin), notes, optional receipt photo
- **Do myself** → `POST /drivers/vehicles/:vehicleId/service-records` → history row appears immediately as **Completed**; when a plan item was picked it is linked (`service_record_items.plan_item_id`) and its `nextDueMileage`/`nextDueOn` advance; **free-text logs are orphans** — they never touch any plan
- **Report** → creates a work order (`scheduled_service`, optional `plan_item_id`) → history row shows **Reported**; flips to **Completed** when the fleet completes the work order (refresh-driven — online-first, no push)
- Drivers may also **add plan items from the suggested list** (existing flow) — but cannot author arbitrary plan items from the form beyond free-text history logs

#### Driver - Work Order / Report Issue Screen (standalone)
- Entry: Dashboard Quick Actions → **Report Issue** (standalone — not absorbed into Register service)
- Fields: Issue type (dropdown), description (text), urgency (dropdown), photos (optional)
- Current odometer auto-filled from `vehicles.mileage` (last known — shift capture no longer exists)
- Submit → Work order created with status `reported`
- History: **Reports screen** (pushed from Quick Actions) lists own Report-Issue work orders with status badges (reported/in_progress/completed)

#### Driver - Inspection Screen
- Entry: Dashboard Quick Actions → **Start Inspection**
- Select type: Pre-trip / Post-trip
- Checklist items loaded from org's template
- Each item: Tap to toggle OK/Not OK, optional photo, optional notes
- Required items marked with asterisk
- Submit → Inspection completed (or failed if any item is not_ok)
- Failed inspection auto-generates work order
- History: inspections also listed in the pushed **Reports** screen

#### Driver - Refuel Screen
- Entry: Dashboard Quick Actions → **Refuel** (or Expenses tab)
- Fields: Date, fuel type (dropdown), amount (liters/kWh), cost, odometer (auto-filled from `vehicles.mileage`)
- Reuses the personal-mode fuel log form; writes to the org fuel endpoint; bumps `vehicles.mileage`

#### Driver - My Garage / Vehicle detail (read-only)
- My Garage: single row for the assigned org vehicle; "+" hidden; no edit/archive/share actions
- Tap → read-only vehicle detail (photo, make/model, plate, year, VIN, fuel type, documents, maintenance schedule)
- Header vehicle chip shows the assigned vehicle; no vehicle switcher (exactly one vehicle)

#### Fleet Owner/Manager - Work Orders Screen (Fleet Portal)
- Entry: Fleet Portal sidebar → Work Orders
- List of all work orders with status badges, vehicle name, driver name, urgency, date
- Filter by: status, urgency, vehicle, driver
- Tap → Work Order Detail:
  - Driver info, vehicle info, issue details, photos
  - Actions: "Start" (→ in_progress), "Resolve" (→ **completed modal: cost required, resolution notes, optional parts**) — Admin/Manager only
  - Resolve creates the service record (report-time odometer) and advances the linked plan item when present
  - Can assign to mechanic or handle directly

#### Fleet Owner/Manager - Assignments Screen (New)
- Entry: **Hamburger menu** → Fleet → Driver Assignments
- List of active assignments: Driver name, vehicle name, assigned date
- "Assign Vehicle" → Select vehicle (dropdown) → Select driver (dropdown, org_driver only) → Confirm
- "Unassign" → Confirmation → Assignment completed
- Shows assignment history

#### Fleet Owner/Manager - Reports Screen (Fleet Portal)
- Entry: Fleet Portal sidebar → Reports
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
- SSO with AutoX credentials; Fleet Dashboard receives the dedicated `dco-fleet` JWT audience
- Route guard: `dco-fleet` + active membership in an active Enterprise organization → organization Fleet routes
- **Login is restricted by org role**: `org_driver` accounts are rejected at Fleet Portal login (drivers use the mobile app only); `org_admin`, `org_manager`, `org_mechanic` may log in
- Organization role authorization applies to every page action and API request
- AutoX Admin read-only support access is available only through Web Admin (`dco-admin`), not through Fleet Dashboard routes

#### Layout
- Desktop-optimized: sidebar navigation, data tables, charts, bulk actions
- **Sidebar visibility matrix (role-based):**

| Sidebar item | `org_admin` | `org_manager` | `org_mechanic` | `org_driver` |
|--------------|:-----------:|:-------------:|:--------------:|:------------:|
| Dashboard | ✓ | ✓ | ✓ | — no portal login — |
| Vehicles | ✓ | ✓ | ✓ | |
| Work Orders | ✓ | ✓ | ✓ (read/log, no approvals) | |
| Inspections | ✓ | ✓ | ✓ (read/log, no approvals) | |
| Driver Assignments | ✓ | ✓ | — | |
| Reports | ✓ | ✓ | — | |
| Transferred | ✓ | ✓ | — | |
| Members (incl. driver CRUD) | ✓ | — | — | |
| Workshops | ✓ | — | — | |
| Warranty Templates | ✓ | — | — | |
| Org Settings | ✓ | — | — | |

- Sidebar filtering is presentation only; every page/API call re-checks org role server-side
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

#### Vehicle detail — `/vehicles/:id`
- **Maintenance plan card** (read-only): generated plan items with next-due mileage/date and overdue/due-soon status — lets a manager verify plan progression after driver logs
- **Service history card**: org service records for the vehicle (driver do-myself logs, portal completions, workshop entries, auto-created WO completion records) — every driver log is checkable here

#### Work Orders — Route: `/work-orders`
- **Table view**: ID, vehicle, driver, issue type, urgency badge, status badge, reported date, assigned to
- **Filters**: Status (reported/in_progress/completed), urgency, vehicle, driver, date range
- **Bulk actions**: Assign to mechanic, mark in-progress
- **Row actions**: View detail, assign, resolve
- **Detail view**: Driver info, vehicle info, issue description, photos, status timeline, resolution notes
- **Actions**: "Start" (→ in_progress), "Resolve" (→ completed — **modal requires cost**, optional resolution notes + parts; auto-creates the service record and advances the linked plan item)

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

#### Members — Route: `/members` (Admin only — hidden from manager/mechanic sidebar)
- **Member list**: name/email or username, role badge, status, joined date
- **Add member**: email + role (`org_manager` / `org_mechanic` / `org_driver`) + optional temporary password — new accounts get the password shown once after adding (**no invite email**); existing accounts are linked unchanged (manager/mechanic only)
- **Create driver**: same email-based form with role `org_driver` — **rejected with 409 `personal_account_exists`** when the email already belongs to any existing account (alert: "This email already has a personal account. Try again with a different email address."); server sets `must_change_password=true`. This is the **only** driver-creation path in the product (the username endpoint and Web Admin driver management are removed)
- **Deactivate driver**: confirmation → soft delete (login blocked, active assignment cascaded to completed, history retained, username reserved)
- **Reactivate driver**: restores login; vehicle must be re-assigned manually
- **Reset driver password**: admin sets a new temporary password (re-arms `must_change_password`)
- **Change role / remove**: existing member role change and removal (admin cannot demote/remove the sole `org_admin`)

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
- **Org info**: Name, contact details (read-only — edit requires AutoX admin)
- **Lemon threshold**: Configure multiplier or absolute value
- **Revenue labels**: View/manage revenue labels per vehicle

---

### 20. Web Admin Changes (Next.js — `admin.yourdomain.com`)

#### Auth
- No changes — existing `admin` role with `dco-admin` audience
- Fleet Owner/Manager do not gain Web Admin access; Fleet operations are in the Fleet Dashboard

#### Organization Provisioning — Route: `/organizations/new`
- Form: org name, type, plan (Enterprise), admin email, optional temporary password, contacts
- **New admin account path**: if no account exists for `admin_email`, the AutoX Admin creates it with the temporary password and `must_change_password=true` — **no invite email is sent**; the AutoX Admin communicates credentials out-of-band
- **Existing account path**: account is linked to the org unchanged (no password reset)
- Existing pending orgs provisioned before the alignment keep their invite/resend behavior (legacy; `invite-resend` retained for them only)

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
- **AutoX Admin** can view fleet data for support purposes
- **Read-only**: No write actions (approve work orders, assign drivers, etc.)
- **Cross-org view**: See all organizations and their fleet data
- **Use case**: Support tickets, troubleshooting, auditing

---

## Business Rules

1. **Org creation is admin-only** — only AutoX admins can create organizations via the Admin Portal
2. **One organization per user** — enforced at membership level
3. **Fleet Owner must transfer admin role** before leaving or deleting account
4. **Vehicle status transitions follow lifecycle template** — cannot skip states or use invalid states for the template
5. **Warranty expires on earlier of time or mileage** — system checks both on each service log
6. **Only approved workshops can log warranty service** — enforced server-side
7. **Transferred vehicles retain full history** — buyer sees everything
8. **Free plan exempt** — transferred vehicles don't count against 1-vehicle limit
9. **CSV import max 100 rows** — batch limit for performance
10. **Org must be `active`** for fleet access (Fleet Portal login; Driver surface on mobile)
11. **Workshop visibility is scoped** — only sees assigned vehicles, no buyer info
12. **Driver mode is derived** — effective mode comes from live entitlements; no stored mode preference
13. **Archive-not-delete** — organizations are soft-archived, vehicles revert to owners
14. **Invite email is one-time (legacy pending orgs only)** — pre-alignment pending org admins can be re-sent from the admin portal; new provisioning uses temporary passwords and sends no invite email
15. **One active vehicle per driver** — driver cannot be assigned multiple vehicles simultaneously
16. **One active driver per vehicle** — vehicle cannot have multiple active driver assignments
17. **Work order status transitions** — reported → in_progress → completed (no skipping)
18. **Inspection required items** — all required checklist items must be completed
19. **Failed inspection auto-generates work order** — if any inspection item is not_ok
20. **Mileage monotonicity** — logged odometer readings (service records, fuel logs) never decrease for a vehicle; mileage advances only through logs (shift capture retired)
21. **Driver visibility is restricted** — drivers cannot see costs, analytics, other vehicles, or org settings; personal-garage routes are server-denied while `org_driver` role or an active assignment exists
22. **Lemon threshold default** — 2x fleet average cost-per-mile, org can override
23. **Cost analytics uses existing data** — maintenance costs (service records), fuel costs (fuel logs), wear items (expenses)
24. **Revenue label is informational only** — no payment processing or financial calculations
25. **Enterprise is organization-scoped** — set `organizations.plan=enterprise`; never encode Enterprise as a user plan or user role
26. **Fleet entitlement requires active org membership** — both organization plan and `status=active` are required; org role determines allowed operations
27. **AutoX Admin activates organizations** — creation starts `pending`; owner login does not activate the org
28. **Org suspension revokes Fleet access** — all members lose Fleet context/API access while personal access remains unchanged
29. **Premium and Enterprise are independent** — an Enterprise member receives Fleet access from membership, not Premium; Premium only raises the Vehicle Sharing caps
30. **Invited sharees do not need Premium** — the vehicle access level (`view` / `add_edit_own`) governs their access to a share
31. **Premium downgrade does not revoke shares** — existing shares keep working; only new share creation is blocked while over the free caps
32. **Feature entry points are hidden when unavailable** — app UI mirrors entitlement, and backend authorization remains authoritative
33. **Fleet Portal sidebar is role-gated** — `org_admin` full nav; `org_manager`/`org_mechanic` reduced nav (Dashboard, Vehicles, Work Orders, Inspections, Driver Assignments, Reports, Transferred); `org_driver` cannot log into the portal; server-side role checks remain authoritative
34. **Drivers are created only by the Fleet Admin via the Members page** — email + role `org_driver` + temporary password; **409 `personal_account_exists`** when the email belongs to an existing account; the username-only creation endpoint and Web Admin driver management are removed
35. **Login accepts email or username** — `users.username` remains a globally unique identifier (backfilled, reserved on deactivation); customer signup remains email-required; driver accounts are email-bearing (created via Members)
36. **Temporary passwords are forced to change** — `must_change_password` blocks fleet/driver API access (except profile/password routes) until changed; backend-enforced, not a UI prompt
37. **Driver deactivation is a soft delete** — status `deactivated`, login blocked, active assignment cascaded to completed, history retained and attributed, reactivation allowed, username reserved forever
38. **Driver login forces Driver mode** — `org_driver` accounts never see Personal/Fleet mode toggles; they get the personal four-tab layout with org data (read-only Garage, fuel-only Expenses)
39. **Fleet Admin is provisioned by AutoX Admin with email + temporary password** — invite-email provisioning retired for new orgs; exactly one admin per org, created only by AutoX Admin (admin transfer remains open decision #3)
40. **Driver password recovery is email-based** — driver accounts always have an email (Members creation), so standard email recovery applies; temporary passwords are still handed over out-of-band at creation
41. **Drivers cannot write user records** — a driver may edit only their own profile/password; no vehicle, org, or other-user create/edit/delete (server-enforced); personal-garage routes return 403
42. **Driver maintenance logging is Report | Do myself** — Report creates a work order (appears in Maintenance history as Reported); Do myself writes a service record immediately Completed; cost is always required (contact fleet admin when unknown); free-text logs never touch a plan
43. **Work-order completion requires cost** — Admin/Manager only; completion auto-creates a service record at the **report-time odometer** and advances the linked plan item (`work_orders.plan_item_id`); the auto service record is portal-only, never shown to the driver
44. **Work orders appear where they were created** — maintenance-Report WOs in Maintenance history; Report-Issue WOs in the pushed Reports screen; no duplicates across feeds
45. **Vehicle mileage is log-driven only** — service records and fuel logs bump `vehicles.mileage`; odometer fields auto-fill from it; shift mileage is retired
46. **Driver Quick Actions** — Dashboard shows Report Issue · Start Inspection · Refuel · Notes; personal mode keeps Log Service · History · Refuel · Notes

---

## User Flow

### Login → Resolve Entitlements → Show Available Features
```
User (Mobile)
  Logs in → app loads account plan and current share/org context
  → Free (`free`) user: basic personal app + Vehicle Sharing within free caps (1 share); no Fleet entry unless invited to an active org
  → Paid tier (`lite`/`standard`/`fleet`) user: basic personal app + Vehicle Sharing within tier caps (3 / unlimited / unlimited)
  → Enterprise org member: basic personal app + Fleet entry only when org is active
  → Paid user who is also an active org member: both Vehicle Sharing and Fleet are available
  → Sharee on `free`: Shared with Me entry is available for their share scope; no paid plan required
  → User may switch Personal/Fleet contexts; personal vehicles remain in Personal mode

Backend (every protected request)
  → Validates user plan caps, vehicle access level, organization plan/status/membership/role
  → Rejects unauthorized actions even if a client presents a stale or forged navigation state
```

### AutoX Admin Creates and Activates Org → Owner Uses Fleet → Manages Vehicles
```
Platform Admin (Web Admin Portal)
  /organizations → "Create Organization"
  → Enter org name, admin email, temporary password, contact details
  → Assign organization plan: Enterprise
  → Create organization with status: pending
  → If no account exists for admin email: Fleet Admin account created with temp password (must change on first login) — no invite email sent
  → If account exists: linked to the org unchanged
  → Optionally upload CSV of vehicles
  → Submit → Org created; AutoX admin reviews provisioning
  → AutoX admin activates organization → status: active
  → System sends activation notice to the linked Org Admin

Fleet Admin (Mobile - receives credentials out-of-band)
  Logs in with email + temp password
  → Forced to change password on first login
  → Hamburger menu → Fleet entry appears (active org membership)
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
  → Enter org details; plan=enterprise; status=pending
  → Upload CSV: 15 vehicles
  → Preview: 15 rows parsed, 14 valid, 1 warning (duplicate VIN)
  → Submit → Org created, 14 vehicles imported; status=pending
  → 1 failed row logged for review
  → AutoX admin reviews setup and activates organization
  → Activation email sent to Org Admin; Fleet access becomes available
```

### Fleet Admin Creates Driver → Driver Uses Vehicle
```
Fleet Admin (Fleet Portal - Members page)
  Members → "Add member" → role: Driver (org_driver)
  → Email: john@driverco.com, Temporary password: ********
  → (Email belongs to an existing personal account? → rejected: 409 personal_account_exists)
  → Submit → Driver account created (must_change_password: true)

Fleet Admin → "Assign Vehicle"
  → Select vehicle (Toyota Camry, status: available)
  → Select driver (John Doe, role: org_driver)
  → Confirm → Assignment created

Driver (Mobile - first login)
  Logs in with email + temporary password
  → Forced password change screen → sets new password
  → Lands in Driver mode: personal four-tab layout (Garage / Maintenance / Expenses / Settings)
  → Garage: Toyota Camry shown read-only as the active vehicle

  → Dashboard Quick Actions → "Refuel" → Date, amount, cost, odometer (auto-filled) → Submit
     → mileage advances (log-driven only)

  → Maintenance tab → "Register service"
  → Item: Oil Change (from plan), odometer auto-filled, cost: 45
  → Branch "Do myself" → Submit → history row: Completed; plan item advances
  → Branch "Report"  → Submit → history row: Reported (work order created)

  → Dashboard Quick Actions → "Report Issue" → Type: breakdown, Description: "Brakes squeaking", Urgency: high
  → Submit → work order (status: reported) appears in the Reports screen

  → Dashboard Quick Actions → "Start Inspection" → Pre-trip
  → Tires: OK, Lights: OK, Brakes: Not OK (photo attached)
  → Submit → Inspection failed → Auto-generates work order

Fleet Admin / Manager (Fleet Portal - Work Orders)
  → Sees new work orders (brake issue + inspection failure)
  → Tap brake issue → "Start" → Assigned to mechanic
  → ... mechanic fixes brakes ...
  → Tap brake issue → "Resolve" → Cost: 120, Notes: "Pads replaced" → Completed
  → Service record auto-created (report-time odometer); driver's Reports screen shows Completed on next refresh

Fleet Admin (Fleet Portal - Members page)
  → Deactivate driver (left the company)
  → Assignment cascaded to completed; login blocked; history retained; username reserved
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
- Type: required, one of `showroom`, `dealership`, `taxi_fleet`, `rental`, `commercial`
- Plan: required, `enterprise`, assigned by AutoX Admin; no billing flow in this phase
- Admin email: required, valid email format
- Temporary password: required when no account exists for the admin email (min 8 chars); applied with `must_change_password=true`; not sent by email
- Initial status: server sets `pending`; only a AutoX Admin can transition it to `active` after provisioning
- Contact email: optional, valid email format
- Contact phone: optional, max 20 chars

### Feature Access
- Fleet access requires `organizations.plan=enterprise`, `status=active`, and an active membership for the authenticated user
- Role checks apply after entitlement checks; user-level `plan` does not grant Fleet access
- Vehicle Sharing caps are plan-scoped: free 1, lite 3, standard/fleet unlimited (see `vehicle-sharing.md`)
- Sharees retain `view` / `add_edit_own` access without their own paid plan
- `GET /v1/me/entitlements` is a display/navigation hint; protected API routes independently enforce access

### Member Invitation (Manager / Mechanic / Driver)
- Email: required, valid email format
- Role: required, must be `org_manager`, `org_mechanic`, or `org_driver`
- Invitee must not already belong to an org
- **Driver role extra rule**: the email must not already belong to any existing account — otherwise 409 `personal_account_exists` (a driver identity is always new; manager/mechanic linking of existing accounts is unchanged)

### Driver Creation (Fleet Admin only — Members page)
- Email: required, valid email format; **rejected when an account already exists** (409 `personal_account_exists`)
- Role: fixed `org_driver`
- Temporary password: optional (server-generated when omitted), min 8 chars, applied with `must_change_password=true`
- Deactivate/reactivate: admin only; deactivation cascades active assignment; reactivation requires manual re-assignment
- No username-only creation path exists (endpoint removed)

### Login
- Identifier: required — either a valid email or a username (lookup is case-insensitive)
- Customer self-signup remains email-required; username login is available to any account after backfill
- Fleet Portal login additionally requires org role ∈ {`org_admin`, `org_manager`, `org_mechanic`} (drivers are rejected)

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
- Odometer: required, must be ≥ 0 (auto-filled from `vehicles.mileage`)
- Photos: optional, max 5 photos, each max 15 MB
- `plan_item_id`: optional, must be a plan item of the assigned vehicle
- **Completion (Admin/Manager)**: `completion_cost` required (≥ 0); resolution notes optional; parts optional (free-text names allowed); report-time odometer stamped on the auto-created service record

### Driver Service Record (Do myself)
- Odometer: required, auto-filled from `vehicles.mileage`, must be ≥ current (monotonic)
- Serviced on: required, today or past
- Item: plan item of the assigned vehicle, or free-text name (free-text = orphan, never advances a plan)
- Cost: **required** (≥ 0) — `total_cost` is NOT NULL
- Notes/photos: optional

### Inspection
- Template ID: required, must exist in same org
- Inspection type: required, must be one of: pre_trip, post_trip, random
- All required items must have a result (ok or not_ok)
- Notes: optional, max 1000 chars

### Driver Assignment
- Vehicle ID: required, must be in same org, must not have active assignment
- Driver ID: required, must have `org_driver` role in same org, must not have active assignment

### Lemon Threshold
- Multiplier: optional, must be ≥ 1.0 (default: 2.0)
- Absolute value: optional, must be ≥ 0 (in cost-per-mile currency unit)

---

## Error States

| Scenario | Response |
|----------|----------|
| User is at or over their plan's Vehicle Sharing caps | 403 `share_limit_reached` |
| User lacks active Enterprise organization membership | 403 `fleet_access_required` |
| Organization is not Enterprise-entitled | 403 `enterprise_org_required` |
| User has no active membership in requested org | 403 `not_org_member` |
| User's org role does not permit requested operation | 403 `insufficient_org_role` |
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
| Not AutoX admin (for org creation) | 403 `not_dco_admin` |
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
| Username already taken | 409 `username_taken` |
| Invalid username format | 400 `invalid_username` |
| Temporary password not yet changed | 403 `password_change_required` |
| Deactivated driver attempts login | 401 `deactivated` |
| Driver attempts Fleet Portal login | 403 `portal_access_restricted` |
| Fleet Admin tries to create/promote a second org admin | 403 `insufficient_org_role` |
| Work order: vehicle not in org | 404 `work_order_vehicle_not_in_org` |
| Inspection: template not found | 404 `inspection_template_not_found` |
| Driver creation email belongs to an existing account | 409 `personal_account_exists` |
| Work order completion without cost | 400 `completion_cost_required` |
| Driver touches personal-garage routes | 403 `personal_garage_forbidden` |

---

## Non-Functional Requirements

- **Offline-first**: personal-mode data syncs via the existing change log; the **Driver surface is online-first by contract** — driver lists/forms read and write over HTTP (entitlements JSON cached in `AppMeta` as offline fallback), no Drift/outbox for org data
- **Load time**: Vehicle inventory < 2s (local DB), Org management < 1.5s, Cost analytics < 3s (on demand)
- **Security**: Workshop access validated server-side on every request; buyer info not exposed to workshops; driver access restricted to assigned vehicle only
- **CSV import**: Process in background, return job ID, poll for results
- **Mode switch**: Instant UI swap, no data reload needed (data already synced)
- **Admin portal**: Org creation form submission < 3s (excluding CSV import)
- **Provisioning**: Fleet Admin credentials are produced synchronously at org creation (no invite-email wait); member adds return the temporary password synchronously (no invite email); activation notice sent on activation
- **Driver mode**: Personal-parity four-tab UI with quick actions optimized for quick logging (report issue, log maintenance, inspection)
- **Inspection completion**: < 30 seconds for standard 10-item checklist
- **Cost analytics**: Computed on demand for fleets < 50 vehicles; cached hourly for larger fleets
- **Accessibility**: Status badges have text + color; warranty expiry announced to screen readers; inspection items are screen-reader friendly
- **Testability**: Unit tests for warranty expiry logic, status transitions, cost calculations, lemon detection; integration tests for transfer flow, work order lifecycle, inspection flow

---

## Analytics Events

| Event | Properties |
|-------|------------|
| `admin_org_created` | `org_id`, `admin_user_id`, `plan`, `vehicle_count`, `status` (`pending`) |
| `admin_org_activated` | `org_id`, `activated_by`, `activated_at` |
| `admin_org_edited` | `org_id`, `fields_changed` |
| `admin_org_suspended` | `org_id`, `reason` |
| `admin_org_archived` | `org_id`, `vehicle_count`, `member_count` |
| `admin_invite_sent` | `org_id`, `admin_email`, `user_existed` |
| `admin_org_admin_created` | `org_id`, `admin_user_id` (temp-password account created at provisioning) |
| `driver_account_created` | `org_id`, `driver_user_id`, `email`, `created_by` |
| `driver_account_deactivated` | `org_id`, `driver_user_id`, `assignments_cascaded` |
| `driver_account_reactivated` | `org_id`, `driver_user_id` |
| `password_changed` | `user_id`, `forced` (must_change_password flow) |
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
| `maintenance_logged_by_driver` | `org_id`, `vehicle_id`, `driver_id`, `mode` (do_myself/report), `plan_item_id?`, `cost` |
| `fuel_logged_by_driver` | `org_id`, `vehicle_id`, `driver_id`, `fuel_type`, `amount`, `cost` |
| `cost_analytics_viewed` | `org_id`, `view_type` (vehicle/fleet/lemons), `vehicle_id` (if vehicle view) |
| `lemon_flag_triggered` | `org_id`, `vehicle_id`, `cost_per_mile`, `threshold` |
| `lemon_threshold_updated` | `org_id`, `old_threshold`, `new_threshold`, `updated_by` |
| `inspection_template_created` | `org_id`, `template_id`, `item_count` |
| `inspection_template_updated` | `org_id`, `template_id`, `items_changed` |
| `report_exported` | `org_id`, `export_type` (vehicle/fleet/lemons), `format` (csv) |

---

## Success Metrics

- Organizations created per week (by AutoX admins)
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
- Driver adoption rate (% of org_driver members who log maintenance or fuel weekly)
- Work order creation rate (per driver per month)
- Work order resolution time (average hours from reported to completed)
- Inspection completion rate (% of driver-days with a completed inspection)
- Inspection failure rate (% of inspections that fail)
- Cost analytics usage (Fleet Owner views per week)
- Lemon flag accuracy (vehicles flagged vs actually replaced)
- CSV export usage (reports exported per month)

---

## Dependencies

- Auth (JWT, roles, audiences — `dco-fleet` for Fleet Dashboard, `dco-owner` for Mobile, `dco-admin` for Web Admin)
- Users API (profile, org membership, username/email login lookup)
- Vehicles API (vehicle CRUD, grants, status)
- Documents API (vault reuse for transferred vehicles)
- Partners API (workshop accounts, approved list)
- Media storage (vehicle photos, inspection photos, work order photos)
- Notifications (warranty expiry reminders, org created email, work order updates)
- Email service (org activation notices, email verification and password resets for email-bearing accounts — provisioning and driver creation send no emails; drivers without email are excluded by design)
- Sync (org, membership, vehicle, template, warranty, work order, inspection, assignment entities)
- Admin API (user management plus organization provisioning/activation and read-only support lookup)
- Fleet Dashboard API (org operations, vehicles, work orders, inspections, assignments, analytics — shared with mobile)
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
- Org transfer between AutoX admins
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

- **Schema**: Add `organizations`, `organization_members`, `organization_vehicles`, `warranty_templates`, `warranty_template_workshops`, `vehicle_warranties`, `transferred_vehicles`, `work_orders`, `inspections`, `inspection_templates`, `driver_assignments` tables; ~~`shift_mileage`~~ removed (October 2026); `work_orders.plan_item_id` FK added; `service_record_parts.part_id` made nullable (free-text parts)
- **Organizations table**: `plan=enterprise`, `status` (starts `pending`), `admin_user_id` (FK → users.id, the Fleet Owner), `created_by` and nullable `activated_by` (AutoX admin FKs), `activated_at`, `contact_email`, `contact_phone`, `settings` (JSON — lemon threshold config)
- **Organization members**: Add `org_driver` to role enum
- **Organization vehicles**: Add `lifecycle_template`, `revenue_label` fields; status becomes free-form string
- **Users table**: Add `org_id` nullable FK (denormalized for quick "my org" lookup)
- **Vehicles table**: No change (ownership stays on `user_id`); org link via `organization_vehicles`
- **Partners table**: Add `workshop_account` flag for workshop AutoX accounts
- **Users table**: Add `username` (NOT NULL after backfill, globally unique), make `email` nullable (Postgres UNIQUE already permits multiple NULLs), add `must_change_password` boolean; backfill usernames from email local part (collisions suffixed `_2`, `_3`, …); `status=deactivated` reused for driver soft delete with assignment cascade
- **Sync**: New entity types `organization`, `organization_member`, `organization_vehicle`, `warranty_template`, `vehicle_warranty`, `transferred_vehicle`, `work_order`, `inspection`, `inspection_template`, `driver_assignment`
- **Mobile Drift**: personal-mode only — the Driver surface is **online-first** (no Drift/outbox tables for org data; entitlements cached in `AppMeta`)
- **Fleet Dashboard (fleet.yourdomain.com)**: New Next.js app with desktop-optimized layout, sidebar navigation, data tables, charts. SSO uses `dco-fleet`; full fleet management requires active Enterprise membership.
- **Web Admin (admin.yourdomain.com)**: User management plus AutoX-only org provisioning/activation. Routes include `/users`, `/support`, `/organizations`, and `/fleet-view` (read-only fleet support).
- **Admin API**: User and organization management endpoints (`/v1/admin/users/*`, `/v1/admin/organizations/*`, `/v1/admin/support/*`, `/v1/admin/fleet-view`)
- **Fleet API**: Shared between Fleet Dashboard (`dco-fleet`) and Mobile (`dco-owner`) for `/v1/organizations/*` and `/v1/drivers/*`; both enforce the same org plan/status/membership/role checks.
- **Email templates**: Organization activated notifications to the linked Org Admin; Fleet Admin temp-password provisioning, member adds, and driver creation send **no** emails (credentials communicated out-of-band as temporary passwords)
- **Cost analytics**: Computed on demand initially; consider caching layer for large fleets (100+ vehicles)

---

## Confirmed Access Decisions

1. Enterprise entitlement belongs to the organization (`organizations.plan=enterprise`); it is not a user plan or user role.
2. Enterprise and the user plan are independent. Plans are AutoX-admin-managed for this phase; no purchase/billing flow is included.
3. Vehicle Sharing is open to every plan within caps (free 1, lite 3, standard/fleet unlimited); sharees use granted access without their own paid plan. A downgrade revokes shares above the new caps (oldest kept) and blocks new creation while over the cap.
4. Fleet access requires active membership in an active Enterprise organization; membership role limits actions. Organization provisioning starts pending and AutoX Admin explicitly activates it.
5. Hide unavailable Vehicle Sharing/Fleet entry points. API authorization is authoritative and re-checks plan caps, vehicle access level, membership, status, and role.
6. Flutter uses `dco-owner`; Fleet Dashboard uses `dco-fleet`; AutoX support uses `dco-admin` through Web Admin. Workshop accounts follow the separate `dco-workshop` audience in `architecture/iam.md`.
7. **(Oct 2026)** The four organization roles stand; "Fleet Admin" means `org_admin`. Fleet Portal sidebar visibility is role-based: full nav for `org_admin`, reduced nav (Dashboard, Vehicles, Work Orders, Inspections, Driver Assignments, Reports, Transferred) for `org_manager`/`org_mechanic`, and no portal login for `org_driver`. The mobile Fleet entry is retired: mobile serves the personal garage plus the Driver surface for `org_driver` only, and management routes require the `dco-fleet` audience.
8. **(Oct 2026)** AutoX Admin provisions the Fleet Admin account with email + temporary password (forced change on first login); invite-email provisioning retires for new organizations. Exactly one `org_admin` per org, created only by AutoX Admin — no self-promotion or deputy admins.
9. ~~**(Oct 2026)** Drivers are created exclusively by the Fleet Admin with username + display name + initial password and **no email**. `users.username` is globally unique and is the driver login identifier; `users.email` becomes nullable; login accepts email or username. Email member invite is limited to `org_manager`/`org_mechanic`.~~ **Superseded (Oct 2026, second grilling):** drivers are created on the **Members page by email** (role `org_driver` + temporary password) with rejection of emails belonging to existing accounts; the username-only creation endpoint and Web Admin driver management are removed. `users.username` stays a global identifier; login still accepts email or username.
10. **(Oct 2026)** Driver deletion is a soft delete: `status=deactivated`, login blocked, active `driver_assignments` cascaded to completed, history retained and attributed, reactivation allowed (manual re-assignment required), username reserved permanently.
11. **(Oct 2026)** Driver login forces Driver mode — no Personal/Fleet toggle for `org_driver` accounts; Driver mode is the **personal four-tab layout with org data** (second grilling — see decision 16). Drivers may edit only their own profile and password; all vehicle/user/org writes remain server-denied, including personal-garage routes (403).
12. **(Oct 2026)** Temporary passwords (`must_change_password`) are enforced backend-side: fleet/driver API calls except profile/password routes return 403 `password_change_required` until changed.
13. **(Oct 2026)** The Fleet Portal Members page (admin-exclusive) is the separate dashboard for user management: driver create/deactivate/reactivate/password-reset plus the existing manager/mechanic invite. AutoX Web Admin keeps organization provisioning only and never manages drivers.
14. **(Oct 2026)** When a driver logs fuel, they record and see the full cost/amount — resolving former open decision #11 in favor of full driver cost entry.

### Driver Surface Decisions (October 2026 — second grilling)

15. **Driver creation is Members-only and email-based** — role `org_driver` + temporary password; **409 `personal_account_exists`** when the email belongs to any existing account (alert: "This email already has a personal account. Try again with a different email address."). `POST /organizations/:id/drivers` and Web Admin driver endpoints/UI are deleted (enforcing decision 13). Every driver account therefore has an email and standard email recovery applies.
16. **Driver mode = personal parity** — same four tabs (Garage / Maintenance / Expenses / Settings) and same screens as personal mode; driver-mode repositories map to org endpoints (`/organizations/:id/*`, `/drivers/*`); online-first retained (no Drift/outbox for org data). The 3-tab shell (My Vehicle / My Reports) is removed; Reports becomes a pushed screen.
17. **Driver Quick Actions** — Dashboard grid shows **Report Issue · Start Inspection · Refuel · Notes**; personal mode keeps Log Service · History · Refuel · Notes. Report Issue stays a **standalone** screen (not absorbed into Register service).
18. **Driver maintenance logging = Report | Do myself** (Maintenance tab → Register service): Report creates a work order (`scheduled_service`, optional `plan_item_id`) shown as **Reported** in Maintenance history; Do myself writes a service record shown as **Completed** immediately. Cost is **required** on both paths (contact fleet admin when unknown). Plan-linked logs advance the plan item; **free-text do-myself logs are orphans** (never touch a plan). Suggested-item adds remain available.
19. **Work-order completion requires cost** — Admin/Manager only; auto-creates a service record using the **report-time odometer**, with notes and parts (free-text parts allowed — `service_record_parts.part_id` nullable); plan-linked WOs advance the plan item (`work_orders.plan_item_id` added). The auto service record is portal-side only — the driver's history shows the **WO row** carrying the status (no duplicate rows); Reported→Completed flips on refresh.
20. **Work orders appear where they were created** — maintenance-Report WOs in Maintenance history; Report-Issue WOs in the pushed Reports screen (which also lists the driver's inspections).
21. **Shift mileage is retired** — `shift_mileage` table and routes deleted; mileage is log-driven only (service records + fuel logs bump `vehicles.mileage`); odometer fields auto-fill from `vehicles.mileage`; cost-per-mile distance derives from logged odometer readings.
22. **Personal garage is server-denied to drivers** — 403 `personal_garage_forbidden` on personal routes while `org_driver` role or an active assignment exists; client shows friendly states instead of raw errors. The Garage tab itself works read-only: assigned vehicle as the single My Garage row, "+" hidden, no edit/archive/share; spend cards hidden.
23. **Driver Expenses = fuel logs only** — no generic expense CRUD for drivers (no new org expense endpoints); mileage/cost flow through existing org fuel routes.
24. **Fleet Portal closes the loop** — `GET /organizations/:id/vehicles/:vehicleId/service-records` + read-only **Service history** and **Maintenance plan** cards on vehicle detail make every driver log checkable by the fleet.

## Remaining Open Decisions

1. **Buyer auto-creation**: If the buyer email doesn't exist, should we auto-create a pending account (requires email verification) or reject the transfer?
2. **Warranty mileage tracking**: Who updates the vehicle's mileage to check against warranty limits — the workshop on each service, or the owner on each fuel log?
3. **Fleet Owner ownership transfer**: Can the Fleet Owner transfer admin role to another member (like vehicle ownership transfer for shared vehicles)?
4. **Bulk status update**: Can the Fleet Owner change status of multiple vehicles at once (e.g., mark 5 vehicles as `listed`)?
5. **Workshop service on non-warranty vehicles**: Should workshops be able to log service on vehicles not under warranty (general service)?
6. **CSV template download**: Should we provide a CSV template file for import?
7. **Transferred vehicle reversal**: If the buyer returns the vehicle within X days, can the org reclaim it?
8. ~~**Invite expiry**~~ **Resolved (Oct 2026)** — member adds and new org provisioning no longer send invite emails; credentials are handed over as a temporary password at creation time. Re-send remains only for legacy pending orgs.
9. **Inspection template sharing**: Can inspection templates be shared across orgs, or are they always org-scoped?
10. **Work order assignment**: Can a work order be assigned to a specific mechanic, or just to the org generally?
11. ~~**Driver fuel cost tracking**~~ **Resolved (Oct 2026)** — drivers enter and see the full fuel cost/amount; cost flows into org cost analytics. See Confirmed Access Decision 14.
12. **Cost analytics caching**: Should TCO/cost-per-mile be computed on demand or cached? At what fleet size does caching become necessary?
13. **Lemon threshold notification**: Should the system auto-notify the Fleet Owner when a vehicle crosses the lemon threshold?
14. ~~**Multi-vehicle shifts**~~ **Retired (Oct 2026)** — shift mileage was removed entirely (see Driver Surface Decision 21); multi-vehicle shift questions no longer apply.
15. **Inspection photo requirement**: Should photos be required for `not_ok` inspection items, or just recommended?
16. **Work order urgency escalation**: Should `critical` urgency work orders trigger push notifications or SMS to the Fleet Owner?
17. **Fleet Dashboard vs Mobile parity**: Should the Fleet Dashboard have 100% feature parity with mobile, or are some features web-only (bulk actions, advanced filters) and some mobile-only (quick actions, push notifications)?
18. **Fleet Dashboard deployment**: Same Vercel project as Web Admin with different subdomains, or separate Vercel projects?
19. **Fleet Dashboard theme**: Should it use the same Garage Minimal Dark theme as mobile, or a different theme optimized for desktop/data-heavy UIs?
