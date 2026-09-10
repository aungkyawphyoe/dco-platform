# Web Admin — Family Sharing Changes (v1.1)

**Status:** Planned — extends `docs/app-shell.md` and `docs/adr/web-stack.md`  
**Contract:** `product/frd/family-sharing.md`, `architecture/iam-family.md`  
**Theme:** Garage Minimal Dark (shared tokens)

---

## Overview

Two major changes to the Web Admin portal:

1. **Unified Login**: Allow `role=owner` users (Primary Owners) to sign in via `/login` — currently admin-only
2. **Family Dashboard (Read-Only)**: New route `/family` for Primary Owners to view family overview

Admin routes (`/`, `/users/*`, `/partners/*`) remain unchanged and `admin`-only.

---

## Auth Flow Changes

### Current (MVP)
```
Web App → /login → BFF /api/auth/login → Validates admin role → Sets httpOnly cookie (dco-admin JWT) → / (admin dashboard)
```

### v1.1 Extended
```
Web App → /login → BFF /api/auth/login → Validates credentials → 
  IF role=admin → Sets cookie (dco-admin JWT) → Redirects to / (admin dashboard)
  IF role=owner + has family → Sets cookie (dco-owner JWT) → Redirects to /family (family dashboard)
  IF role=owner + no family → 403 "Family access required"
  ELSE → 401
```

### BFF Endpoint: `POST /api/auth/login` (Extended)

**Request:**
```json
{ "email": "user@example.com", "password": "secret" }
```

**Response (Admin):**
```json
{ "redirect": "/", "role": "admin" }
```

**Response (Primary Owner):**
```json
{ "redirect": "/family", "role": "owner", "family_id": "uuid" }
```

**Response (Owner, no family):**
```json
{ "error": "no_family_access", "message": "This account is not part of a family." }
```

### Middleware Updates

**`middleware.ts` (Extended)**
```typescript
// Current: checks admin cookie for / (admin) routes
// v1.1: Adds family route protection

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const cookie = request.cookies.get('dco_session');
  
  // Public routes
  if (pathname === '/login' || pathname.startsWith('/api/')) {
    return NextResponse.next();
  }
  
  // Admin routes
  if (pathname.startsWith('/users') || pathname.startsWith('/partners') || pathname === '/') {
    const adminToken = await validateAdminCookie(cookie);
    if (!adminToken) return redirectToLogin();
    request.headers.set('x-admin-user', JSON.stringify(adminToken));
    return NextResponse.next();
  }
  
  // Family routes (Primary Owner read-only)
  if (pathname.startsWith('/family')) {
    const ownerToken = await validateOwnerCookie(cookie);
    if (!ownerToken) return redirectToLogin();
    if (ownerToken.family_role !== 'primary_owner') {
      return NextResponse.redirect(new URL('/login?error=no_family_access', request.url));
    }
    request.headers.set('x-family-user', JSON.stringify(ownerToken));
    return NextResponse.next();
  }
  
  return NextResponse.next();
}
```

---

## New Route: `/family` (Family Dashboard)

### Layout
```
┌─────────────────────────────────────────────────────────────┐
│  ☰  DCO Admin          Smith Family          [Copy Code]   │  ← Top Bar (background.secondary)
│       A7K9M2QX                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  3 Members   │ │  2 Vehicles  │ │  1 Driver    │        │  ← KPI Cards (background.card)
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ VEHICLES                                    [QR]    │   │  ← Section Header + Mobile deep link
│  ├──────────┬──────────┬──────────┬──────────┬────────┤   │
│  │ Nickname │ Plate    │ Make/Model│ Owner   │ Drivers│   │
│  ├──────────┼──────────┼──────────┼──────────┼────────┤   │
│  │ Daily    │ ABC-1234 │ 2023 Tesl │ Alex P  │ 2      │   │  ← Row (text.primary)
│  │ Driver   │          │ Model 3   │ (You)   │        │   │
│  ├──────────┼──────────┼──────────┼──────────┼────────┤   │
│  │ Weekend  │ XYZ-789  │ 2020 Hond │ Sarah C │ 1      │   │
│  │ Car      │          │ Civic     │         │        │   │
│  └──────────┴──────────┴──────────┴──────────┴────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ MEMBERS                                     [QR]    │   │
│  ├──────────┬──────────┬────────┬──────────┬──────────┤   │
│  │ Name     │ Email    │ Role   │ Vehicles │ License  │   │
│  ├──────────┼──────────┼────────┼──────────┼──────────┤   │
│  │ Alex P   │ alex@... │ 👑 PO  │ 2        │ Valid    │   │  ← Role badge
│  │ Sarah C  │ sarah@.. │ 👤 Member│ 1       │ ⚠ 14 days│   │  ← Warning badge
│  │ Mike D   │ mike@... │ 🚗 Driver│ 0       │ ✓ Valid  │   │
│  └──────────┴──────────┴────────┴──────────┴──────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### KPI Cards
| Card | Value | Source |
|------|-------|--------|
| Members | Count of `family_memberships` | API |
| Vehicles | Count of vehicles owned by family members | API |
| Drivers | Count of members with `role=driver` + grants | API |

### Data Tables

#### Vehicles Table
| Column | Source | Notes |
|--------|--------|-------|
| Nickname | `vehicles.nickname` || name | |
| Plate | `vehicles.license_plate` | |
| Make/Model | `vehicles.year` + `make` + `model` | |
| Owner | `users.display_name` (from `vehicles.user_id`) | "(You)" for current user |
| Drivers | Count of `vehicle_grants` where `permission='drive_only'` | Badge |

#### Members Table
| Column | Source | Notes |
|--------|--------|-------|
| Name | `users.display_name` || email | |
| Email | `users.email` | |
| Role | `family_memberships.role` | Badge: PO=gold, Member=blue, Driver=green |
| Vehicles | Count of `vehicles` where `user_id = member.id` | |
| License | `driving_licenses.expiry_date` → status | Badge: Valid/⚠/✗ |

### Actions (Read-Only — No Mutations)
- **Copy Share Code** → Clipboard
- **QR Button** → Modal with QR code for mobile deep link
- **Row Click** → No navigation (read-only)
- **Mobile Deep Link QR**: Opens `dco://family/join?code=XXXXXXXX` on phone

---

## QR Code Modal
```
┌─────────────────────────────────────┐
│  Invite to Smith Family        ✕    │
├─────────────────────────────────────┤
│                                     │
│        [QR Code 280×280]            │
│                                     │
│  Share Code: A7K9M2QX               │
│  [Copy Code]                        │
│                                     │
│  Expires: 7 days                    │
│  Scan with DCO mobile app to join.  │
│                                     │
│  [Close]                            │
└─────────────────────────────────────┘
```

---

## API Integration

### Family Dashboard Data (Single Aggregated Call)
```
GET /v1/families/me?include=members,vehicles,grants,licenses
```

**Response:**
```json
{
  "family": { "id": "...", "name": "Smith Family", "share_code": "A7K9M2QX", ... },
  "my_role": "primary_owner",
  "members": [
    {
      "id": "...", "user_id": "...", "email": "...", "display_name": "Alex P",
      "role": "primary_owner", "joined_at": "...", "vehicle_count": 2,
      "license_status": "valid"
    },
    { "role": "member", "vehicle_count": 1, "license_status": "expiring_soon" },
    { "role": "driver", "vehicle_count": 0, "license_status": "valid" }
  ],
  "vehicles": [
    {
      "id": "...", "nickname": "Daily Driver", "license_plate": "ABC-1234",
      "make": "Tesla", "model": "Model 3", "year": 2023,
      "owner": { "id": "...", "display_name": "Alex P" },
      "driver_count": 2
    }
  ]
}
```

### TanStack Query Hooks
```typescript
// hooks/useFamilyDashboard.ts
export function useFamilyDashboard() {
  return useQuery({
    queryKey: ['family', 'dashboard'],
    queryFn: () => api.get('/families/me?include=members,vehicles,grants,licenses'),
    staleTime: 30_000,
  });
}

export function useFamilyQRCode() {
  return useQuery({
    queryKey: ['family', 'qr'],
    queryFn: () => api.get('/families/me/qr'), // Returns { qr_data_uri, expires_at }
    staleTime: 60_000,
  });
}
```

---

## Components (New / Extended)

### New Components
| Component | Location | Purpose |
|-----------|----------|---------|
| `FamilyDashboard` | `app/family/page.tsx` | Main dashboard layout |
| `FamilyKPICards` | `components/family/FamilyKPICards.tsx` | 3 metric cards |
| `FamilyVehiclesTable` | `components/family/FamilyVehiclesTable.tsx` | Vehicles data table |
| `FamilyMembersTable` | `components/family/FamilyMembersTable.tsx` | Members data table |
| `QRCodeModal` | `components/ui/QRCodeModal.tsx` | Reusable QR display |
| `RoleBadge` | `components/ui/RoleBadge.tsx` | Shared with mobile design system |
| `LicenseStatusBadge` | `components/ui/LicenseStatusBadge.tsx` | Shared with mobile |

### Extended Components
| Component | Change |
|-----------|--------|
| `LoginForm` | Accepts owner credentials; shows family redirect |
| `Sidebar` | Not shown on `/family` routes (different layout) |
| `TopBar` | Shows family name + share code on `/family` |

---

## Route Structure (Updated)

```
app/
├── login/
│   └── page.tsx              # Unified login (admin + owner)
├── (admin)/
│   ├── layout.tsx            # Admin sidebar + middleware
│   ├── page.tsx              # Admin dashboard
│   ├── users/
│   └── partners/
└── (family)/
    ├── layout.tsx            # Family top bar + middleware (requires primary_owner)
    ├── page.tsx              # Family dashboard (/family)
    └── loading.tsx           # Skeleton
```

---

## BFF Cookie Handling

### Login Sets Two Possible Cookies
```typescript
// lib/auth/cookies.ts
export async function setAuthCookie(response: NextResponse, session: SessionResponse) {
  const isAdmin = session.user.role === 'admin';
  const cookieName = isAdmin ? 'dco_admin_session' : 'dco_owner_session';
  const audience = isAdmin ? 'dco-admin' : 'dco-owner';
  
  // Verify audience matches
  const claims = await verifyAccess(session.access_token);
  if (claims.aud !== audience) throw new Error('Audience mismatch');
  
  response.cookies.set(cookieName, session.access_token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 15, // 15 min access token
    path: '/',
  });
  
  // Refresh token stored separately (httpOnly, longer TTL)
  response.cookies.set(`${cookieName}_refresh`, session.refresh_token, {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 30, // 30 days
    path: '/api/auth/refresh',
  });
}
```

### Token Refresh (BFF)
```typescript
// app/api/auth/refresh/route.ts
export async function POST(request: NextRequest) {
  const isAdminRoute = request.nextUrl.pathname.startsWith('/api/admin');
  const cookieName = isAdminRoute ? 'dco_admin_session_refresh' : 'dco_owner_session_refresh';
  const refreshToken = request.cookies.get(cookieName)?.value;
  
  if (!refreshToken) return unauthorized();
  
  const newSession = await api.post('/auth/refresh', { refresh_token: refreshToken });
  const response = NextResponse.json({ ok: true });
  setAuthCookie(response, newSession);
  return response;
}
```

---

## TypeScript Types (Shared with Mobile)

```typescript
// types/family.ts (generated from OpenAPI)
export type FamilyRole = 'primary_owner' | 'member' | 'driver';
export type GrantPermission = 'full' | 'drive_only';
export type LicenseStatus = 'valid' | 'expiring_soon' | 'expired' | 'none';

export interface Family {
  id: string;
  name: string;
  share_code: string;
  qr_code_data: { code: string; family_id: string; expires_at: string } | null;
  status: 'active' | 'archived';
  created_by: string;
  created_at: string;
  archived_at: string | null;
  my_role?: FamilyRole;
}

export interface FamilyMember {
  id: string;
  user_id: string;
  email: string;
  display_name: string | null;
  role: FamilyRole;
  joined_at: string;
  invited_by: string | null;
  vehicle_count: number;
  license_status: LicenseStatus | null;
}

export interface VehicleGrant {
  id: string;
  vehicle_id: string;
  user_id: string;
  granted_by: string;
  permission: GrantPermission;
  created_at: string;
}

export interface DrivingLicense {
  id: string;
  user_id: string;
  license_number: string | null;
  issuing_country: string | null;
  expiry_date: string;
  categories: string | null;
  front_media_id: string | null;
  back_media_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface VehicleDetail {
  // ... Vehicle fields
  grants: VehicleGrant[];
  documents: Document[];
  assigned_drivers: {
    user_id: string;
    display_name: string;
    permission: GrantPermission;
    license_status: LicenseStatus;
  }[];
}

export interface UserDetail {
  // ... User fields
  family_id: string | null;
  family_role: FamilyRole | null;
  driving_license: DrivingLicense | null;
  owned_vehicles: Vehicle[];
}
```

---

## UI States

### Loading
- KPI Cards: Skeleton (background.skeleton)
- Tables: Row skeletons (3-5 rows)
- QR Modal: Spinner

### Empty
- Vehicles: "No vehicles in family yet."
- Members: "No family members."

### Error
- Banner at top: "Failed to load family data. [Retry]"
- Inline on tables: "Unable to load."

---

## Accessibility

- Tables: Proper `<th scope="col">`, sortable headers (future)
- Role badges: `aria-label="Role: Primary Owner"`
- License status: `aria-label="License expires in 14 days"`
- QR Modal: `role="dialog"`, `aria-modal="true"`, focus trap
- Color + text for all status indicators

---

## Testing Checklist

- [ ] Admin login → redirects to `/` (admin dashboard)
- [ ] Primary Owner login → redirects to `/family`
- [ ] Owner without family login → shows error "Family access required"
- [ ] Admin cannot access `/family` → 403
- [ ] Primary Owner cannot access `/users` → 403
- [ ] Family dashboard loads KPIs, tables
- [ ] Copy share code works
- [ ] QR modal opens, shows correct code
- [ ] Token refresh works for both audiences
- [ ] Logout clears correct cookie
- [ ] Mobile deep link QR opens DCO app join screen
- [ ] Responsive: tables stack on mobile viewport
- [ ] Dark theme only (no light mode)

---

## Deployment Notes

- No database migrations for web (uses existing API)
- New BFF routes: `/api/auth/login` (extended), `/api/auth/refresh` (dual audience)
- Middleware updated for dual-route protection
- Environment variable: `NEXT_PUBLIC_APP_SCHEME=dco` for deep links
- Feature flag: `NEXT_PUBLIC_FAMILY_FEATURE=true` (can toggle off)
