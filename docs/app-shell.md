# App shell and navigation IA

**Status:** Spec. Source screens: `wireframes/dco-mobile-wireframes.tldraw`. Auth screens are in that file; this document does not redesign them.

Default after a successful owner login: **Dashboard** (frame `3. Dashboard (Default Vehicle Detail)`).

---

## Owner app — bottom navigation + hamburger menu

Four bottom tabs (consistent for normal users and fleet owners) plus a hamburger menu (drawer) for additional features.

### Bottom tabs

| Tab (UI) | GoRouter path | Tldraw frame | Role |
|----------|---------------|--------------|------|
| **Garage** | `/dashboard` | **3** Dashboard (and **3** empty) | Home. Active vehicle summary. Default after login. |
| **Maintenance** | `/maintenance` | **6** Maintenance (and **6** empty) | Plan + history for the active vehicle. |
| **Expenses** | `/expenses` | **7** Expenses | Spend for the active vehicle. |
| **Setting** | `/settings` | **9** Settings | Account and profile. Minimal — most features moved to hamburger. |

Active tab icon uses design-token gold (`icon.active`). Inactive uses slate (`icon.inactive`).

### Hamburger menu (drawer)

Accessible from **any screen** via the leading hamburger icon in the app bar. Opens a side drawer with the following sections:

#### Quick Access (top section)
| Menu Item | Icon | Destination | Notes |
|-----------|------|-------------|-------|
| **Sync** | refresh | Sync Status screen | Moved from Settings. Compact status indicator + manual sync button. |

#### Features (middle section)
| Menu Item | Icon | Destination | Notes |
|-----------|------|-------------|-------|
| **My Garage** | Car |  My Garage | List of viehicle screen. Add new, detail can be checked. |
| **Documents** | folder | Document List | Moved from Settings. Per-vault document management. |
| **Parts** | wrench | Parts List | Entry point also kept on Dashboard quick actions. |
| **Maintenance Plan** | clipboard-list | Maintenance Plan | Moved from Maintenance tab. Upcoming/Scheduled/History. |
| **Insurance** | shield | Insurance section | Moved from Garage. Vehicle insurance documents/status. *Not Implemented* Hide for now. |
| **Fuel Stats** | chart-bar | Fuel Stats screen | Adaptive: charge KPIs for electric, refuel KPIs otherwise. Charts for cost trends, efficiency, cost per distance. |
| **Maintenance Stats** | chart-bar | Maintenance Stats screen | **NEW.** Charts for maintenance costs, service frequency, upcoming schedule. |
| **Expense Stats** | chart-bar | Expense Stats screen | **NEW.** Charts for spending by category, monthly trends, lifetime summary. |

#### Sharing & Fleet (bottom section — conditional)
| Menu Item | Icon | Destination | Notes |
|-----------|------|-------------|-------|
| **Sharing** | share | Vehicle Sharing / Shared with Me | Visible to all users; share creation capped by plan (free 1/3, premium 5/20). |
| **Fleet** | truck | Fleet Mode / Org Management | Visible only to members of an active Enterprise organization; role limits actions. |

```text
Auth (online)
  1. Create Account
  2. Login
        │  success
        ▼
  ┌─────────────────────────────────────────┐
  │  Shell (bottom nav + hamburger)         │
  │                                         │
  │  ☰ [Garage]  Maintenance  Expenses  Setting
  │     ▲                                   │
  │     └── default: screen 3 Dashboard     │
  │                                         │
  │  Hamburger drawer:                      │
  │  ├─ Sync                               │
  │  ├─ Documents                          │
  │  ├─ Parts                              │
  │  ├─ Maintenance Plan                   │
  │  ├─ Insurance                          │
  │  ├─ Fuel Stats (NEW)                  │
  │  ├─ Maintenance Stats (NEW)            │
  │  ├─ Expense Stats (NEW)                │
  │  ├─ Sharing (conditional)              │
  │  └─ Fleet (conditional)                │
  └─────────────────────────────────────────┘
```

---

## Screen map (mobile)

Numbering follows the tldraw frame names.

| # | Frame | How you get there | Notes |
|---|--------|-------------------|--------|
| 1 | Create Account | Unauthenticated | Out of this nav spec |
| 2 | Login | Unauthenticated | Out of this nav spec |
| 3 | Dashboard | Login success; Garage tab; picking a vehicle in My Garage | Empty variant: CTA **Register A Vehicle**, shimmer while local DB hydrates |
| 4 | Garage Home (My Garage) | Header **garage** on 3 | List + add. Switching a card sets active vehicle and **pops back to 3** |
| 5 | Add/Edit Vehicle | `+` on 4 or Register on empty 3 | New: save → set active → Maintenance Plan (registration flow). Edit: save → 3 |
| 6 | Maintenance | Maintenance tab | Upcoming / Scheduled / History. Stack: plan list, add item, suggested catalog, register service |
| 7 | Expenses | Expenses tab | Month/total, by category, recent list |
| 8 | Documents | **Hamburger menu** → Documents | Moved from header on 7. Per-vault document management. |
| 9 | Settings | Setting tab | Profile, account, Sign Out. Fleet context switch is in the conditional hamburger menu. |
| 10 | Maintenance Plan | **Hamburger menu** → Maintenance Plan; after registering a vehicle | Moved from Maintenance tab. Suggested items filtered by fuel type. In the registration flow it shows an extra **Done** button → My Garage (4). |
| 11 | Add Maintenance Item / Register Service | From 6 or from Hamburger → Maintenance Plan | Register service updates mileage and can complete plan items |
| 12 | Vehicle Share Management | **Hamburger menu** → Sharing | Vehicle Shares tab: manage shares on your vehicles (code/QR, email invites, access levels).
| 13 | Shared with Me | **Hamburger menu** → Sharing | View/manage shares you hold on other people's vehicles. |
| 14 | Insurance | **Hamburger menu** → Insurance | Moved from Garage. Vehicle insurance documents/status. |
| 15 | Parts | **Hamburger menu** → Parts (also from Dashboard quick actions) | Per-vehicle parts catalog. |
| 16 | Sync Status | **Hamburger menu** → Sync | Moved from Settings. Sync status indicator + manual sync. |
| 17 | Fuel Stats | **Hamburger menu** → Fuel Stats | Adaptive (charge/refuel KPIs): cost trends, efficiency, cost per distance. Contract: `product/frd/stats.md`. |
| 18 | Maintenance Stats | **Hamburger menu** → Maintenance Stats | **NEW.** Charts: maintenance cost trends, service frequency, upcoming schedule. |
| 19 | Expense Stats | **Hamburger menu** → Expense Stats | **NEW.** Charts: spending by category, monthly trends, lifetime summary. |
| 20 | Fleet Mode / Org Management | **Hamburger menu** → Fleet | Only for org members. Toggle fleet mode, manage org. |

Header on Dashboard (3):

- Leading: **hamburger icon** → opens drawer menu.
- Title: time-of-day greeting (morning / afternoon / evening) over the user's display name (fallback: email; omitted when neither is set).
- Trailing: **garage icon** → screen 4, and **Noti** → in-app notification feed.

Empty garage: Dashboard still is the default route. Maintenance, Expenses, and Documents show their "no active vehicle" empty states until a vehicle exists.

---

## Nested stacks (not tabs)

Keep one `StatefulShellRoute` (or equivalent) for the four tabs. Push these on the active tab's stack:

- My Garage, Vehicle detail (`/vehicle/:id` — hero + Overview/Maintenance/Details tabs), Add/Edit Vehicle, Service History, Insurance, Refuel/Charge, Fuel Types
- Add/Edit expense, Expense detail
- Document list, viewer, upload
- Maintenance Plan, Suggested items, Add item, Register Service, Service detail
- Notification feed, Profile, Email & password, Notification prefs, Reminders (soon thresholds)
- Vehicle Share Management, Shared with Me (share codes, email invites, access levels)
- Fuel Stats, Maintenance Stats, Expense Stats (chart screens, `stats.md`)
- Sync Status
- Fleet Mode, Org Management, Vehicle Inventory, Work Orders, Inspections, Assignments, Reports

Back from a nested screen returns to the tab or hamburger that opened it. Switching tabs does not destroy stacks in MVP (standard Flutter shell).

---

## Fleet mode and Driver mode

The drawer's **Fleet** entry (visible only to members of an `active` Enterprise organization; role limits actions) opens the **Fleet hub** (`/fleet`): organization card, mode switch, and manage entries (Org Management, Assignments, Warranty Templates — gated by role). The selected mode is stored per user in `AppMeta` and re-validated against live entitlements on every read; losing access degrades back to personal mode. Personal data keeps the offline-first Drift + outbox path; fleet and driver data is **online-first** — lists read the API (HTTP 403 → access-denied empty state), and only the mode string is cached locally.

**Oct 2026 alignment (specified, pending implementation):** `org_driver` accounts get **no mode choice** — login lands directly in Driver mode (no personal/fleet toggle, no personal-garage tabs). Login accepts **email or username** (customer signup stays email-only); driver accounts are username-only with a forced password change on first login (`password_change_required` blocks fleet/driver routes until changed). The drawer Fleet entry stays visible to all org members — the *Fleet Portal* sidebar (not the mobile drawer) is the surface restricted by role (admin full / manager+mechanic reduced / driver no portal login).

Mode changes swap the *contents* of the existing tab branches — the shell does not change shape in personal or fleet mode:

| Tab slot | Personal | Fleet | Driver |
|----------|----------|-------|--------|
| 1 | Garage (Dashboard) | Vehicle Inventory | My Vehicle |
| 2 | Maintenance | Work Orders | My Reports |
| 3 | Expenses | Reports (analytics + CSV export) | *hidden* |
| 4 | Setting | Setting | Setting |

Driver mode shows a **three-item** bottom nav (My Vehicle / My Reports / Setting). Entering driver mode while the Expenses tab is active jumps to the first tab.

Fleet and driver detail screens push on the **root** navigator (not a tab stack):

- Fleet: Fleet hub, Org Management (Members / Vehicles / Workshops / Settings), Add/Edit vehicle, Vehicle detail (status transition, Transfer to buyer), Work order detail (start/resolve), Driver assignments, Warranty templates → New.
- Driver: Start/end shift, Report issue, Log fuel, Start inspection (checklist built from the org's inspection template).

---

## Route guards

From `product/frd/auth.md`:

- Unauthenticated: only welcome / login / signup / password-reset.
- Authenticated: those screens are unreachable without logout.
- Admin portal URLs are not part of the Flutter app.

---

## Compared with Autozis

Autozis web demo uses a **left sidebar** (Manage: Garage, Assistant, Maintenance Plan, Insurance, Notes, Documents; Stats: Insights, Refuel, Maintenance, Expenses, Trips; Catalogs; Account) plus a **bottom module dock** (Dashboard, Refuel, Maintenance, Expenses, Trips, Reminders).

DCO mobile uses **four bottom tabs + hamburger menu**. The hamburger menu provides access to secondary features (Documents, Parts, Maintenance Plan, Insurance, Stats, Sharing, Fleet) while the bottom tabs remain the primary navigation. This is a hybrid approach — bottom tabs for daily use, hamburger for less frequent actions.

---

## Web admin IA

Staff only. Online. Wireframes: tldraw **A1–A6** (cluster "WEB ADMIN (MVP)").

| Frame | Route | Default? |
|-------|-------|----------|
| A1 Admin Login | `/login` | Unauthenticated default |
| A2 Admin Dashboard | `/` | **Authenticated default** |
| A3 Users | `/users` | |
| A4 User profile | `/users/:id` | |
| A5 Partners | `/partners` | |
| A6 Partner create/edit | `/partners/new`, `/partners/:id` | |
| A7 Owner Shares Dashboard | `/vehicles/shared` | Vehicle owner read-write |

Sidebar (Autozis-like chrome, DCO items only):

- Overview — Dashboard
- Directory — Users, Partners, Organizations
- Owner Shares Dashboard — read-write shares page for vehicle owners (manage shares, codes, invites)
- Account — Sign out

No owner modules (Garage, Refuel, Trips, Insurance, Documents vault).

Flow: Login → Dashboard → Users (search → profile → deactivate / reactivate / reset / plan) or Partners (create/edit status) or Shared Vehicles (vehicle owner shares view).
