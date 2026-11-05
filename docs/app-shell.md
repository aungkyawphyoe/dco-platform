# App shell and navigation IA

**Status:** Spec. Source screens: `wireframes/dco-mobile-wireframes.tldraw`. Auth screens are in that file; this document does not redesign them.

Default after a successful owner login: **Dashboard** (frame `3. Dashboard (Default Vehicle Detail)`).

---

## Owner app — bottom navigation + hamburger menu

Four bottom tabs (consistent for normal users, fleet owners, **and drivers** — drivers select assigned vehicles, with read-only vehicle master data and full Expenses) plus a hamburger menu (drawer) for additional features.

### Bottom tabs

| Tab (UI) | GoRouter path | Tldraw frame | Role |
|----------|---------------|--------------|------|
| **Garage** | `/dashboard` | **3** Dashboard (and **3** empty) | Home. Active vehicle summary. Default after login. |
| **Maintenance** | `/maintenance` | **6** Maintenance (and **6** empty) | Plan + history for the active vehicle. |
| **Expenses** | `/expenses` | **7** Expenses | Spend for the active vehicle. |
| **More** | `/settings` | **9** More | Customer info, subscription card, Management, Preferences, Support & Information. |

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
| **Maintenance Plan** | clipboard-list | Maintenance Plan | Moved from Maintenance tab. Upcoming/Scheduled/History. |
| **Insurance** | shield | Insurance section | Moved from Garage. Vehicle insurance documents/status. *Not Implemented* Hide for now. |
| **Fuel Stats** | chart-bar | Fuel Stats screen | Adaptive: charge KPIs for electric, refuel KPIs otherwise. Charts for cost trends, efficiency, cost per distance. |
| **Maintenance Stats** | chart-bar | Maintenance Stats screen | **NEW.** Charts for maintenance costs, service frequency, upcoming schedule. |
| **Expense Stats** | chart-bar | Expense Stats screen | **NEW.** Charts for spending by category, monthly trends, lifetime summary. |

#### Sharing & Fleet (bottom section — conditional)
| Menu Item | Icon | Destination | Notes |
|-----------|------|-------------|-------|
| **Sharing** | share | Vehicle Sharing / Shared with Me | Visible to all users; share creation capped by plan (free 1, lite 3, standard/fleet unlimited). |
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
  │  ☰ [Garage]  Maintenance  Expenses  More
  │     ▲                                   │
  │     └── default: screen 3 Dashboard     │
  │                                         │
  │  Hamburger drawer:                      │
  │  ├─ Sync                               │
  │  ├─ Documents                          │
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
| 4 | Garage Home (My Garage) | Header **garage** on 3 | Owned/Shared tabs appear only when shared vehicles exist; Shared reuses Shared with Me. Otherwise list + add. Switching a card sets active vehicle and **pops back to 3** |
| 5 | Add/Edit Vehicle | `+` on 4 or Register on empty 3 | New: save → set active → Maintenance Plan (registration flow). Edit: save → 3 |
| 6 | Maintenance | Maintenance tab | Upcoming / Scheduled / History. Stack: plan list, add item, suggested catalog, register service |
| 7 | Expenses | Expenses tab | Month/total, by category, recent list |
| 8 | Documents | **Hamburger menu** → Documents | Moved from header on 7. Per-vault document management. |
| 9 | More | More tab | Profile, subscription card, grouped management/preferences/support rows, Sign Out (asks for confirmation). |
| 10 | Maintenance Plan | **Hamburger menu** → Maintenance Plan; after registering a vehicle | Moved from Maintenance tab. Suggested items filtered by fuel type. In the registration flow it shows an extra **Done** button → My Garage (4). |
| 11 | Add Maintenance Item / Register Service | From 6 or from Hamburger → Maintenance Plan | Register service updates mileage and can complete plan items |
| 12 | Vehicle Share Management | **Hamburger menu** → Sharing | Vehicle Shares tab: manage shares on your vehicles (code/QR, email invites, access levels).
| 13 | Shared with Me | **Hamburger menu** → Shared with Me; My Garage → Shared tab | View shares and join a vehicle share. No separate Join Vehicle Share drawer entry. |
| 14 | Insurance | **Hamburger menu** → Insurance | Moved from Garage. Vehicle insurance documents/status. |
| 15 | Parts | **More** → Parts (also from Dashboard quick actions) | Per-vehicle parts catalog. |
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
- Notification feed, Profile, Email & password, Notification prefs, Reminders (soon thresholds + email reminders)
- Vehicle Share Management, Shared with Me (share codes, email invites, access levels)
- Fuel Stats, Maintenance Stats, Expense Stats (chart screens, `stats.md`)
- Sync Status
- Fleet Mode, Org Management, Vehicle Inventory, Work Orders, Inspections, Assignments, Reports

Back from a nested screen returns to the tab or hamburger that opened it. Switching tabs does not destroy stacks in MVP (standard Flutter shell).

---

## Fleet mode and Driver mode

Mobile has **no Fleet hub, no mode switch, and no drawer Fleet entry** (removed October 2026 — fleet management lives on the Fleet Portal). The app has two effective modes, derived from live entitlements (`GET /me/entitlements`) with no stored preference:

- **Driver mode** — separate admin-created accounts, forced organization scope, no toggle. The same four tabs and core screen implementations use organization-scoped local data and sync.
  - Garage lists all assigned vehicles and provides the shared active-vehicle selector. Vehicle master data and assignment management belong to Fleet Admin.
  - Maintenance uses the shared completed-service form and full vehicle history. Planned logs link admin-defined items; unplanned logs do not create plans.
  - Expenses uses all existing categories and full assigned-vehicle totals. Documents follow the same assigned-vehicle scope.
  - Shared quick actions remain; Report Issue, Start Inspection and Reports are supplemental fleet actions.
  - Drivers edit their own ordinary records only. Admin corrections lock records. Sync status shows pending, accepted and declined submissions.
  - Notes remain private and local to the account. Sharing/join/create-vehicle/plan-management entry points are hidden.

- **Personal mode** — everyone else, including non-driver org members (`org_admin`/`org_manager`/`org_mechanic`), who keep mobile login for their personal garage only.

Backend enforcement is authoritative: management API routes require the `dco-fleet` (Fleet Portal) audience and reject mobile's `dco-owner` token; personal-garage routes reject driver identities with 403 `personal_garage_forbidden`.

Driver-specific screens push on the active **tab** stacks (parity with personal mode):

- Driver: shared Register service and Refuel forms, Report Issue, Start inspection, Reports, and read-only vehicle detail.

---

## Post-login tour

Distinct from the pre-login introduction in `product/frd/auth.md`. The introduction runs before sign-in and is marked handled per installation; the tour runs after authentication and is stored per account.

- After the dashboard has loaded on the Garage tab (active-vehicle stream resolved, first-vehicle and verification routing prompts dismissed), the shell offers a compact **Show me around?** card with **Show me around** and **Not now**. It never covers the screen before the user opts in.
- Four anchored steps point at real controls: the active vehicle card or empty state, then the Maintenance, Expenses, and More bottom tabs. Copy explains settings and sync together.
- Personal accounts with an empty garage are told to add their first vehicle; no vehicle or sample record is created. Drivers with no assignment are told that a fleet admin manages assignments, and vehicle creation is never offered.
- Next, Back, Skip, and system Back are always available. Back on the first step exits the tour; the overlay never traps the user. Steps do not switch tabs, so existing tab stacks are preserved.
- Dismissal and completion are stored locally in account-scoped AppMeta under a versioned key. The offer appears once per account and tour version and does not repeat on launch, sign-out, or transient loading. A new tour version is offered again.
- More → Help → **Replay tour** starts an explicit replay from the Garage dashboard, regardless of stored progress. Replays do not re-arm the automatic offer.
- Targets that are not currently laid out fall back to a centred card rather than failing. The presentation honours light/dark, English/Burmese, large text (scrollable hint card), and reduced motion (no animated overlay), and exposes the hint as a live-region semantic.

Tour state is device-local. It is not a sync entity and does not affect account isolation.

**Testing aid:** debug builds offer the tour on every launch so the flow can be exercised (`DCO_TOUR_ALWAYS`, on by default in debug; pass `--dart-define=DCO_TOUR_ALWAYS=false` to disable). Release builds always honour stored progress. Dismissing the offer still suppresses it for the rest of that run; restart the app or sign out and back in to see it again.

---

## Route guards

From `product/frd/auth.md`:

- Unauthenticated: only introduction / login / signup / password-reset.
- Authenticated: those screens are unreachable without logout.
- Admin portal URLs are not part of the Flutter app.

---

## Compared with Autozis

Autozis web demo uses a **left sidebar** (Manage: Garage, Assistant, Maintenance Plan, Insurance, Notes, Documents; Stats: Insights, Refuel, Maintenance, Expenses, Trips; Catalogs; Account) plus a **bottom module dock** (Dashboard, Refuel, Maintenance, Expenses, Trips, Reminders).

AutoX mobile uses **four bottom tabs + hamburger menu**. The hamburger menu provides access to secondary features (Documents, Maintenance Plan, Insurance, Stats, Sharing, Fleet) while the bottom tabs remain the primary navigation. This is a hybrid approach — bottom tabs for daily use, hamburger for less frequent actions.

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

Sidebar (Autozis-like chrome, AutoX items only):

- Overview — Dashboard
- Directory — Users, Partners, Organizations
- Owner Shares Dashboard — read-write shares page for vehicle owners (manage shares, codes, invites)
- Account — Sign out

No owner modules (Garage, Refuel, Trips, Insurance, Documents vault).

Flow: Login → Dashboard → Users (search → profile → deactivate / reactivate / reset / plan) or Partners (create/edit status) or Shared Vehicles (vehicle owner shares view).

### Personal plans and gifts

More → **Plans & subscriptions** opens `/pricing`. Vehicle/share limit dialogs and personal storage-full state expose **View plans**. The screen shows the current personal plan, gift end time, and selectable Free/Lite/Standard price comparisons (monthly/annual). **Redeem a gift code** opens the dedicated `/pricing/redeem` screen for online redemption, verification, feedback, and retry. Browsing plans never changes the subscription. Driver mode hides and route-guards this screen. Paid checkout remains unavailable. See `product/frd/mobile-pricing-promotions.md`.

## Offline Help and feedback

More → Help retains Replay tour and adds six offline FAQs: sign-in, vehicle setup, maintenance, expenses/fuel, synchronization, and local-only Notes. Vehicle guidance follows the current Personal/Driver scope. The sync answer links to the existing sync status screen.

Feedback to `support@autoxmm.com` is an ephemeral, editable message. Opening an email draft hands it to the user's mail app for review; AutoX does not send it. Platform information is excluded by default and only included through an explicit checkbox. Copy includes the recipient, subject, and the same message, providing an offline/no-mail-app fallback. Failed launching or copying preserves the typed message. No account records, documents, logs, or tokens are attached or sent to analytics. The draft is discarded when the Help screen is disposed. Broad crash monitoring and ticket infrastructure remain separate work.

## More navigation hub (5 November 2026)

The fourth tab retains `/settings` for route compatibility and uses `more_horiz` with the More label. Customer information and the personal subscription card remain at the top, and Sign Out remains at the bottom. Account Connection moves to the current user's Profile screen only.

- Management: Shared Users (personal owners only), Fuel Types, Parts. Expense Types is deferred. Parts is removed from the drawer; existing contextual entry points remain.
- Preferences: Settings (`/settings/preferences`) contains Appearance, Localization, Unit and Formats, Reminders, retaining existing destinations.
- Support & Information: Help, About (`/settings/about`). About displays the installed version/build, branding, Terms, Privacy, and a tappable website footer.

Shared Users (`/settings/shared-users`) groups active shares by recipient, expands to vehicles and access levels, and links to existing vehicle sharing controls. Pending invitations are separate, with expired status shown. Active vehicle shares consume quota, including repeated recipients and archived vehicles, matching server rules; pending invitations do not. The overview uses an account-scoped Drift snapshot, preserves it on refresh failures, and shows its update time. Only a catalog plan with greater capacity triggers the premium banner; unlimited users see no upsell. Driver mode hides and guards this route.
