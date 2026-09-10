# Mobile Family Screens — UI/UX Specification (v1.1)

**Status:** Planned — extends `docs/app-shell.md` and `docs/design-system.md`  
**Contract:** `product/frd/family-sharing.md`  
**Theme:** Garage Minimal Dark (`docs/theme/garage-minimal-dark.json`)

---

## Design Principles

1. **Consistency**: Reuse existing patterns (cards, lists, forms, chips) from Garage/Maintenance/Settings
2. **Hierarchy**: Primary Owner actions prominent; Member/Driver views read-focused
3. **Accessibility**: Role badges = text + color; license expiry announced; 44×44 hit targets
4. **Offline-first**: All family data cached locally; writes queue to outbox

---

## New Screens Overview

| Screen | Route | Tab Stack | Entry Points |
|--------|-------|-----------|--------------|
| Family Setup | `/family/setup` | Settings | Settings → Family → "Create Family" |
| Family Management | `/family/manage` | Settings | Settings → Family (after family exists) |
| Car Detail | `/vehicle/:id/detail` | Garage | Garage Home → Vehicle card |
| User Detail | `/user/:id/detail` | Settings/Family | Family Management → Member, Car Detail → Driver, Settings → Profile |

---

## Screen: Family Setup (`/family/setup`)

### Wireframe Reference
New frame in tldraw (Settings cluster)

### Layout
```
┌─────────────────────────────────────┐
│  ← Settings          Create Family  │  ← AppBar (background.card)
├─────────────────────────────────────┤
│                                     │
│   [Family Icon]                     │
│   Create Your Family                │  ← Title (text.primary)
│   Invite members to share vehicles  │  ← Subtitle (text.secondary)
│   and manage access together.       │
│                                     │
│   ┌─────────────────────────────┐   │
│   │ Family Name                 │   │  ← Input (background.input, border.default)
│   │ [________________________]  │   │
│   │                             │   │
│   │  [Create Family]            │   │  ← Primary Button (full width)
│   └─────────────────────────────┘   │  ← Card (background.card, radius.md)
│                                     │
└─────────────────────────────────────┘
```

### States
- **Empty**: Name field focused
- **Validating**: Button loading spinner
- **Success**: Navigate to Family Management with share sheet

### Validation
- Name: 1-100 chars, required
- Error inline: "Family name required"

---

## Screen: Family Management (`/family/manage`)

### Wireframe Reference
New frame in tldraw (Settings cluster)

### Layout — Tabbed (Default: Members)
```
┌─────────────────────────────────────┐
│  ← Settings      [Members] Vehicles │  ← Segmented Control (icon.active/secondary)
│            Invite                   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Avatar] Primary Owner      │   │  ← ListTile
│  │ You • 2 vehicles            │   │
│  │ [Primary Owner badge]       │   │  ← Role badge (gold background)
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Avatar] Sarah Chen         │   │
│  │ Member • 1 vehicle          │   │
│  │ [Member badge] [⋮]          │   │  ← Trailing menu (Primary Owner only)
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Avatar] Mike Driver        │   │
│  │ Driver • 0 vehicles         │   │
│  │ [Driver badge] [⋮]          │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Tabs

#### Members Tab (Default)
- List of `FamilyMember` with avatar, name, role badge, vehicle count
- **Primary Owner sees**: Trailing menu (⋮) → "Change Role" / "Remove"
- **Member/Driver sees**: Read-only
- Empty state: "No members yet. Invite family to get started."

#### Vehicles Tab
```
┌─────────────────────────────────────┐
│  [Vehicle Card]                     │
│  📷 Daily Driver    ABC-1234        │
│  2023 Tesla Model 3  •  45,200 mi  │
│  [Driver badge ×2] [Member badge]  │  ← Chips for assigned drivers
│                                     │
│  [Vehicle Card]                     │
│  📷 Weekend Car     XYZ-789         │
│  2020 Honda Civic     •  78,500 mi  │
│  [Driver badge]                     │
└─────────────────────────────────────┘
```
- Reuses `VehicleCard` from Garage Home
- Adds driver chips below vehicle info

#### Invite Tab
```
┌─────────────────────────────────────┐
│  Share Your Family                  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Share Code:  A7K9M2QX      │   │  ← Monospace, copy button
│  │  [Copy]                     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │        [QR Code Image]      │   │  ← 200×200, contains deep link
│  │   Scan to join family       │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Regenerate Code]  [Share Sheet]  │  ← Secondary + Primary buttons
│                                     │
│  ⚠️ Code expires in 7 days.        │  ← Caption (text.caption)
│  Regenerating invalidates old code. │
└─────────────────────────────────────┘
```

### Role Badge Styles
| Role | Background | Text | Icon |
|------|------------|------|------|
| Primary Owner | `button.primary` (gold) | `text.onAccent` (navy) | Crown |
| Member | `status.info` (blue) | `text.primary` (white) | Person |
| Driver | `status.success` (green) | `text.primary` (white) | Steering Wheel |

---

## Screen: Car Detail (`/vehicle/:id/detail`)

### Wireframe Reference
Replaces Vehicle Detail (Garage frame 5 → new detail frame)

### Layout
```
┌─────────────────────────────────────┐
│  ← Garage        Daily Driver  ⋮    │  ← AppBar (vehicle photo backdrop)
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │  VEHICLE IDENTITY           │   │  ← Section Header (text.tertiary)
│  │  📷 Daily Driver            │   │
│  │  ABC-1234  •  2023 Tesla M3 │   │
│  │  45,200 mi  •  Electric     │   │
│  │  VIN: 5YJ3E1EBXPF123456     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  DOCUMENTS (3)          +   │   │  ← Section Header + Action
│  │  [Doc Card] [Doc Card]      │   │  ← Horizontal scroll (DocumentCard)
│  │  [Doc Card]                 │   │     Reuses Documents vault UI
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ASSIGNED DRIVERS (2)    +  │   │  ← Section Header + Action (PO/Member)
│  │  ┌─────────────────────┐    │   │
│  │  │ [Avatar] Sarah      │    │   │  ← Driver Tile
│  │  │ Member • Full       │    │   │
│  │  │ License: Valid      │    │   │  ← License status badge
│  │  └─────────────────────┘    │   │
│  │  ┌─────────────────────┐    │   │
│  │  │ [Avatar] Mike       │    │   │
│  │  │ Driver • Drive Only │    │   │
│  │  │ License: Expiring   │    │   │  ← Warning badge (status.warning)
│  │  └─────────────────────┘    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  QUICK ACTIONS              │   │
│  │  [Log Service] [Log Fuel]   │   │  ← Button row (Primary + Secondary)
│  │  [Add Document] [Drivers]   │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Document Cards (Reuse `documents.md` UI)
- Thumbnail (image/PDF icon)
- Name, category badge, date
- Tap → Document viewer (existing)

### Driver Tile
```
┌─────────────────────────────────────┐
│ [Avatar]  Sarah Chen      [chevron] │
│ Member • Full Access                │
│ License: Valid  ●  Expires Aug 2026 │  ← Status dot (success/warning/danger)
└─────────────────────────────────────┘
```
- Tap → User Detail screen

### Quick Actions (Contextual)
| Role | Actions Shown |
|------|---------------|
| Primary Owner | Log Service, Log Fuel, Add Document, Manage Drivers |
| Member (full grant) | Log Service, Log Fuel, Add Document, Manage Drivers |
| Driver (drive_only) | Log Fuel, View Documents |

---

## Screen: User Detail (`/user/:id/detail`)

### Wireframe Reference
New frame in tldraw (Settings/Family cluster)

### Layout — Self View (Primary Owner viewing own profile)
```
┌─────────────────────────────────────┐
│  ← Settings         Profile    ✎    │  ← AppBar (edit button)
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │      [Large Avatar]         │   │
│  │      Alex Primary           │   │  ← Name (text.primary)
│  │      alex@email.com         │   │  ← Email (text.secondary)
│  │      [Primary Owner badge]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  DRIVING LICENSE            │   │
│  │  ┌─────────┐ ┌─────────┐    │   │  ← Thumbnail pair
│  │  │ Front   │ │ Back    │    │   │
│  │  │ [img]   │ │ [img]   │    │   │
│  │  └─────────┘ └─────────┘    │   │
│  │  Expires: Aug 15, 2026 ●    │   │  ← Status dot + date
│  │  Number: D1234567           │   │
│  │  Categories: B, BE          │   │
│  │  [Update License]           │   │  ← Tertiary button
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ACCESS LEVEL               │   │
│  │  Primary Owner              │   │
│  │  Full control over family,  │   │
│  │  vehicles, and members.     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  MY VEHICLES (2)            │   │
│  │  [Vehicle Card]             │   │  ← Owned vehicles only
│  │  [Vehicle Card]             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  FAMILY ACTIONS             │   │
│  │  [Leave Family]             │   │  ← Destructive button (outline rust)
│  │  (Requires ownership        │   │
│  │   transfer first)           │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Layout — Member View (Primary Owner viewing Member)
```
┌─────────────────────────────────────┐
│  ← Family          Sarah Chen       │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │      [Avatar]               │   │
│  │      Sarah Chen             │   │
│  │      sarah@email.com        │   │
│  │      [Member badge]         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  DRIVING LICENSE            │   │
│  │  [Front] [Back]             │   │
│  │  Expires: Sep 1, 2026  ⚠    │   │  ← Warning (expiring soon)
│  │  Number: M9876543           │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ACCESS LEVEL               │   │
│  │  Member (Secondary Owner)   │   │
│  │  Full vehicle access except │   │
│  │  ownership transfer.        │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  MY VEHICLES (1)            │   │
│  │  [Vehicle Card]             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ACTIONS                    │   │
│  │  [Change Role ▼]            │   │  ← Select: Member / Driver
│  │  [Assign Vehicles]          │   │
│  │  [Remove from Family]       │   │  ← Destructive
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Layout — Driver View
- Same as Member but role = Driver, permission = Drive Only
- Actions: Change Role, Assign Vehicles, Remove

### License Status Badges
| Status | Condition | Color | Icon |
|--------|-----------|-------|------|
| Valid | > 30 days | `status.success` | Check |
| Expiring Soon | 7-30 days | `status.warning` | Clock |
| Expiring Critical | < 7 days | `status.danger` | Alert |
| Expired | Past | `status.danger` | X Circle |
| None | No license | `text.tertiary` | — |

---

## Settings Integration

### Settings Screen (Extended)
Add Family section after Notifications:

```
┌─────────────────────────────────────┐
│  FAMILY                             │  ← Section header
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Family Icon]  My Family    │   │  ← If in family
│  │  Smith Family • 4 members   │   │
│  │  [chevron]                  │   │  → Family Management
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Family Icon]  Join Family  │   │  ← If not in family
│  │  Enter code or scan QR      │   │
│  │  [chevron]                  │   │  → Join Family (code input)
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Family Icon]  Create Family│   │  ← If not in family
│  │  Start a new family group   │   │
│  │  [chevron]                  │   │  → Family Setup
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## Component Reuse

| Component | Source | Reused In |
|-----------|--------|-----------|
| `VehicleCard` | Garage Home | Family Management → Vehicles tab, Car Detail → quick view |
| `DocumentCard` | Documents vault | Car Detail → Documents section |
| `RoleBadge` | New | Family Management, User Detail, Car Detail drivers |
| `LicenseStatusBadge` | New | User Detail, Car Detail drivers |
| `InputField` | Auth/Forms | Family Setup, Join Family |
| `PrimaryButton` | System | All create/confirm actions |
| `SecondaryButton` | System | Cancel, Regenerate Code |
| `DestructiveButton` | New | Remove member, Leave family |

---

## Deep Links

| Link | Route | Params |
|------|-------|--------|
| Family invite QR | `dco://family/join` | `?code=A7K9M2QX` |
| Car Detail from notification | `dco://vehicle/detail` | `?id=uuid` |
| User Detail from family | `dco://user/detail` | `?id=uuid` |

---

## Animations & Transitions

- **Tab switch** (Family Management): 150ms cross-fade
- **Car Detail entry**: Hero transition from Garage Home card (photo)
- **User Detail entry**: Shared avatar transition
- **QR code display**: Scale in 200ms
- **Role badge change**: 100ms color morph

---

## Accessibility

- Role badges: `semanticsLabel = "Role: Primary Owner"`
- License expiry: `semanticsLabel = "License expires in 14 days, on August 15"`
- QR code: `semanticsLabel = "QR code to join Smith Family. Code A7K9M2QX"`
- All buttons: 44×44 minimum touch target
- Color alone never conveys status (always text + icon)

---

## Error & Empty States

| Screen | Empty State | Error State |
|--------|-------------|-------------|
| Family Setup | N/A | Inline validation |
| Family Management (Members) | "No members yet. Invite family to get started." | Banner: "Failed to load members. Pull to retry." |
| Family Management (Vehicles) | "No vehicles in family." | Same |
| Car Detail | N/A (vehicle always exists) | "Unable to load vehicle. Check connection." |
| User Detail | N/A (user always exists) | "Unable to load profile." |

---

## Implementation Notes

### Drift Tables (Mobile Offline)
```dart
// New tables for family sync
@DataClassName('FamilyLocal')
class Families extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get shareCode => text()();
  TextColumn get qrCodeData => text().nullable()(); // JSON
  TextColumn get createdBy => text()();
  IntColumn get status => intEnum<FamilyStatus>()(); // 0=active, 1=archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('FamilyMembershipLocal')
class FamilyMemberships extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get familyUuid => text()();
  TextColumn get userUuid => text()();
  IntColumn get role => intEnum<FamilyRole>()(); // 0=primary_owner, 1=member, 2=driver
  DateTimeColumn get joinedAt => dateTime()();
  TextColumn get invitedBy => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('VehicleGrantLocal')
class VehicleGrants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get vehicleUuid => text()();
  TextColumn get userUuid => text()();
  TextColumn get grantedBy => text()();
  IntColumn get permission => intEnum<GrantPermission>()(); // 0=full, 1=drive_only
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('DrivingLicenseLocal')
class DrivingLicenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get userUuid => text().unique()();
  TextColumn get licenseNumber => text().nullable()();
  TextColumn get issuingCountry => text().nullable()();
  DateTimeColumn get expiryDate => dateTime()();
  TextColumn get categories => text().nullable()();
  TextColumn get frontMediaUuid => text().nullable()();
  TextColumn get backMediaUuid => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
```

### Riverpod Providers
```dart
// Family state
final familyProvider = FutureProvider<Family?>((ref) async {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMyFamily();
});

final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final family = await ref.watch(familyProvider.future);
  if (family == null) return [];
  return ref.watch(familyRepositoryProvider).getMembers(family.id);
});

final vehicleGrantsProvider = FutureProvider.family<List<VehicleGrant>, String>((ref, vehicleId) async {
  return ref.watch(vehicleRepositoryProvider).getGrants(vehicleId);
});

final drivingLicenseProvider = FutureProvider.family<DrivingLicense?, String>((ref, userId) async {
  return ref.watch(userRepositoryProvider).getLicense(userId);
});
```

---

## Testing Checklist

- [ ] Family creation → share code generated → QR valid
- [ ] Join via code → membership created → appears in Management
- [ ] Join via QR deep link → same flow
- [ ] Primary Owner changes Member → Driver → permissions update
- [ ] Primary Owner assigns driver to vehicle → grant created
- [ ] Driver can view car detail, log fuel, cannot log service
- [ ] License upload → expiry reminders scheduled
- [ ] Ownership transfer → tokens refreshed → roles swapped
- [ ] Leave family (non-PO) → membership removed → grants revoked
- [ ] Archive family → all memberships cleaned up
- [ ] Offline: create family → sync on reconnect
- [ ] Offline: join family → sync on reconnect
- [ ] Role badge colors meet contrast on all surfaces
- [ ] License status announced correctly to screen readers
