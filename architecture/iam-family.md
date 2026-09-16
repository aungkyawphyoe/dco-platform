# Identity and Access — Family Sharing Extension

**Status:** Accepted — extends `architecture/iam.md`  
**Contract:** `product/frd/family-sharing.md`, `architecture/data-model-family.md`  
**Principle:** Additive only. MVP IAM (`owner` | `admin`) unchanged. Family roles live in `family_memberships.role`, not `users.role`.

---

## Extended IAM Taxonomy

### Principal Types (v1.1)

| Principal | Surface | JWT `aud` | `users.role` | Family Role | What they can do |
|-----------|---------|-----------|--------------|-------------|------------------|
| Primary Owner | Flutter + Web | `dco-owner` | `owner` | `primary_owner` | Own garage + family mgmt + vehicle grants + web family read-only |
| Member (Secondary Owner) | Flutter | `dco-owner` | `owner` | `member` | Full vehicle access (granted) + family view |
| Driver | Flutter | `dco-owner` | `owner` | `driver` | View + fuel log + doc view on granted vehicles |
| Platform Admin | Web Admin | `dco-admin` | `admin` | — | `/v1/admin/*` only (unchanged) |

### Key Design Decisions

1. **`users.role` stays `owner`** for all family participants. Family authority is in `family_memberships.role`, not a new user role enum value.
2. **Same JWT audience (`dco-owner`)** for all family roles — the Flutter app doesn't split. Authorization checks `family_memberships` + `vehicle_grants` on each request.
3. **Web Primary Owner** uses same `dco-owner` JWT via BFF cookie. Route guard checks `family_memberships.role = primary_owner`.
4. **No new audiences** — avoids token fragmentation. Admin stays `dco-admin`.

---

## Authorization Model

### Vehicle Access Check (Runtime)

```typescript
// Every vehicle-accessing endpoint calls this
async function getVehicleAccessLevel(
  db: Db,
  userId: string,
  vehicleId: string
): Promise<'owner' | 'full' | 'drive_only' | null> {
  const vehicle = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId)).limit(1);
  if (!vehicle[0]) return null;
  
  if (vehicle[0].userId === userId) return 'owner';
  
  const grant = await db
    .select()
    .from(vehicleGrants)
    .where(and(eq(vehicleGrants.vehicleId, vehicleId), eq(vehicleGrants.userId, userId)))
    .limit(1);
  
  return grant[0]?.permission ?? null;
}
```

### Permission Gates

| Endpoint Category | Required Access | Check |
|-------------------|-----------------|-------|
| `GET /v1/vehicles/:id` | `owner` \| `full` \| `drive_only` | `getVehicleAccessLevel` |
| `GET /v1/vehicles/:id/documents` | `owner` \| `full` \| `drive_only` | Same |
| `POST /v1/vehicles/:id/documents` | `owner` \| `full` | `accessLevel in ('owner', 'full')` |
| `POST /v1/vehicles/:id/service-records` | `owner` \| `full` | Same |
| `POST /v1/vehicles/:id/expenses` | `owner` \| `full` | Same |
| `POST /v1/vehicles/:id/fuel-logs` | `owner` \| `full` \| `drive_only` | Same |
| `POST /v1/families/:id/vehicle-grants` | `owner` \| `full` on vehicle | Grantor must have `full` |
| `PATCH /v1/families/:id/members/:userId` | `primary_owner` | Family membership role |

---

## JWT Claims (Extended)

### Access Token (dco-owner)

```json
{
  "sub": "user-uuid",
  "role": "owner",
  "plan": "free|premium",
  "family_id": "family-uuid|null",
  "family_role": "primary_owner|member|driver|null",
  "aud": "dco-owner",
  "iat": 1234567890,
  "exp": 1234567890
}
```

- `family_id` + `family_role` denormalized for fast route guards (avoids DB lookup on every request)
- Updated on refresh token rotation when family membership changes

### Refresh Token

Unchanged — includes `familyId` for revoke-all-on-reset (already in MVP).

---

## Web Admin Route Guards (Extended)

### Current (MVP)
```typescript
// Admin only
requireAdmin(request, adminAud); // role=admin + aud=dco-admin
```

### v1.1 Extension
```typescript
// Three-tier guard
async function requireWebAccess(request, required: 'admin' | 'family' | 'none') {
  const claims = request.authUser; // from BFF cookie
  
  if (required === 'admin') {
    if (claims.role !== 'admin' || claims.aud !== 'dco-admin') throw 403;
    return;
  }
  
  if (required === 'family') {
    if (claims.role !== 'owner' || claims.aud !== 'dco-owner') throw 403;
    if (!claims.family_id || claims.family_role !== 'primary_owner') throw 403;
    return;
  }
  
  // 'none' = public
}
```

### Route Mapping

| Route | Guard | Notes |
|-------|-------|-------|
| `/login` | Public | Accepts both admin + owner credentials |
| `/` (admin dashboard) | `admin` | Existing |
| `/users/*` | `admin` | Existing |
| `/partners/*` | `admin` | Existing |
| `/family` | `family` | **New** — Primary Owner read-only |
| `/family/*` | `family` | **New** — Vehicle/member details |

---

## Mobile Route Guards (Extended)

### Current (MVP)
```dart
// All authenticated routes require owner role
if (authUser.role != 'owner') redirectToLogin();
```

### v1.1 Extension
```dart
// Family features require family membership
enum FamilyFeature { create, manage, view, join }

bool canAccessFamilyFeature(FamilyFeature feature, AuthUser user) {
  switch (feature) {
    case FamilyFeature.create:
      return user.familyId == null; // Not already in a family
    case FamilyFeature.manage:
      return user.familyRole == 'primary_owner';
    case FamilyFeature.view:
      return user.familyId != null;
    case FamilyFeature.join:
      return user.familyId == null;
  }
}

// Vehicle access
bool canAccessVehicle(String vehicleId, AuthUser user, {required String permission}) {
  final access = await getVehicleAccessLevel(user.id, vehicleId);
  if (access == null) return false;
  if (permission == 'full') return access == 'owner' || access == 'full';
  if (permission == 'drive') return access != null; // any access
  return false;
}
```

---

## Family Lifecycle & Token Updates

| Event | Token Update |
|-------|--------------|
| User creates family | Next refresh: `family_id` + `family_role=primary_owner` |
| User joins family | Next refresh: `family_id` + `family_role=member/driver` |
| Primary Owner transfers ownership | Old PO: `family_role=member`; New PO: `family_role=primary_owner` |
| Member removed from family | Next refresh: `family_id=null`, `family_role=null` |
| Family archived | All members: `family_id=null`, `family_role=null` |

**Implementation:** On family membership change, revoke user's refresh token family (existing `familyId` in `refresh_tokens`). Forces re-auth with new claims.

---

## Admin Support View (Read-Only)

Admins can view family structures for support via `/v1/admin/families`:

```typescript
// Admin only
GET /v1/admin/families?status=active&limit=50
GET /v1/admin/families/:id
GET /v1/admin/families/:id/members
GET /v1/admin/families/:id/vehicles
```

Returns family data without PII exposure beyond what admin already sees (email, name, plan).

---

## Security Considerations

1. **Share code entropy**: 8-char alphanumeric (62^8 ≈ 218T) — brute force infeasible with rate limiting
2. **QR code expiry**: 7 days; contains only `code` + `family_id` — no secrets
3. **Vehicle grants**: Server-side validated on every access; no client-side trust
4. **License images**: Same media pipeline as documents — signed URLs, no public access
5. **Token denormalization**: `family_id`/`family_role` in JWT are hints; server re-validates on mutating operations
6. **One family per user**: Enforced by unique constraint on `family_memberships.user_id`

---

## Migration from Pre-Family MVP

| Pre-Family State | Current State |
|-----------|------------|
| `users.role = 'owner'` | Unchanged |
| No family concept | `family_memberships` created on family creation/join |
| Vehicle owned by `user_id` | Unchanged; grants additive |
| Admin JWT `dco-admin` | Unchanged |
| Owner JWT `dco-owner` | Extended with `family_id`, `family_role` |

No breaking changes to existing tokens. Fields are optional (null when not in family).

---

## Future: Fleet/Org Extension (Phase 2)

When Fleet lands (Phase 2), introduce `organizations` as new root:

| Concept | Family (MVP) | Fleet (Future) |
|---------|---------------|----------------|
| Root entity | `families` | `organizations` (type=fleet) |
| Membership | `family_memberships` | `organization_members` |
| Roles | `primary_owner`/`member`/`driver` | `org_admin`/`dispatcher`/`driver` |
| Vehicle link | `vehicle_grants` | `vehicle_grants` (org-scoped) |
| JWT audience | `dco-owner` (same) | `dco-fleet` (new) |
| App | Flutter (same) | Web Fleet Portal (new) |

**Do not** migrate families to organizations in v1.1. They remain separate until a unified model is designed.
