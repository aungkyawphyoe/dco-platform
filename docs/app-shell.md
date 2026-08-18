# App shell and navigation IA

**Status:** Spec. Source screens: `wireframes/dco-mobile-wireframes.tldraw`. Auth screens are in that file; this document does not redesign them.

Default after a successful owner login: **Dashboard** (frame `3. Dashboard (Default Vehicle Detail)`).

---

## Owner app — bottom navigation

Four tabs. Labels match the wireframe chrome (Garage / Maintenance / Expenses / Setting). The first tab **is** Dashboard; it is named Garage in the tab bar because the working context is the garage's active vehicle.

| Tab (UI) | GoRouter path | Tldraw frame | Role |
|----------|---------------|--------------|------|
| **Garage** | `/dashboard` | **3** Dashboard (and **3** empty) | Home. Active vehicle summary. Default after login. |
| **Maintenance** | `/maintenance` | **6** Maintenance (and **6** empty) | Plan + history for the active vehicle. |
| **Expenses** | `/expenses` | **7** Expenses | Spend for the active vehicle. Documents is reached from here (header) and from garage detail, not as a fifth tab. |
| **Setting** | `/settings` | **9** Settings | Account, vehicles, sync. |

Active tab icon uses design-token gold (`icon.active`). Inactive uses slate (`icon.inactive`). Sync status is a compact indicator in the top bar or settings — never a fifth tab.

```text
Auth (online)
  1. Create Account
  2. Login
        │  success
        ▼
  ┌─────────────────────────────────────────┐
  │  Shell (bottom nav)                     │
  │                                         │
  │  [Garage]  Maintenance  Expenses  Setting
  │     ▲                                   │
  │     └── default: screen 3 Dashboard     │
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
| 8 | Documents | Header **Documents** on 7; also from vehicle flows that open the vault | Not a bottom-nav root |
| 9 | Settings | Setting tab | Profile, notifications, manage vehicles → 4, backup & sync (status, not v1.1 backup product), export **disabled / hidden** in MVP if not built |
| 10 | Maintenance Plan / Predefined items | From 6 | Suggested items filtered by fuel type |
| 11 | Add Maintenance Item / Register Service | From 6 | Register service updates mileage and can complete plan items |

Header on Dashboard (3):

- Leading: **vehicle chip** (nickname, e.g. "Daily Driver") → screen 4.
- Trailing: **garage** affordance (same destination as chip) and **Noti** → in-app notification feed (not a tab).

Empty garage: Dashboard still is the default route. Maintenance, Expenses, and Documents show their "no active vehicle" empty states until a vehicle exists.

---

## Nested stacks (not tabs)

Keep one `StatefulShellRoute` (or equivalent) for the four tabs. Push these on the active tab's stack:

- My Garage, Add/Edit Vehicle
- Maintenance Plan, Suggested items, Add item, Register Service, Service detail
- Add/Edit expense, Expense detail
- Document list (if opened from Expenses), viewer, upload
- Notification feed, Profile, Email & password, Notification prefs, Sync status

Back from a nested screen returns to the tab that opened it. Switching tabs does not destroy stacks in MVP (standard Flutter shell).

---

## Route guards

From `product/frd/auth.md`:

- Unauthenticated: only welcome / login / signup / password-reset.
- Authenticated: those screens are unreachable without logout.
- Admin portal URLs are not part of the Flutter app.

---

## Compared with Autozis

Autozis web demo uses a **left sidebar** (Manage: Garage, Assistant, Maintenance Plan, Insurance, Notes, Documents; Stats: Insights, Refuel, Maintenance, Expenses, Trips; Catalogs; Account) plus a **bottom module dock** (Dashboard, Refuel, Maintenance, Expenses, Trips, Reminders).

DCO mobile **does not copy that IA**. Owners get four tabs. Fuel, trips, insurance, assistant, and catalogs are absent. "Garage" in the tab bar is the Autozis *dashboard* idea (active vehicle home), not Autozis's garage list — the list is screen 4, one tap off the chip.

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

Sidebar (Autozis-like chrome, DCO items only):

- Overview — Dashboard
- Directory — Users, Partners
- Account — Sign out

No owner modules (Garage, Refuel, Trips, Insurance, Documents vault).

Flow: Login → Dashboard → Users (search → profile → deactivate / reactivate / reset / plan) or Partners (create/edit status).
