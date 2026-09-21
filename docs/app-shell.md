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
| **Setting** | `/settings` | **9** Settings | Account, fleet toggle. Minimal — most features moved to hamburger. |

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
| **Documents** | folder | Document List | Moved from Settings. Per-vault document management. |
| **Parts** | wrench | Parts List | Entry point also kept on Dashboard quick actions. |
| **Maintenance Plan** | clipboard-list | Maintenance Plan | Moved from Maintenance tab. Upcoming/Scheduled/History. |
| **Insurance** | shield | Insurance section | Moved from Garage. Vehicle insurance documents/status. |
| **Refuel Stats** | chart-bar | Refuel Stats screen | **NEW.** Charts for refuel/charge history, cost trends, fuel efficiency. |
| **Maintenance Stats** | chart-bar | Maintenance Stats screen | **NEW.** Charts for maintenance costs, service frequency, upcoming schedule. |
| **Expense Stats** | chart-bar | Expense Stats screen | **NEW.** Charts for spending by category, monthly trends, lifetime summary. |

#### Family & Fleet (bottom section — conditional)
| Menu Item | Icon | Destination | Notes |
|-----------|------|-------------|-------|
| **Family** | people | Family Setup / Management | Moved from Settings. Only visible if user has family or is Premium. |
| **Fleet** | truck | Fleet Mode / Org Management | Only visible if user is org member. Toggles fleet mode. |

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
  │  ├─ Refuel Stats (NEW)                 │
  │  ├─ Maintenance Stats (NEW)            │
  │  ├─ Expense Stats (NEW)                │
  │  ├─ Family (conditional)               │
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
| 4 | Garage Home (My Garage) | Header **garage** / vehicle chip on 3 | List + add. Switching a card sets active vehicle and **pops back to 3** |
| 5 | Add/Edit Vehicle | `+` on 4 or Register on empty 3 | After first save: set active, go to 3 |
| 6 | Maintenance | Maintenance tab | Upcoming / Scheduled / History. Stack: plan list, add item, suggested catalog, register service |
| 7 | Expenses | Expenses tab | Month/total, by category, recent list |
| 8 | Documents | **Hamburger menu** → Documents | Moved from header on 7. Per-vault document management. |
| 9 | Settings | Setting tab | Profile, Fleet toggle, Sign Out. Most features moved to hamburger. |
| 10 | Maintenance Plan | **Hamburger menu** → Maintenance Plan | Moved from Maintenance tab. Suggested items filtered by fuel type. |
| 11 | Add Maintenance Item / Register Service | From 6 or from Hamburger → Maintenance Plan | Register service updates mileage and can complete plan items |
| 12 | Family Setup | **Hamburger menu** → Family | Moved from Settings. Create or join a family group. |
| 13 | Family Management | **Hamburger menu** → Family | Moved from Settings. Members, vehicles, share code, QR, driving licenses. |
| 14 | Insurance | **Hamburger menu** → Insurance | Moved from Garage. Vehicle insurance documents/status. |
| 15 | Parts | **Hamburger menu** → Parts (also from Dashboard quick actions) | Per-vehicle parts catalog. |
| 16 | Sync Status | **Hamburger menu** → Sync | Moved from Settings. Sync status indicator + manual sync. |
| 17 | Refuel Stats | **Hamburger menu** → Refuel Stats | **NEW.** Charts: refuel cost trends, fuel efficiency, cost per km. |
| 18 | Maintenance Stats | **Hamburger menu** → Maintenance Stats | **NEW.** Charts: maintenance cost trends, service frequency, upcoming schedule. |
| 19 | Expense Stats | **Hamburger menu** → Expense Stats | **NEW.** Charts: spending by category, monthly trends, lifetime summary. |
| 20 | Fleet Mode / Org Management | **Hamburger menu** → Fleet | Only for org members. Toggle fleet mode, manage org. |

Header on Dashboard (3):

- Leading: **hamburger icon** → opens drawer menu.
- Trailing: **vehicle chip** (nickname, e.g. "Daily Driver") → screen 4, and **Noti** → in-app notification feed.

Empty garage: Dashboard still is the default route. Maintenance, Expenses, and Documents show their "no active vehicle" empty states until a vehicle exists.

---

## Nested stacks (not tabs)

Keep one `StatefulShellRoute` (or equivalent) for the four tabs. Push these on the active tab's stack:

- My Garage, Add/Edit Vehicle, Service History, Insurance, Refuel/Charge, Fuel Types
- Add/Edit expense, Expense detail
- Document list, viewer, upload
- Maintenance Plan, Suggested items, Add item, Register Service, Service detail
- Notification feed, Profile, Email & password, Notification prefs
- Family setup, Family management (members, vehicles, share code, QR, driving licenses)
- Refuel Stats, Maintenance Stats, Expense Stats (new chart screens)
- Sync Status
- Fleet Mode, Org Management, Vehicle Inventory, Work Orders, Inspections, Assignments, Reports

Back from a nested screen returns to the tab or hamburger that opened it. Switching tabs does not destroy stacks in MVP (standard Flutter shell).

---

## Route guards

From `product/frd/auth.md`:

- Unauthenticated: only welcome / login / signup / password-reset.
- Authenticated: those screens are unreachable without logout.
- Admin portal URLs are not part of the Flutter app.

---

## Compared with Autozis

Autozis web demo uses a **left sidebar** (Manage: Garage, Assistant, Maintenance Plan, Insurance, Notes, Documents; Stats: Insights, Refuel, Maintenance, Expenses, Trips; Catalogs; Account) plus a **bottom module dock** (Dashboard, Refuel, Maintenance, Expenses, Trips, Reminders).

DCO mobile uses **four bottom tabs + hamburger menu**. The hamburger menu provides access to secondary features (Documents, Parts, Maintenance Plan, Insurance, Stats, Family, Fleet) while the bottom tabs remain the primary navigation. This is a hybrid approach — bottom tabs for daily use, hamburger for less frequent actions.

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
| A7 Family Dashboard | `/family` | Primary Owner read-only |

Sidebar (Autozis-like chrome, DCO items only):

- Overview — Dashboard
- Directory — Users, Partners
- Family — Primary Owner read-only dashboard (members, vehicles, share code)
- Account — Sign out

No owner modules (Garage, Refuel, Trips, Insurance, Documents vault).

Flow: Login → Dashboard → Users (search → profile → deactivate / reactivate / reset / plan) or Partners (create/edit status) or Family (read-only view for Primary Owners).
