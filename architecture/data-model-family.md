# Family Sharing Data Model Extension (v1.1)

**Status:** Planned — extends `architecture/data-model.md`  
**Contract:** `product/frd/family-sharing.md`  
**Migration:** Additive only — no changes to existing MVP tables

---

## New Tables

### families

```sql
CREATE TABLE families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(name) <= 100),
  share_code text NOT NULL UNIQUE CHECK (char_length(share_code) = 8),
  qr_code_data jsonb, -- { code, family_id, expires_at }
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  archived_at timestamptz
);

CREATE INDEX idx_families_share_code ON families(share_code);
CREATE INDEX idx_families_created_by ON families(created_by);
```

### family_memberships

```sql
CREATE TYPE family_role AS ENUM ('primary_owner', 'member', 'driver');

CREATE TABLE family_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role family_role NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now(),
  invited_by uuid REFERENCES users(id),
  UNIQUE (family_id, user_id),
  UNIQUE (user_id) -- one family per user
);

CREATE INDEX idx_family_memberships_family_id ON family_memberships(family_id);
CREATE INDEX idx_family_memberships_user_id ON family_memberships(user_id);
```

### vehicle_grants

```sql
CREATE TYPE grant_permission AS ENUM ('full', 'drive_only');

CREATE TABLE vehicle_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  granted_by uuid NOT NULL REFERENCES users(id),
  permission grant_permission NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (vehicle_id, user_id)
);

CREATE INDEX idx_vehicle_grants_vehicle_id ON vehicle_grants(vehicle_id);
CREATE INDEX idx_vehicle_grants_user_id ON vehicle_grants(user_id);
```

### driving_licenses

```sql
CREATE TABLE driving_licenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  license_number text CHECK (char_length(license_number) <= 50),
  issuing_country text CHECK (char_length(issuing_country) = 2), -- ISO 3166-1 alpha-2
  expiry_date date NOT NULL,
  categories text, -- e.g., "B, BE"
  front_media_id uuid REFERENCES media_objects(id),
  back_media_id uuid REFERENCES media_objects(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_driving_licenses_expiry ON driving_licenses(expiry_date);
```

---

## Modified Tables

### users (additive columns)

```sql
ALTER TABLE users ADD COLUMN family_id uuid REFERENCES families(id);
-- Denormalized for quick "my family" lookup without join
-- Kept in sync by application logic on membership create/update/delete

CREATE INDEX idx_users_family_id ON users(family_id);
```

### change_log (new entity types)

Add to `changeOpEnum` if needed (already supports upsert/archive/delete):
- Entity types: `family`, `family_membership`, `vehicle_grant`, `driving_license`

---

## ERD (Extended)

```mermaid
erDiagram
  users ||--o{ families : creates
  users ||--o{ family_memberships : belongs_to
  families ||--o{ family_memberships : has
  users ||--o{ vehicle_grants : grants
  users ||--o{ vehicle_grants : receives
  vehicles ||--o{ vehicle_grants : granted_on
  users ||--|| driving_licenses : has
  users ||--o{ media_objects : owns
  driving_licenses }|--|| media_objects : front_photo
  driving_licenses }|--|| media_objects : back_photo

  families {
    uuid id PK
    string name
    string share_code UK
    jsonb qr_code_data
    uuid created_by FK
    timestamptz created_at
    string status
    timestamptz archived_at
  }

  family_memberships {
    uuid id PK
    uuid family_id FK
    uuid user_id FK UK
    enum role
    timestamptz joined_at
    uuid invited_by FK
  }

  vehicle_grants {
    uuid id PK
    uuid vehicle_id FK
    uuid user_id FK
    uuid granted_by FK
    enum permission
    timestamptz created_at
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

---

## Access Control Matrix

| Action | Primary Owner | Member (full grant) | Driver (drive_only grant) | Non-member |
|--------|---------------|---------------------|---------------------------|------------|
| View vehicle | ✓ | ✓ | ✓ | ✗ |
| View documents | ✓ | ✓ | ✓ | ✗ |
| Upload documents | ✓ | ✓ | ✗ | ✗ |
| Log maintenance | ✓ | ✓ | ✗ | ✗ |
| Log expenses | ✓ | ✓ | ✗ | ✗ |
| Log fuel/charge | ✓ | ✓ | ✓ | ✗ |
| Manage parts | ✓ | ✓ | ✗ | ✗ |
| View maintenance due | ✓ | ✓ | ✓ | ✗ |
| Assign drivers | ✓ | ✓ | ✗ | ✗ |
| Manage family members | ✓ | ✗ | ✗ | ✗ |
| Transfer ownership | ✓ | ✗ | ✗ | ✗ |
| Archive family | ✓ | ✗ | ✗ | ✗ |

---

## Sync Entities (Mobile Offline)

Add to Drift schema and sync engine:

| Entity Type | Local Table | Server Table | Notes |
|-------------|-------------|--------------|-------|
| family | families_local | families | Primary Owner only creates |
| family_membership | family_memberships_local | family_memberships | All members sync |
| vehicle_grant | vehicle_grants_local | vehicle_grants | Grantor creates |
| driving_license | driving_licenses_local | driving_licenses | Owner syncs own |

**Conflict Resolution:**
- Family/membership: server wins (authoritative)
- Vehicle grants: last-write-wins on permission; grant creation is idempotent
- Driving license: local wins (user owns their license data)

---

## Query Patterns

### Get My Family (Mobile)
```sql
SELECT f.*, fm.role as my_role
FROM families f
JOIN family_memberships fm ON fm.family_id = f.id
WHERE fm.user_id = $1 AND f.status = 'active';
```

### Get Family Members with License Status
```sql
SELECT u.id, u.email, u.display_name, fm.role, fm.joined_at,
       dl.expiry_date,
       CASE WHEN dl.expiry_date < CURRENT_DATE THEN 'expired'
            WHEN dl.expiry_date < CURRENT_DATE + INTERVAL '14 days' THEN 'expiring_soon'
            ELSE 'valid' END as license_status
FROM family_memberships fm
JOIN users u ON u.id = fm.user_id
LEFT JOIN driving_licenses dl ON dl.user_id = u.id
WHERE fm.family_id = $1
ORDER BY CASE fm.role WHEN 'primary_owner' THEN 1 WHEN 'member' THEN 2 ELSE 3 END, u.display_name;
```

### Get Vehicle with Grants and Drivers
```sql
SELECT v.*, 
       jsonb_agg(
         jsonb_build_object(
           'user_id', ug.user_id,
           'permission', ug.permission,
           'driver_name', u.display_name,
           'license_expiry', dl.expiry_date
         )
       ) FILTER (WHERE ug.id IS NOT NULL) as grants
FROM vehicles v
LEFT JOIN vehicle_grants ug ON ug.vehicle_id = v.id
LEFT JOIN users u ON u.id = ug.user_id
LEFT JOIN driving_licenses dl ON dl.user_id = u.id
WHERE v.id = $1
GROUP BY v.id;
```

### Check User Vehicle Access (Authorization)
```sql
-- Returns permission level or null if no access
SELECT 
  CASE 
    WHEN v.user_id = $1 THEN 'owner'
    WHEN ug.permission = 'full' THEN 'full'
    WHEN ug.permission = 'drive_only' THEN 'drive_only'
  END as access_level
FROM vehicles v
LEFT JOIN vehicle_grants ug ON ug.vehicle_id = v.id AND ug.user_id = $1
WHERE v.id = $2;
```

---

## Migration Script (Conceptual)

```sql
-- 1. Create enums
CREATE TYPE family_role AS ENUM ('primary_owner', 'member', 'driver');
CREATE TYPE grant_permission AS ENUM ('full', 'drive_only');

-- 2. Create new tables (see above)

-- 3. Add family_id to users
ALTER TABLE users ADD COLUMN family_id uuid REFERENCES families(id);
CREATE INDEX idx_users_family_id ON users(family_id);

-- 4. Backfill: No existing data to migrate (new feature)

-- 5. Update change_log entity_type check constraint if using enum
-- (currently text, so no change needed)

-- 6. Add RLS policies if using Row Level Security (optional)
```

---

## Seed Data

None required. Families created on-demand by users.

---

## Rollback Plan

1. Drop `driving_licenses`, `vehicle_grants`, `family_memberships`, `families` tables
2. Drop `family_id` column from `users`
3. Drop `family_role`, `grant_permission` enums
4. Remove entity types from sync/change_log logic

All additive — no data loss risk for existing MVP tables.
